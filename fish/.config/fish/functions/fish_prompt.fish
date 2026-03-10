function fish_prompt --description 'Custom fish prompt'
    set -l last_status $status
    set -l color_reset (set_color normal)

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
    set cwd_part (custom_pwd_prompt)

    # vcs
    set -l git_info (custom_git_prompt)
    if test -n "$git_info"
        set vcs_part ' ' $git_info
    end

    # duration
    if test $CMD_DURATION -gt 5000
        set duration_part (set_color yellow) ' ' (humanize_duration) $color_reset
    end

    # date
    set date_part (set_color brblack) (date '+%H:%M:%S') $color_reset

    # suffix
    if test $last_status -ne 0
        set suffix (set_color $fish_color_error) $suffix $color_reset
    else
        set suffix (set_color $fish_color_command) $suffix $color_reset
    end

    set -l line1 $login_part $cwd_part $vcs_part $duration_part
    set -l line2 $date_part ' ' $suffix ' '

    string join '' -- \n $line1 \n $line2
end
