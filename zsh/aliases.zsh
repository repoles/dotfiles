# Aliases
# #######

# Some example alias instructions
# If these are enabled they will be used instead of any instructions
# they may mask.  For example, alias rm='rm -i' will mask the rm
# application.  To override the alias instruction use a \ before, ie
# \rm will call the real rm not the alias.

# Interactive operation...
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -i'

# Default to human readable figures
alias df='df -h'
alias du='du -h'

# Some shortcuts for different directory listings
# alias ls='ls -h -G'                          # classify files in colour
# alias ll='ls -l'                             # long list
# alias la='ls -A'                             # all but . and ..
# alias ldot='ls -d .*'                        # list only dotfiles

# alias cd..='cd ../'                          # Go back 1 directory level
# alias ..='cd ../'                            # Go back 1 directory level
# alias ...='cd ../../'                        # Go back 2 directory levels
# alias .3='cd ../../../'                      # Go back 3 directory levels
# alias .4='cd ../../../../'                   # Go back 4 directory levels
# alias .5='cd ../../../../../'                # Go back 5 directory levels
# alias .6='cd ../../../../../../'             # Go back 6 directory levels

# alias d='dirs -v'
# for index ({1..9}) alias "$index"="cd +${index}"; unset index

# Misc :)
alias less='less -r'                         # raw control characters
alias whence='type -a'                       # where, of a sort
alias grep='grep -i --color'                 # show differences in colour
alias path='echo -e ${PATH//:/\\n}'          # print the PATH entries
alias fpath='echo -e ${FPATH//:/\\n}'        # print the FPATH entries
alias myip='curl checkip.amazonaws.com'      # Public facing IP Address

# Melhor usar o dua (https://lib.rs/crates/dua-cli)
# alias dud='du -d 1 -h | sort -h'
# alias duf='du -sh * | sort -h'

# eza instead of ls
alias ls="eza --icons"
alias ll="eza --icons --long"
alias la="eza --icons --long --all"
alias lh="eza --icons --long --all --list-dirs .*"
alias tree="eza --icons --tree --level=2"

# bat instead of cat
alias cat="bat -pp"

# display free disk space
alias storage="df -H /System/Volumes/Data"

# Rails aliases
alias devlog='tail -f log/development.log'
alias prodlog='tail -f log/production.log'
alias testlog='tail -f log/test.log'

alias -g RED='RAILS_ENV=development'
alias -g REP='RAILS_ENV=production'
alias -g RET='RAILS_ENV=test'

alias rc='bin/rails console'
alias rcs='bin/rails console --sandbox'

alias rdm='bin/rails db:migrate'
alias rdr='bin/rails db:rollback'

alias rds='bin/rails db:seed'
alias rs='bin/rails server'

alias rdb='bin/rails dbconsole'

# cd to iCloud Drive
alias icloud="cd $HOME/Library/Mobile\ Documents/com\~apple\~CloudDocs"
