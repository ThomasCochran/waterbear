# --- @@SCHEME_NAME@@ colors for fish's syntax highlighting, completions and pager ---
# (set -g, so they win over `fish_config` choices; to use your own, set them in config.fish)
set -g fish_color_normal @@FG@@
set -g fish_color_command @@A@@ --bold
set -g fish_color_keyword @@B@@
set -g fish_color_quote @@C2@@
set -g fish_color_redirection @@C6@@
set -g fish_color_end @@C5@@
set -g fish_color_error @@C1@@
set -g fish_color_param @@FG@@
set -g fish_color_option @@C12@@
set -g fish_color_comment @@DIM@@
set -g fish_color_operator @@B@@
set -g fish_color_escape @@C14@@
set -g fish_color_autosuggestion @@DIM@@
set -g fish_color_valid_path --underline
set -g fish_color_cwd @@A@@
set -g fish_color_cwd_root @@C1@@
set -g fish_color_user @@B@@
set -g fish_color_host @@A@@
set -g fish_color_host_remote @@C3@@
set -g fish_color_status @@C1@@
set -g fish_color_cancel @@C1@@ --reverse
set -g fish_color_selection @@BG@@ --background=@@A@@
set -g fish_color_search_match --background=@@C8@@
set -g fish_color_history_current @@B@@ --bold
set -g fish_pager_color_prefix @@B@@ --bold --underline
set -g fish_pager_color_completion @@FG@@
set -g fish_pager_color_description @@DIM@@
set -g fish_pager_color_progress @@BG@@ --background=@@A@@
set -g fish_pager_color_selected_background --background=@@C8@@
