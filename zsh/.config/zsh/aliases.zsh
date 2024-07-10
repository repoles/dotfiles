# Some shortcuts for different directory listings
# alias ls='ls -h -G'                          # classify files in colour
# alias ll='ls -l'                             # long list
# alias la='ls -A'                             # all but . and ..
# alias ldot='ls -d .*'                        # list only dotfiles

alias ..='cd ../'                            # Go back 1 directory level
alias ...='cd ../../'                        # Go back 2 directory levels

# Default to human readable figures
alias df='df -h'
alias du='du -h'

# Interactive operation
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -i'

# eza instead of ls
alias ls='eza --icons --grid'
alias ll='eza --icons --long'
alias la='eza --icons --all'
alias ldot='eza --icons --all --list-dirs .*'
alias tree='eza --icons --tree --level=2'

# bat instead of cat
alias cat='bat -pp'

# Ruby on Rails
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

# Misc :)
alias path='echo -e ${PATH//:/\\n}'          # print the PATH entries
alias fpath='echo -e ${FPATH//:/\\n}'        # print the FPATH entries
alias grep='grep --ignore-case --color'      # show differences in colour
alias hhistory='fc -i -l 1'                  # all history with timestamp

# Storage information on macOS
alias storage='df -H /System/Volumes/Data | awk "{print \$1,\$2,\$3,\$4,\$5}" | column -t'
