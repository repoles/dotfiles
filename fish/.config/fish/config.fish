if status is-login
end

if status is-interactive
    set -g fish_greeting

    # https://fishshell.com/docs/current/interactive.html#syntax-highlighting-variables
    set -g fish_color_command green
    set -g fish_color_error red
    set -g fish_color_param normal
    set -g fish_color_cwd blue
    set -g fish_color_comment brblack --italics
    set -g fish_pager_color_progress black --background=cyan

    # --- Custom prompt settings ---
    set -g fish_transient_prompt 1

    set -g custom_prompt_pwd_color blue

    set -g custom_prompt_git_branch_color purple
    set -g custom_prompt_git_branch_symbol \ue725 # 
    # set -g custom_prompt_git_branch_dirty_symbol \u2022 # •

    # set -g custom_prompt_git_status_color cyan
    set -g custom_prompt_git_status_ahead_symbol \u2191 # ↑
    set -g custom_prompt_git_status_behind_symbol \u2193 # ↓

    # set -g custom_prompt_command_duration_threshold 2000
    set -g custom_prompt_command_duration_color yellow
    set -g custom_prompt_time_color brblack
    set -g custom_prompt_symbol \u276f # ❯
    set -g custom_prompt_symbol_success_color green
    set -g custom_prompt_symbol_failure_color red

    # ---

    /opt/homebrew/bin/brew shellenv | source
    zoxide init fish --cmd j | source

    # https://junegunn.github.io/fzf/shell-integration/#setting-up-shell-integration
    fzf --fish | FZF_ALT_C_COMMAND= FZF_CTRL_T_COMMAND= source

    # set -x STARSHIP_CONFIG $XDG_CONFIG_HOME/starship/starship.toml
    # starship init fish | source

    fish_add_path $HOME/.local/bin
    [ "$TERM_PROGRAM" = "Apple_Terminal" ] && function fish_title; end
end
