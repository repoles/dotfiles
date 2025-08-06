if status is-login
    /opt/homebrew/bin/brew shellenv | source
end

if status is-interactive
    set -g fish_greeting

    set -g fish_color_command blue
    # set -g fish_color_param normal

    fzf --fish | source

    zoxide init fish --cmd j | source

    set -x STARSHIP_CONFIG $XDG_CONFIG_HOME/starship/starship.toml
    starship init fish | source

    fish_add_path $HOMEBREW_PREFIX/opt/mysql@8.4/bin $HOME/Code/Scripts
    [ "$TERM_PROGRAM" = "Apple_Terminal" ] && function fish_title; end
end
