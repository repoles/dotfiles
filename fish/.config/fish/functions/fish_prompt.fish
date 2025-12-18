# name: My Simple Prompt
# author: Lucas Repolês

function fish_prompt --description 'Write out the prompt'
    set -l last_status $status
    set -l normal (set_color normal)

    set -l login_part ''
    set -l cwd_part ''
    set -l vcs_part ''
    set -l duration_part ''
    set -l status_part ''
    # set -l suffix \u276f # ❯
    set -l suffix '>'

    if set -q SSH_CLIENT; or set -q SSH_TTY; or set -q SSH_CONNECTION
        set login_part (prompt_login)' '
    end

    set cwd_part (set_color $fish_color_cwd)(prompt_pwd)$normal
    set vcs_part (fish_git_prompt)$normal

    if test $CMD_DURATION -gt 5000
        set -l secs (math --scale=0 $CMD_DURATION/1000 % 60)
        set -l mins (math --scale=0 $CMD_DURATION/60000 % 60)
        set -l hours (math --scale=0 $CMD_DURATION/3600000)

        test $hours -gt 0 && set -a duration_part $hours'h'
        test $mins -gt 0 && set -a duration_part $mins'm'
        test $secs -gt 0 && set -a duration_part $secs's'

        set duration_part (set_color yellow)(string join ' ' $duration_part)$normal
    end

    if test $last_status -ne 0
        set status_part (set_color $fish_color_error)" [$last_status]"(set_color normal)
    end

    echo -n -s $login_part $cwd_part $vcs_part $duration_part $status_part $suffix ' '
end
