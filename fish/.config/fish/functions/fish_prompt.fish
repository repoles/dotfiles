# name: My Simple Prompt
# author: Lucas Repolês

function fish_prompt --description 'Write out the prompt'
    set -l last_status $status
    set -l normal (set_color normal)

    set -l login_part ''
    set -l cwd_part ''
    set -l vcs_part ''
    set -l duration_part ''
    set -l date_part ''
    set -l suffix \u276f # ❯

    # login
    if set -q SSH_CLIENT; or set -q SSH_TTY; or set -q SSH_CONNECTION
        set login_part (prompt_login) ' '
    end

    # cwd
    set cwd_part (set_color $fish_color_cwd) (prompt_pwd) $normal

    # vcs
    set vcs_part (fish_git_prompt) $normal

    # duration
    if test $CMD_DURATION -gt 5000
        set -l secs (math --scale=0 $CMD_DURATION/1000 % 60)
        set -l mins (math --scale=0 $CMD_DURATION/60000 % 60)
        set -l hours (math --scale=0 $CMD_DURATION/3600000)

        test $hours -gt 0 && set -a duration_part $hours'h'
        test $mins -gt 0 && set -a duration_part $mins'm'
        test $secs -gt 0 && set -a duration_part $secs's'

        set duration_part (set_color yellow) (string join ' ' $duration_part) $normal
    end

    # date
    set date_part (set_color brblack) (date '+%H:%M:%S') $normal

    # suffix
    if test $last_status -ne 0
        set suffix (set_color $fish_color_error) $suffix $normal
    else
        set suffix (set_color $fish_color_command) $suffix $normal
    end

    set -l line1 $login_part $cwd_part $vcs_part $duration_part
    set -l line2 $date_part ' ' $suffix ' '

    string join '' -- \n $line1 \n $line2
end
