# This is in conf.d, and named so it sorts before mise.fish, because mise has to
# activate after every other PATH change — otherwise homebrew's python3 (and
# anything else it duplicates) shadows the version mise pins for the project.
/opt/homebrew/bin/brew shellenv | source
