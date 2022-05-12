# .zshenv é o primeiro arquivo carregado pelo ZSH e
# é ele quem configura o local de outros arquivos.
# Por isso, deve-se criar um link simbólico para esse
# arquivo em $HOME. Ex: ln -s ~/.config/zsh/.zshenv ~/.

# https://wiki.archlinux.org/title/XDG_Base_Directory
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# zsh
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# rbenv
export RBENV_ROOT="$XDG_DATA_HOME/rbenv"

# Ainda não consegui fazer o RubyGems
# carregar .gemrc de XDG_CONFIG_HOME

# export GEM_HOME="$XDG_DATA_HOME/gem"
# export GEM_SPEC_CACHE="$XDG_CACHE_HOME/gem"

# Comentado, pois optei por deixar o RubyGems usar os locais padrão
# do SO para evitar a instalação de gems no contexto do Ruby padrão

# bundle
export BUNDLE_USER_CONFIG="$XDG_CONFIG_HOME/bundle"
export BUNDLE_USER_CACHE="$XDG_CACHE_HOME/bundle"
export BUNDLE_USER_PLUGIN="$XDG_DATA_HOME/bundle"

# z
export _Z_DATA="$XDG_DATA_HOME/z"
export _Z_CMD=j

# Desliga gerenciamento do histórico implementado
# pelo macOS em /etc/zshrc_Apple_Terminal
export SHELL_SESSIONS_DISABLE=1
