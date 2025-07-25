set -x XDG_CONFIG_HOME $HOME/.config
set -x XDG_CACHE_HOME $HOME/.cache
set -x XDG_DATA_HOME $HOME/.local/share
set -x XDG_STATE_HOME $HOME/.local/state

# set -x STARSHIP_CONFIG $XDG_CONFIG_HOME/starship/starship.toml

if status is-login
    [ -d /opt/homebrew/bin ] && /opt/homebrew/bin/brew shellenv | source
end

if status is-interactive
    set -g fish_greeting ""

    set -g fish_color_command green

    # starship init fish | source

    # set -g hydro_color_prompt green
    # set -g hydro_color_pwd blue
    set -g hydro_color_git purple
    set -g hydro_color_duration yellow

    set -g hydro_cmd_duration_threshold 5000
    # set -g hydro_fetch true
    # set -g hydro_multiline true

    fish_add_path --append $HOMEBREW_PREFIX/opt/mysql@8.4/bin
    [ $TERM_PROGRAM = Apple_Terminal ] && function fish_title; end
end
