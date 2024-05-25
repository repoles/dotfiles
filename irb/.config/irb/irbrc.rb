IRB.conf[:SAVE_HISTORY] ||= 1000
IRB.conf[:HISTORY_FILE] ||= File.join(ENV["XDG_STATE_HOME"], "irb", "history_#{File.basename(Dir.pwd)}")

# Esse autocomplete mais atrapalha que ajuda
IRB.conf[:USE_AUTOCOMPLETE] = false
