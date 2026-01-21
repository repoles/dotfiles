# Ruby on Rails
abbr --add rdc "bin/rails db:create"
abbr --add rdd "bin/rails db:drop"
abbr --add rdm "bin/rails db:migrate"
abbr --add rdr "bin/rails db:rollback"
abbr --add rds "bin/rails db:seed"

abbr --add rc "bin/rails console"
abbr --add rs "bin/rails server"

abbr --add rcs "bin/rails console --sandbox"

abbr --add devlog  "tail -f log/development.log"
abbr --add prodlog "tail -f log/production.log"
abbr --add testlog "tail -f log/test.log"

abbr --position anywhere --add RED "RAILS_ENV=development"
abbr --position anywhere --add REP "RAILS_ENV=production"
abbr --position anywhere --add RET "RAILS_ENV=test"

# git
abbr --add gs "git status"
abbr --add gl "git log"

# tmux
abbr --add tclear "clear; tmux clear-history"

# misc
abbr --add cp "cp -iv"
abbr --add mv "mv -iv"
abbr --add rm "rm -i"

abbr --add --position anywhere G "| rg -n"
