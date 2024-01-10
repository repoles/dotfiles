# https://wiki.archlinux.org/title/XDG_Base_Directory

export HISTFILE="$XDG_STATE_HOME"/zsh/history
create_directories_for_file "$HISTFILE"

export HISTSIZE=50000
export SAVEHIST=10000

export VISUAL=vim
export EDITOR="$VISUAL"
export BUNDLER_EDITOR="code"
export LANG=en_US.UTF-8

export RBENV_ROOT="$XDG_DATA_HOME"/rbenv
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME"/ripgrep/config

export BUNDLE_USER_CONFIG="$XDG_CONFIG_HOME"/bundle
export BUNDLE_USER_CACHE="$XDG_CACHE_HOME"/bundle
export BUNDLE_USER_PLUGIN="$XDG_DATA_HOME"/bundle

export ZSHZ_DATA="$XDG_DATA_HOME"/z
export ZSHZ_CMD=j

export IRBRC="$XDG_CONFIG_HOME/irb/irbrc"

export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME"/aws/credentials
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME"/aws/config

# Elimina espaço extra colocado pelo ZSH no fim da seção da direita do prompt
# https://github.com/romkatv/powerlevel10k/issues/68#issuecomment-492010264
# export ZLE_RPROMPT_INDENT=0

MYSQL_DIR="$HOMEBREW_PREFIX/opt/mysql@5.7/bin"
path=($path $HOME/Code/Scripts $MYSQL_DIR)
unset MYSQL_DIR

fpath=($ZDOTDIR/completions $HOMEBREW_PREFIX/share/zsh/site-functions $fpath)

# Usa openssl 1.1 para compilar o Ruby instalado pelo rbenv
# https://github.com/rbenv/ruby-build/wiki#macos
# Sem essa configuração, o openssl será baixado em cada instalação do Ruby
# export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$HOMEBREW_PREFIX/opt/openssl@1.1"

# Para que ao excluir usando OPTION + DELETE a
# exclusão pare em caracteres como -, _, ., etc.
export WORDCHARS=""

# https://developer.1password.com/docs/ssh/get-started#step-4-configure-your-ssh-or-git-client
# mkdir -p ~/.1password && ln -s ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ~/.1password/agent.sock
# 30/01/2023: ainda não consegui utilizar o 1Password como agente de forma prática
# export SSH_AUTH_SOCK=~/.1password/agent.sock
