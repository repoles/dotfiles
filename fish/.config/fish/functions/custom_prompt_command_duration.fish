function custom_prompt_command_duration --argument-names duration
    # The duration is passed in rather than read from $CMD_DURATION so the
    # prompt keeps capturing volatile state up front, and so the section can
    # be exercised directly: custom_prompt_command_duration 93000
    test -n "$duration"; or set duration 0

    set -l threshold 5000
    set -q custom_prompt_command_duration_threshold
        and set threshold $custom_prompt_command_duration_threshold

    # Short commands are the common case, so the section stays out of the way
    # until something actually took a while.
    test "$duration" -ge "$threshold"; or return

    set -l duration_str (humanize_duration $duration)
    if set -q custom_prompt_command_duration_symbol
        set duration_str "$custom_prompt_command_duration_symbol $duration_str"
    end

    if set -q custom_prompt_command_duration_color
        echo -n (set_color $custom_prompt_command_duration_color)"$duration_str"(set_color normal)
    else
        echo -n "$duration_str"
    end
end
