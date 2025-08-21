# name: My Custom Prompt
# author: Lucas Repolês

function fish_prompt --description 'Write out the prompt'
    set -l last_pipestatus $pipestatus
    set -lx __fish_last_status $status # Export for __fish_print_pipestatus.
    set -l normal (set_color normal)
    set -q fish_color_status
    or set -g fish_color_status red

    # echo "$(date +'%Y-%m-%d %H:%M:%S') fish_prompt" >> $TMPDIR/git_status.log

    # Color the prompt differently when we're root
    set -l color_cwd $fish_color_cwd
    set -l suffix '>'
    if functions -q fish_is_root_user; and fish_is_root_user
        if set -q fish_color_cwd_root
            set color_cwd $fish_color_cwd_root
        end
        set suffix '#'
    end

    # Write pipestatus
    # If the status was carried over (if no command is issued or if `set` leaves the status untouched), don't bold it.
    set -l bold_flag --bold
    set -q __fish_prompt_status_generation; or set -g __fish_prompt_status_generation $status_generation
    if test $__fish_prompt_status_generation = $status_generation
        set bold_flag
    end
    set __fish_prompt_status_generation $status_generation
    set -l status_color (set_color $fish_color_status)
    set -l statusb_color (set_color $bold_flag $fish_color_status)
    set -l prompt_status (__fish_print_pipestatus "[" "]" "|" "$status_color" "$statusb_color" $last_pipestatus)

    # Only show login info in SSH sessions
    set -l login_info ''
    if set -q SSH_CLIENT; or set -q SSH_TTY; or set -q SSH_CONNECTION
        set login_info (prompt_login)' '
    end

    # Don't show git info in TMUX sessions
    # set -l git_info ''
    # if not set -q TMUX
    #     set git_info (fish_git_prompt)
    # end

    set -l cmd_duration ''
    if test $CMD_DURATION -gt 5000
        set -l secs (math --scale=0 $CMD_DURATION/1000 % 60)
        set -l mins (math --scale=0 $CMD_DURATION/60000 % 60)
        set -l hours (math --scale=0 $CMD_DURATION/3600000)

        test $hours -gt 0 && set -a cmd_duration $hours'h'
        test $mins -gt 0 && set -a cmd_duration $mins'm'
        test $secs -gt 0 && set -a cmd_duration $secs's'

        set cmd_duration (set_color yellow) (string join ' ' $cmd_duration)
    end

    echo -n -s $login_info (set_color $color_cwd) (prompt_pwd) $normal (fish_git_prompt) $cmd_duration $normal ' '$prompt_status $suffix ' '
end
