set -x XDG_CONFIG_HOME $HOME/.config
set -x XDG_CACHE_HOME $HOME/.cache
set -x XDG_DATA_HOME $HOME/.local/share
set -x XDG_STATE_HOME $HOME/.local/state

set -x EDITOR nvim
set -x VISUAL zed --wait

# We use mise to manage Ruby installations. However,
# we want to keep the Ruby that comes installed on
# macOS unchanged and without adding new gems.
# set -x GEM_HOME $XDG_DATA_HOME/gem
# set -x GEM_PATH $GEM_HOME
set -x GEM_SPEC_CACHE $XDG_CACHE_HOME/gem

set -x BUNDLE_USER_CONFIG $XDG_CONFIG_HOME/bundle/config.yml
set -x BUNDLE_USER_PLUGIN $XDG_DATA_HOME/bundle
set -x BUNDLE_USER_CACHE $XDG_CACHE_HOME/bundle

set -x IRBRC $XDG_CONFIG_HOME/irb/irbrc.rb
mkdir -p $XDG_DATA_HOME/irb # where irb history must be saved

set -x PRYRC $XDG_CONFIG_HOME/pry/pryrc.rb

set -x MYSQL_HISTFILE $XDG_DATA_HOME/mysql/history
mkdir -p (dirname $MYSQL_HISTFILE)

set -x AWS_CONFIG_FILE $XDG_CONFIG_HOME/aws/config
# I'm using aws-vault now (https://github.com/99designs/aws-vault)
# set -x AWS_SHARED_CREDENTIALS_FILE $XDG_CONFIG_HOME/aws/credentials

set -x FZF_DEFAULT_OPTS '--tmux center,90%,70% --layout reverse'
