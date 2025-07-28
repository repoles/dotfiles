# So that when deleting using OPTION + DELETE the
# deletion stops at characters like -, _, ., etc
WORDCHARS=""

export IRBRC="$XDG_CONFIG_HOME"/irb/irbrc.rb
mkdir -p "$XDG_DATA_HOME"/irb # to put irb history

export BUNDLE_USER_CACHE=$XDG_CACHE_HOME/bundle

export PRYRC="$XDG_CONFIG_HOME"/pry/pryrc.rb
mkdir -p "$XDG_DATA_HOME"/pry

export MYSQL_HISTFILE="$XDG_DATA_HOME"/mysql/history
mkdir -p "$MYSQL_HISTFILE:h"

export STARSHIP_CONFIG="$XDG_CONFIG_HOME"/starship/starship.toml

export AWS_CONFIG_FILE="$XDG_CONFIG_HOME"/aws/config
# i'm using aws-vault now (https://github.com/99designs/aws-vault)
#export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME"/aws/credentials

export LANG=en_US.UTF-8
export EDITOR="vim"
export VISUAL="code --wait"

export VIMINIT="set nocp | source ${XDG_CONFIG_HOME}/vim/vimrc"
