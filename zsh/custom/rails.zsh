# Log aliases
alias devlog='tail -f log/development.log'
alias prodlog='tail -f log/production.log'
alias testlog='tail -f log/test.log'

# Environment settings
alias -g RED='RAILS_ENV=development'
alias -g REP='RAILS_ENV=production'
alias -g RET='RAILS_ENV=test'

# Rails aliases
alias rc='bin/rails console'
alias rcs='bin/rails console --sandbox'

alias rdm='bin/rails db:migrate'
alias rdr='bin/rails db:rollback'

alias rds='bin/rails db:seed'
alias rs='bin/rails server'

alias rdb='bin/rails dbconsole'
