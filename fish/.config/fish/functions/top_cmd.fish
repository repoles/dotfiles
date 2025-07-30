function top_cmd
    # Get total number of commands in history
    set total (history | wc -l)

    # Prevent division by zero
    if test $total -eq 0
        echo "No history available."
        return 1
    end

    # to ignore sudo in aws bellow, use {if ($1 == "sudo") print $2; else print $1}

    # Process and format output
    history \
        | awk '{print $1}' \
        | sed 's|.*/||' \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -n 20 \
        | awk -v total=$total 'BEGIN { OFS="\t" }
            {
                count = $1;
                cmd = $2;
                pct = (count / total) * 100;
                printf " %2d. %5d %6.2f%%  %s\n", NR, count, pct, cmd
            }'
end
