if status is-login
    /opt/homebrew/bin/brew shellenv | source
end

if status is-interactive
    set -g fish_greeting

    set -g fish_pager_color_progress black --background=cyan

    # https://fishshell.com/docs/current/interactive.html#syntax-highlighting-variables
    # set -g fish_color_command green
    # set -g fish_color_param normal
    # set -g fish_color_cwd blue --bold
    set -g fish_color_comment purple --italics

    # https://fishshell.com/docs/current/cmds/fish_git_prompt.html
    # set -g __fish_git_prompt_show_informative_status true
    set -g __fish_git_prompt_showupstream informative
    # set -g __fish_git_prompt_use_informative_chars true

    # set -g __fish_git_prompt_showcolorhints true
    set -g __fish_git_prompt_color purple
    # set -g __fish_git_prompt_color_branch purple

    set -g __fish_git_prompt_char_upstream_ahead ↑
    set -g __fish_git_prompt_char_upstream_behind ↓

    zoxide init fish --cmd j | source
    fzf --fish | source

    set -x STARSHIP_CONFIG $XDG_CONFIG_HOME/starship/starship.toml
    starship init fish | source

    fish_add_path $HOMEBREW_PREFIX/opt/mysql@8.4/bin $HOME/Code/Scripts
    [ "$TERM_PROGRAM" = "Apple_Terminal" ] && function fish_title; end
end
