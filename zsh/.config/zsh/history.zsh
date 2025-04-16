HISTSIZE=10000      # controls the maximum number of commands stored in memory during a session
SAVEHIST=$HISTSIZE  # controls how many commands are written to the history file for future sessions
HISTDUP=erase       # all duplicate history entries are erased as new commands are entered

HISTFILE="${XDG_STATE_HOME}/zsh/history"
mkdir -p "$HISTFILE:h"

setopt append_history           # commands are added to the history file incrementally
setopt share_history            # commands entered in one session are instantly available in another
setopt extended_history         # adds information such as the date and time each command was executed
setopt hist_ignore_space        # commands that begin with a space character are not saved in the history
# setopt hist_ignore_all_dups   # if an identical command already exists in the history, it won't save the new entry
# setopt hist_save_no_dups      # duplicated commands are discarded when saving history to the history file
setopt hist_ignore_dups         # when a command is repeated, the previous occurrence of the command is deleted from the history
setopt hist_find_no_dups        # while performing history searches, duplicate entries are skipped
# setopt hist_expire_dups_first # makes the history mechanism delete duplicates first when it needs to expire old entries from the history file
setopt hist_verify              # show command with history expansion to user before running it
# setopt hist_reduce_blanks     # removes excessive blanks from each command before saving it to the history file
# setopt inc_append_history     # writes each command to the history file as soon as it is executed
