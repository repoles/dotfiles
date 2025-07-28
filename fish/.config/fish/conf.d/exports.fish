set -x XDG_CONFIG_HOME $HOME/.config
set -x XDG_CACHE_HOME $HOME/.cache
set -x XDG_DATA_HOME $HOME/.local/share
set -x XDG_STATE_HOME $HOME/.local/state

set -x IRBRC $XDG_CONFIG_HOME/irb/irbrc.rb
mkdir -p $XDG_DATA_HOME/irb # where irb history will be saved

set -x MYSQL_HISTFILE $XDG_DATA_HOME/mysql/history
mkdir -p (dirname $MYSQL_HISTFILE)
