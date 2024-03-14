# History command configuration
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt share_history          # share command history data
setopt auto_pushd             # push the current directory visited on the stack.
setopt pushd_ignore_dups      # do not store duplicates in the stack.
setopt pushd_silent           # do not print the directory stack after pushd or popd.

source "$ZDOTDIR/functions.zsh"
source "$ZDOTDIR/exports.zsh"
source "$ZDOTDIR/aliases.zsh"
source "$ZDOTDIR/completions.zsh"

# Plugins
zsh_add_plugin "zsh-users/zsh-autosuggestions"
zsh_add_plugin "zsh-users/zsh-syntax-highlighting"
zsh_add_plugin "zsh-users/zsh-history-substring-search"
zsh_add_plugin "romkatv/powerlevel10k" "powerlevel10k.zsh-theme"
zsh_add_plugin "agkozak/zsh-z"
unset -f zsh_add_file zsh_add_plugin

ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

ZSH_HIGHLIGHT_PATTERNS+=('rm -rf *' 'fg=white,bold,bg=red')
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern) # default: main
ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red # default: fg=red,bold

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Source all files in $ZDOTDIR/custom that end in .zsh
# for zsh_file in "$ZDOTDIR"/custom/*.zsh; do
#   source "$zsh_file"
# done
# unset zsh_file

# https://direnv.net
eval "$(direnv hook zsh)"

# https://asdf-vm.com
. "$HOMEBREW_PREFIX"/opt/asdf/libexec/asdf.sh

# https://github.com/junegunn/fzf
[ -f "${XDG_CONFIG_HOME}"/fzf/fzf.zsh ] && source "${XDG_CONFIG_HOME}"/fzf/fzf.zsh

# To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
[[ ! -f $ZDOTDIR/.p10k.zsh ]] || source $ZDOTDIR/.p10k.zsh
