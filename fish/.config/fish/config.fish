set -x XDG_CONFIG_HOME $HOME/.config
set -x XDG_CACHE_HOME $HOME/.cache
set -x XDG_DATA_HOME $HOME/.local/share
set -x XDG_STATE_HOME $HOME/.local/state

if status is-login
    [ -d /opt/homebrew/bin ] && /opt/homebrew/bin/brew shellenv | source
end

if status is-interactive
    set fish_greeting ""

    set fish_color_command blue

    fish_add_path --append $HOMEBREW_PREFIX/opt/mysql@8.4/bin
    [ $TERM_PROGRAM = Apple_Terminal ] && function fish_title; end
end
