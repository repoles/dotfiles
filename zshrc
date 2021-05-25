# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Pat hto your oh-my-zsh installation.
export ZSH="/Users/repoles/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes

# https://github.com/denysdovhan/spaceship-prompt
ZSH_THEME="spaceship" 

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
export UPDATE_ZSH_DAYS=30

# Uncomment the following line if pasting URLs and other text is messed up.
DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git 
  rails 
  zsh-autosuggestions 
  zsh-syntax-highlighting 
  history-substring-search
)

# https://github.com/zsh-users/zsh-autosuggestions
# https://github.com/zsh-users/zsh-syntax-highlighting
# https://github.com/zsh-users/zsh-history-substring-search

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='code --wait'
# fi

export EDITOR='vim'

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias ldot='ls -ld .*'

# Interactive operation...
alias rm='rm -i'
alias cp='cp -iv'
alias mv='mv -iv'

# Default to human readable figures
alias df='df -h'
alias du='du -h'

alias dud='du -d 1 -h'
alias duf='du -sh *'

alias qfind="find . -name "   # qfind: Quickly search for file
# alias myip='curl ifconfig.co' # myip: Public facing IP Address

alias path='echo -e ${PATH//:/\\n}'

# # nvim instead of vim
# if type nvim > /dev/null 2>&1; then
#   alias vim='nvim'
# fi

# Configurações do spaceship-prompt

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
SPACESHIP_CHAR_SYMBOL="❯ "
SPACESHIP_RUBY_SYMBOL="ruby "
SPACESHIP_GIT_STATUS_BEHIND="↓"
SPACESHIP_GIT_STATUS_AHEAD="↑"

# Configurações do zsh-syntax-highlighting

# https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)

# To have commands starting with `rm -rf` in red:
ZSH_HIGHLIGHT_PATTERNS+=('rm -rf *' 'fg=white,bold,bg=red')

# Configurações do zsh-autosuggestions

# https://github.com/zsh-users/zsh-autosuggestions#disabling-suggestion-for-large-buffers
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# https://github.com/zsh-users/zsh-autosuggestions#enable-asynchronous-mode
ZSH_AUTOSUGGEST_USE_ASYNC=true

# Acesso direto aos subdiretórios de
# cdpath=($HOME/Projects/Rails)

# Corrige o título do terminal após fechar uma sessão ssh
# https://superuser.com/a/339946/567904
function ssh() { command ssh "$@"; printf '\e]0;\a' }

# O Homebrew é instalado em um diretório 
# diferente em Macs com chips ARM
if [ $(uname -m) = "arm64" ]; then
	export PATH=/opt/homebrew/bin:$PATH
fi

export TMP_DIR=$HOME/Temp
export SCRIPTS=$HOME/Projects/Scripts

MYSQL_PATH="$(brew --prefix mysql@5.7)/bin"
export PATH=$PATH:$SCRIPTS:$MYSQL_PATH

# Usa openssl 1.1 para compilar o Ruby instalado pelo rbenv
# https://github.com/rbenv/ruby-build/wiki#suggested-build-environment
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"

# Para que ao excluir usando OPTION + DELETE a 
# exclusão pare em caracteres como -, _, ., etc.
export WORDCHARS=""

# Temporariamente desliga o spring do RoR por causa do alto consumo de CPU no Big Sur.
# Resolvido: https://github.com/rails/spring/issues/636#issuecomment-755404716
# export DISABLE_SPRING=1

# Inicia o rbenv (https://github.com/rbenv/rbenv)
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

# Inicia o autojump (https://github.com/wting/autojump)
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh
