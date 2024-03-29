# https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/completion.zsh

unsetopt menu_complete   # do not autoselect the first completion entry
unsetopt flowcontrol
setopt auto_menu         # show completion menu on successive tab press
setopt complete_in_word
setopt always_to_end

# (man zshoptions)
setopt auto_cd glob_complete

zstyle ':completion:*:*:*:*:*' menu select

# case insensitive (all), partial-word and substring completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# Complete . and .. special directories
zstyle ':completion:*' special-dirs true

zstyle ':completion:*:default' list-colors "di=34;1" # cor dos diretórios no tab autocomplete
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USERNAME -o pid,user,comm -w -w"

# disable named-directories autocompletion
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories

# Using a cache for the completion can speed up some commands, like apt for example.
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zcompcache"

ZSH_COMPDUMP="${XDG_CACHE_HOME}/zcompdump-${HOST/.*/}-${ZSH_VERSION}"
autoload -U compinit; compinit -d $ZSH_COMPDUMP
unset ZSH_COMPDUMP
