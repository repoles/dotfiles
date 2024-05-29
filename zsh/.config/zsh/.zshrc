# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source "${ZDOTDIR}/functions.zsh"
source "${ZDOTDIR}/history.zsh"
source "${ZDOTDIR}/exports.zsh"
source "${ZDOTDIR}/aliases.zsh"
source "${ZDOTDIR}/completions.zsh"

zsh_add_plugin "romkatv/powerlevel10k"
zsh_add_plugin "zsh-users/zsh-autosuggestions"
zsh_add_plugin "zsh-users/zsh-syntax-highlighting"
# zsh_add_plugin "zsh-users/zsh-completions"
# zsh_add_plugin "Aloxaf/fzf-tab"

ZSH_HIGHLIGHT_PATTERNS+=('rm -rf *' 'fg=white,bold,bg=red')
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern) # default: main
ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red # default: fg=red,bold

setopt autocd   # change directories by simply typing the directory name without the cd command
setopt correct  # suggests command corrections if you mistype a command

path=($path $HOME/Code/Scripts)

# Shell integrations

# https://mise.jdx.dev
eval "$(mise activate zsh)"

# https://github.com/junegunn/fzf
source <(fzf --zsh)

# https://github.com/ajeetdsouza/zoxide
eval "$(zoxide init zsh --cmd j)"

# To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
[[ ! -f "${ZDOTDIR}"/.p10k.zsh ]] || source "${ZDOTDIR}"/.p10k.zsh
