# Aliases
# #######

# Some example alias instructions
# If these are enabled they will be used instead of any instructions
# they may mask.  For example, alias rm='rm -i' will mask the rm
# application.  To override the alias instruction use a \ before, ie
# \rm will call the real rm not the alias.

# Interactive operation...
alias rm='rm -i'
alias cp='cp -iv'
alias mv='mv -iv'

# Default to human readable figures
alias df='df -h'
alias du='du -h'

# Misc :)
#alias less='less -r'                         # raw control characters
#alias whence='type -a'                       # where, of a sort
alias grep='grep --color'                     # show differences in colour
alias path='echo -e ${PATH//:/\\n}'

# Some shortcuts for different directory listings
alias ls='ls -h -G'                           # classify files in colour
alias ll='ls -l'                              # long list
alias la='ls -A'                              # all but . and ..

#alias cd..='cd ../'                          # Go back 1 directory level (for fast typers)
#alias ..='cd ../'                            # Go back 1 directory level
#alias ...='cd ../../'                        # Go back 2 directory levels
#alias .3='cd ../../../'                      # Go back 3 directory levels
#alias .4='cd ../../../../'                   # Go back 4 directory levels
#alias .5='cd ../../../../../'                # Go back 5 directory levels
#alias .6='cd ../../../../../../'             # Go back 6 directory levels

alias qfind="find . -name "                  # qfind: Quickly search for file
alias myip='curl ifconfig.co'                # myip: Public facing IP Address
alias f='open -a Finder ./'                  # f: Opens current directory in Finder
alias ~="cd ~"                               # ~: Go Home
