set -x XDG_CONFIG_HOME $HOME/.config
set -x XDG_CACHE_HOME $HOME/.cache
set -x XDG_DATA_HOME $HOME/.local/share
set -x XDG_STATE_HOME $HOME/.local/state

set -x EDITOR nvim
set -x VISUAL zed --wait

set -x IRBRC $XDG_CONFIG_HOME/irb/irbrc.rb
mkdir -p $XDG_DATA_HOME/irb # where irb history will be saved

set -x PRYRC $XDG_CONFIG_HOME/pry/pryrc.rb

set -x MYSQL_HISTFILE $XDG_DATA_HOME/mysql/history
mkdir -p (dirname $MYSQL_HISTFILE)

set -x AWS_CONFIG_FILE $XDG_CONFIG_HOME/aws/config
# I'm using aws-vault now (https://github.com/99designs/aws-vault)
# set -x AWS_SHARED_CREDENTIALS_FILE $XDG_CONFIG_HOME/aws/credentials

set -x FZF_DEFAULT_OPTS '--tmux center,90%,70% --layout reverse'
