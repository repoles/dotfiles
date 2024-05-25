# https://wiki.archlinux.org/title/XDG_Base_Directory

# .zshenv é o primeiro arquivo carregado pelo ZSH e é ele
# quem definirá o local de outros arquivos de configurações.

export XDG_CONFIG_HOME="$HOME"/.config
export XDG_CACHE_HOME="$HOME"/.cache
export XDG_DATA_HOME="$HOME"/.local/share
export XDG_STATE_HOME="$HOME"/.local/state

export ZDOTDIR="$XDG_CONFIG_HOME"/zsh

# Desliga gerenciamento do histórico implementado
# pelo macOS em /etc/zshrc_Apple_Terminal
# PRECISA SER DEFINIDO EM .zshenv
export SHELL_SESSIONS_DISABLE=1
