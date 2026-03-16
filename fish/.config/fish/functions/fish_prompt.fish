function fish_prompt
    set -l last_status $status
    set -l last_duration $CMD_DURATION

    # Line 1: directory | git info | command duration
    set -l line1 (custom_prompt_pwd)

    set -l git_info (custom_prompt_git)
    if test -n "$git_info"
        set line1 "$line1 $git_info"
    end

    set -l duration_threshold 5000
    set -q custom_prompt_command_duration_threshold
        and set duration_threshold $custom_prompt_command_duration_threshold

    if test "$last_duration" -ge "$duration_threshold"
        set -l duration_str (humanize_duration $last_duration)
        if set -q custom_prompt_command_duration_color
            set line1 "$line1 "(set_color $custom_prompt_command_duration_color)"$duration_str"(set_color normal)
        else
            set line1 "$line1 $duration_str"
        end
    end

    # Line 2: time | prompt symbol
    set -l time_str (date '+%H:%M:%S')
    set -l time_output
    if set -q custom_prompt_time_color
        set time_output (set_color $custom_prompt_time_color)"$time_str"(set_color normal)
    else
        set time_output $time_str
    end

    set -l symbol '>'
    set -q custom_prompt_symbol; and set symbol $custom_prompt_symbol

    set -l symbol_output
    if test $last_status -eq 0
        if set -q custom_prompt_symbol_success_color
            set symbol_output (set_color $custom_prompt_symbol_success_color)"$symbol"(set_color normal)
        else
            set symbol_output $symbol
        end
    else
        if set -q custom_prompt_symbol_failure_color
            set symbol_output (set_color $custom_prompt_symbol_failure_color)"$symbol"(set_color normal)
        else
            set symbol_output $symbol
        end
    end

    echo -s \n $line1
    echo -s "$time_output $symbol_output "
end
