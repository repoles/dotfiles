#!/usr/bin/env fish
# Usage: git_status.fish /path

# just for logging purposes
# echo "$(date +'%Y-%m-%d %H:%M:%S') git_status for $argv[1]" >> $TMPDIR/git_status.log

set -l p $argv[1]
if test -z "$p" -o ! -d "$p"
    exit 0
end

cd $p

# Configure fish_git_prompt for this one-off process
# set -g __fish_git_prompt_show_informative_status true
set -g __fish_git_prompt_showupstream informative

# set -g __fish_git_prompt_char_cleanstate ''
# set -g __fish_git_prompt_char_stateseparator ' '
# set -g __fish_git_prompt_char_dirtystate '*'
# set -g __fish_git_prompt_char_stagedstate '+'
# set -g __fish_git_prompt_char_upstream_ahead '>'
# set -g __fish_git_prompt_char_upstream_behind '<'

fish_git_prompt
