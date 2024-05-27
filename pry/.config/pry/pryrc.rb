Pry.config.history.file = File.join(ENV["XDG_STATE_HOME"], "pry", "history_#{File.basename(Dir.pwd)}")

if defined?(PryByebug)
  Pry.commands.alias_command 'c', 'continue'
  Pry.commands.alias_command 's', 'step'
  Pry.commands.alias_command 'n', 'next'
  Pry.commands.alias_command 'f', 'finish'
end
