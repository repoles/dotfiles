function humanize_duration --description 'Convert duration in milliseconds to human-readable format'
    # Use argument if provided, otherwise fall back to CMD_DURATION
    set -l duration
    if test (count $argv) -ge 1 && test -n "$argv[1]"
        set duration $argv[1]
    else
        set duration $CMD_DURATION
    end

    if test $duration -lt 1000
        echo $duration'ms'
    else
        set -l secs (math --scale=0 "$duration/1000 % 60")
        set -l mins (math --scale=0 "$duration/60000 % 60")
        set -l hours (math --scale=0 "$duration/3600000")

        # Initialize local result variable
        set -l result

        test $hours -gt 0 && set -a result $hours'h'
        test $mins -gt 0 && set -a result $mins'm'
        test $secs -gt 0 && set -a result $secs's'

        echo $result
    end
end
