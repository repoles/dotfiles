# https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/rails/rails.plugin.zsh

# rails command wrapper
function _rails_command () {
  if [ -e "bin/rails" ]; then
    bin/rails $@
  else
    command rails $@
  fi
}

alias rails='_rails_command'
compdef _rails_command=rails

# rake command wrapper
function _rake_command () {
  if [ -e "bin/rake" ]; then
    bin/rake $@
  elif type bundle &> /dev/null && [[ -e "Gemfile" || -e "gems.rb" ]]; then
    bundle exec rake $@
  else
    command rake $@
  fi
}

alias rake='_rake_command'
compdef _rake_command=rake

# Log aliases
alias devlog='tail -f log/development.log'
alias prodlog='tail -f log/production.log'
alias testlog='tail -f log/test.log'

# Environment settings
alias -g RED='RAILS_ENV=development'
alias -g REP='RAILS_ENV=production'
alias -g RET='RAILS_ENV=test'

# Rails aliases
alias rc='rails console'
alias rcs='rails console --sandbox'

alias rdm='rails db:migrate'
alias rdr='rails db:rollback'

alias rds='rails db:seed'
alias rs='rails server'

alias rdb='rails dbconsole'
