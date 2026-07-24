require "fileutils"

# IRB opens the history file with File.open(..., "w") and never creates its
# parent directory, so we do it here — when irb actually starts, instead of on
# every shell startup.
history_dir = File.join(ENV["XDG_DATA_HOME"], "irb")
FileUtils.mkdir_p(history_dir)

IRB.conf[:SAVE_HISTORY] ||= 1000
IRB.conf[:HISTORY_FILE] ||= File.join(history_dir, "history_#{File.basename(Dir.pwd)}")

# I don't like the IRB autocomplete
IRB.conf[:USE_AUTOCOMPLETE] = false
