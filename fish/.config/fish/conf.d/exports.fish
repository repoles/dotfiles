set -x XDG_CONFIG_HOME $HOME/.config
set -x XDG_CACHE_HOME $HOME/.cache
set -x XDG_DATA_HOME $HOME/.local/share
set -x XDG_STATE_HOME $HOME/.local/state

set -x EDITOR nvim

# We use mise to manage Ruby installations. However,
# we want to keep the Ruby that comes installed on
# macOS unchanged and without adding new gems.
# set -x GEM_HOME $XDG_DATA_HOME/gem
# set -x GEM_PATH $GEM_HOME
set -x GEM_SPEC_CACHE $XDG_CACHE_HOME/gem

set -x BUNDLE_USER_CONFIG $XDG_CONFIG_HOME/bundle/config.yml
set -x BUNDLE_USER_PLUGIN $XDG_DATA_HOME/bundle
set -x BUNDLE_USER_CACHE $XDG_CACHE_HOME/bundle

set -x PRYRC $XDG_CONFIG_HOME/pry/pryrc.rb
set -x IRBRC $XDG_CONFIG_HOME/irb/irbrc.rb # creates its own history directory
set -x MYSQL_HISTFILE $XDG_DATA_HOME/mysql/history # the mysql function creates its directory

set -x AWS_CONFIG_FILE $XDG_CONFIG_HOME/aws/config
# I'm using aws-vault now (https://github.com/99designs/aws-vault)
# set -x AWS_SHARED_CREDENTIALS_FILE $XDG_CONFIG_HOME/aws/credentials

# Discard inherited inline defaults so they cannot override the shared file.
set -e FZF_DEFAULT_OPTS
set -x FZF_DEFAULT_OPTS_FILE $XDG_CONFIG_HOME/fzf/config

set -x FZF_CTRL_R_OPTS "--with-nth=2.."

set -x ICLOUD ~/"Library/Mobile Documents/com~apple~CloudDocs"
set -x WACLI_STORE_DIR $XDG_STATE_HOME/wacli
