#!/usr/bin/env bash
# fzf picker for kitty tabs (current OS window only).

set -euo pipefail

tabs_json="$(kitten @ ls 2>&1)" || {
  printf 'fzf-tabs: kitten @ ls failed:\n%s\n\nIs "allow_remote_control yes" set in kitty.conf?\n' "$tabs_json" >&2
  sleep 2
  exit 1
}

cols=$(tput cols)
lines=$(tput lines)

target_w=80
target_h=20

max_w=$(( cols * 80 / 100 ))
max_h=$(( lines * 80 / 100 ))
(( target_w > max_w )) && target_w=$max_w
(( target_h > max_h )) && target_h=$max_h

h_margin=$(( (cols - target_w) / 2 ))
v_margin=$(( (lines - target_h) / 2 ))
(( h_margin < 0 )) && h_margin=0
(( v_margin < 0 )) && v_margin=0

# Catppuccin Mocha ANSI escapes
RESET=$'\e[0m'
BOLD=$'\e[1m'
ITALIC=$'\e[3m'
TEXT=$'\e[38;2;205;214;244m'
MUTED=$'\e[38;2;88;91;112m'
GREEN=$'\e[38;2;166;227;161m'
PEACH=$'\e[38;2;250;179;135m'
BLUE=$'\e[38;2;137;180;250m'

selection="$(
  printf '%s\n' "$tabs_json" | jq -r \
    --arg RESET "$RESET" --arg BOLD "$BOLD" --arg ITALIC "$ITALIC" \
    --arg TEXT "$TEXT" --arg MUTED "$MUTED" --arg GREEN "$GREEN" \
    --arg PEACH "$PEACH" --arg BLUE "$BLUE" \
    --arg HOME "$HOME" '
    .[]
    | select(.is_focused)
    | .tabs
    | to_entries[]
    | .key as $i
    | .value as $t
    | (if $t.is_focused then $GREEN + "●" + $RESET else " " end) as $dot
    | (($t.title // "") | if length > 40 then .[0:39] + "…" else . end) as $title
    | ((($t.windows[]? | select(.is_focused) | .cwd) // "")
       | if startswith($HOME) then "~" + .[($HOME | length):] else . end
       | if length > 40 then "…" + .[-39:] else . end) as $cwd
    | [
        ($t.id | tostring),
        ((($t.windows[]? | select(.is_focused) | .id) // 0) | tostring),
        "\($dot)  \($PEACH)\($BOLD)\(($i + 1) | tostring)\($RESET)  \($MUTED)│\($RESET)  \($BOLD)\($TEXT)\($title)\($RESET)  \($MUTED)·\($RESET)  \($BLUE)\($ITALIC)\($cwd)\($RESET)"
      ]
    | @tsv
  ' | fzf \
      --ansi \
      --delimiter=$'\t' \
      --with-nth=3.. \
      --prompt=' ❯ ' \
      --pointer='▌' \
      --layout=reverse \
      --info=inline-right \
      --highlight-line \
      --no-scrollbar \
      --no-separator \
      --header=' ' \
      --margin="${v_margin},${h_margin}" \
      --padding='1,2' \
      --border=rounded \
      --border-label=' kitty · tabs ' \
      --border-label-pos=2 \
      --color='fg:#cdd6f4,bg:#1e1e2e,hl:#89b4fa' \
      --color='fg+:#f5e0dc,bg+:#313244,hl+:#89b4fa,gutter:-1' \
      --color='info:#585b70,prompt:#cba6f7,pointer:#f38ba8' \
      --color='marker:#a6e3a1,header:#6c7086' \
      --color='border:#89b4fa,label:#cba6f7'
)" || exit 0

# selection is the full TSV line; first column is the tab id.
tab_id="${selection%%$'\t'*}"
kitten @ focus-tab --match "id:${tab_id}"
