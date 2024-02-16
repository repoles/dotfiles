# https://wiki.archlinux.org/title/XDG_Base_Directory

export HISTFILE="$XDG_STATE_HOME"/zsh/history
mkdir -p $(dirname "$HISTFILE")
export HISTSIZE=50000
export SAVEHIST=10000

export VISUAL=vim
export EDITOR="$VISUAL"
export BUNDLER_EDITOR="code"
export LANG=en_US.UTF-8

export ASDF_CONFIG_FILE="${XDG_CONFIG_HOME}"/asdf/asdfrc
export ASDF_DATA_DIR="${XDG_DATA_HOME}"/asdf

export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME"/ripgrep/config

export BUNDLE_USER_CONFIG="$XDG_CONFIG_HOME"/bundle
export BUNDLE_USER_CACHE="$XDG_CACHE_HOME"/bundle
export BUNDLE_USER_PLUGIN="$XDG_DATA_HOME"/bundle

export ZSHZ_DATA="$XDG_STATE_HOME"/z/history
mkdir -p $(dirname "$ZSHZ_DATA")
export ZSHZ_CMD=j

export IRBRC="$XDG_CONFIG_HOME"/irb/irbrc
mkdir -p "$XDG_STATE_HOME"/irb

export AWS_SHARED_CREDENTIALS_FILE="$XDG_DATA_HOME"/aws/credentials
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME"/aws/config

export VIMINIT="set nocp | source ${XDG_CONFIG_HOME}/vim/vimrc"

export MYSQL_HISTFILE="$XDG_STATE_HOME"/mysql/history
mkdir -p $(dirname "$MYSQL_HISTFILE")

fpath=($ZDOTDIR/completions $HOMEBREW_PREFIX/share/zsh/site-functions $fpath)
path=($path $HOME/Code/Scripts)

# Usa openssl 1.1 para compilar o Ruby instalado pelo rbenv
# https://github.com/rbenv/ruby-build/wiki#macos
# Sem essa configuração, o openssl será baixado em cada instalação do Ruby
# export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$HOMEBREW_PREFIX/opt/openssl@1.1"

# Elimina espaço extra colocado pelo ZSH no fim da seção da direita do prompt
# https://github.com/romkatv/powerlevel10k/issues/68#issuecomment-492010264
# export ZLE_RPROMPT_INDENT=0

# https://developer.1password.com/docs/ssh/get-started#step-4-configure-your-ssh-or-git-client
# mkdir -p ~/.1password && ln -s ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ~/.1password/agent.sock
# 30/01/2023: ainda não consegui utilizar o 1Password como agente de forma prática
# export SSH_AUTH_SOCK=~/.1password/agent.sock

# Para que ao excluir usando OPTION + DELETE a
# exclusão pare em caracteres como -, _, ., etc.
export WORDCHARS=""
