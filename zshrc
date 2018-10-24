# Autocompletion
autoload -Uz compinit
typeset -i updated_at=$(date +'%j' -r ~/.zcompdump 2>/dev/null || stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)
if [ $(date +'%j') != $updated_at ]; then
  compinit -i
else
  compinit -C -i
fi

zmodload -i zsh/complist

# Commands history
HISTFILE=$HOME/.zsh_history
HISTSIZE=100000
SAVEHIST=$HISTSIZE

setopt hist_ignore_all_dups # remove older duplicate entries from history
setopt hist_reduce_blanks # remove superfluous blanks from history items
setopt inc_append_history # save history entries as soon as they are entered
setopt share_history # share history between different instances of the shell

setopt auto_cd # cd by typing directory name if it's not a command
setopt correct_all # autocorrect commands

setopt auto_list # automatically list choices on ambiguous completion
setopt auto_menu # automatically use menu completion
setopt always_to_end # move cursor to end if word had one match

zstyle ':completion:*' menu select # select completions with arrow keys
zstyle ':completion:*' group-name '' # group results by category
zstyle ':completion:::::' completer _expand _complete _ignored _approximate # enable approximate matches for completion

# Plugins
source /usr/local/share/antigen/antigen.zsh
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-history-substring-search
antigen bundle mafredri/zsh-async 
antigen bundle sindresorhus/pure
antigen apply

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

PURE_GIT_DOWN_ARROW=↓
PURE_GIT_UP_ARROW=↑

# Aliases
# #######

# Some example alias instructions
# If these are enabled they will be used instead of any instructions
# they may mask.  For example, alias rm='rm -i' will mask the rm
# application.  To override the alias instruction use a \ before, ie
# \rm will call the real rm not the alias.

# Interactive operation...
alias rm='rm -i'
alias cp='cp -iv'
alias mv='mv -iv'

# Default to human readable figures
alias df='df -h'
alias du='du -h'

# Misc :)
#alias less='less -r'                         # raw control characters
#alias whence='type -a'                       # where, of a sort
alias grep='grep --color'                     # show differences in colour
alias path='echo -e ${PATH//:/\\n}'

# Some shortcuts for different directory listings
alias ls='ls -h -G'                           # classify files in colour
alias ll='ls -l'                              # long list
alias la='ls -A'                              # all but . and ..

#alias cd..='cd ../'                          # Go back 1 directory level (for fast typers)
#alias ..='cd ../'                            # Go back 1 directory level
#alias ...='cd ../../'                        # Go back 2 directory levels
#alias .3='cd ../../../'                      # Go back 3 directory levels
#alias .4='cd ../../../../'                   # Go back 4 directory levels
#alias .5='cd ../../../../../'                # Go back 5 directory levels
#alias .6='cd ../../../../../../'             # Go back 6 directory levels

alias qfind="find . -name "                  # qfind: Quickly search for file
alias myip='curl ifconfig.co'                # myip: Public facing IP Address
alias f='open -a Finder ./'                  # f: Opens current directory in Finder
alias ~="cd ~"                               # ~: Go Home

export USER_EMAIL=repoles@gmail.com

export TEMP_DIR=$HOME/Temp
export SCRIPTS_DIR=$HOME/Code/scripts
export DOTFILES_DIR=$HOME/Code/dotfiles

export PATH=$PATH:$SCRIPTS_DIR

export LANG=en_US.UTF-8

cdpath=($HOME/Code/Rails $HOME/Code/Java)

source $DOTFILES_DIR/rails.zsh

# rbenv https://github.com/rbenv/rbenv
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi
