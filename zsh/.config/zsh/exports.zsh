# So that when deleting using OPTION + DELETE the
# deletion stops at characters like -, _, ., etc
WORDCHARS=""

export IRBRC="$XDG_CONFIG_HOME"/irb/irbrc.rb
mkdir -p "$XDG_STATE_HOME"/irb # to put irb history

export MYSQL_HISTFILE="$XDG_STATE_HOME"/mysql/history
mkdir -p "$MYSQL_HISTFILE:h"

export LANG=en_US.UTF-8
export EDITOR="vim"
export VISUAL="vim"

export VIMINIT="set nocp | source ${XDG_CONFIG_HOME}/vim/vimrc"
