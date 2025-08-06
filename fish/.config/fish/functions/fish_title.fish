function fish_title
  set -l command (status current-command)
  if test "$command" = fish
    echo -- (prompt_pwd -d 1 -D 1 | string shorten --max 20 --left)
  else
    echo -- (string sub -l 20 -- $argv[1] | string trim)
  end
end
