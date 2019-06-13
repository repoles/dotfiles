# Referência: https://carlosbecker.com/posts/speeding-up-zsh/

# Autocompletion
autoload -Uz compinit
typeset -i updated_at=$(date +'%j' -r ~/.zcompdump 2>/dev/null || stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)
if [ $(date +'%j') != $updated_at ]; then
  compinit -i
else
  compinit -C -i
fi

# Commands menu list
zmodload -i zsh/complist 

# Commands history
HISTFILE=$HOME/.zsh_history
HISTSIZE=1000
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

export TEMP_DIR=$HOME/Temp
export SCRIPTS_DIR=$HOME/Code/scripts
export DOTFILES_DIR=$HOME/Code/dotfiles
export USER_EMAIL=repoles@gmail.com

export PATH=/usr/local/opt/mysql@5.6/bin:/usr/local/opt/python/libexec/bin:$PATH:$SCRIPTS_DIR
export LANG=en_US.UTF-8

export WORDCHARS='*?_-[]~=&;!#$%^(){}<>'

cdpath=($HOME/Code/Rails $HOME/Code/Java)

# Plugins
source /usr/local/share/antigen/antigen.zsh # brew install antigen
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-history-substring-search
antigen bundle mafredri/zsh-async
antigen theme denysdovhan/spaceship-prompt
antigen apply

source $DOTFILES_DIR/rails.plugin.zsh
source $DOTFILES_DIR/bundler.plugin.zsh
source $DOTFILES_DIR/aliases.zsh

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

SPACESHIP_PROMPT_ORDER=(
  time          # Time stamps section
  user          # Username section
  dir           # Current directory section
  host          # Hostname section
  git           # Git section (git_branch + git_status)
  ruby          # Ruby section
  exec_time     # Execution time
  line_sep      # Line break
  battery       # Battery level and status
  jobs          # Background jobs indicator
  char          # Prompt character
)

SPACESHIP_TIME_SHOW="true"
SPACESHIP_GIT_STATUS_COLOR="202"
SPACESHIP_RUBY_SYMBOL="ruby "
# SPACESHIP_GIT_STATUS_BEHIND="↓"
# SPACESHIP_GIT_STATUS_AHEAD="↑"

# Para que o título da janela e da aba do Terminal possa
# ser definido com base nas configurações do aplicativo
# Referência: /etc/bashrc_Apple_Terminal
precmd () { printf '\e]7;%s\a' "file://$HOSTNAME$PWD" }

# Corrige o título do terminal após fechar uma sessão ssh
# https://superuser.com/a/339946/567904
function ssh() { command ssh "$@"; printf '\e]0;\a' }

# rbenv https://github.com/rbenv/rbenv
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi
