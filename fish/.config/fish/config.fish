if status is-login
    /opt/homebrew/bin/brew shellenv | source
end

if status is-interactive
    set -g fish_greeting

    set -x STARSHIP_CONFIG $XDG_CONFIG_HOME/starship/starship.toml
    starship init fish | source

    fish_add_path --append $HOMEBREW_PREFIX/opt/mysql@8.4/bin
    [ "$TERM_PROGRAM" = "Apple_Terminal" ] && function fish_title; end
end
