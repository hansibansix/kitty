#!/usr/bin/env bash
# fzf picker for kitty tabs (current OS window only).

set -euo pipefail

tabs_json="$(kitten @ ls 2>&1)" || {
  printf 'fzf-tabs: kitten @ ls failed:\n%s\n\nIs "allow_remote_control yes" set in kitty.conf?\n' "$tabs_json" >&2
  sleep 2
  exit 1
}

selection="$(
  printf '%s\n' "$tabs_json" | jq -r '
    .[]
    | select(.is_focused)
    | .tabs[]
    | [
        (.id | tostring),
        (((.windows[]? | select(.is_focused) | .id) // 0) | tostring),
        (
          (if .is_focused then "*" else " " end)
          + " " + (.id | tostring)
          + "  " + .title
          + "  " + ((.windows[]? | select(.is_focused) | .cwd) // "")
        )
      ]
    | @tsv
  ' | fzf \
      --ansi \
      --delimiter=$'\t' \
      --with-nth=3.. \
      --prompt=' ❯ ' \
      --pointer='▶' \
      --layout=reverse \
      --info=inline-right \
      --margin=35%,38% \
      --border=rounded \
      --border-label=' Tabs ' \
      --border-label-pos=2 \
      --color='fg:#cdd6f4,bg:#1e1e2e,hl:#f38ba8' \
      --color='fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8' \
      --color='info:#cba6f7,prompt:#cba6f7,pointer:#f5e0dc' \
      --color='marker:#f5e0dc,header:#f38ba8' \
      --color='border:#89b4fa,label:#89b4fa'
)" || exit 0

# selection is the full TSV line; first column is the tab id.
tab_id="${selection%%$'\t'*}"
kitten @ focus-tab --match "id:${tab_id}"
