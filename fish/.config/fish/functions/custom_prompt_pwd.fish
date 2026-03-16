function custom_prompt_pwd
    set -l path $PWD
    set -l pwd_color ''
    if set -q custom_prompt_pwd_color
        set pwd_color (set_color $custom_prompt_pwd_color)
    end
    set -l color_reset (set_color normal)

    # Replace $HOME with ~
    if test "$path" = "$HOME"
        printf '%s%s%s' "$pwd_color" '~' "$color_reset"
        return
    else if string match -q -- "$HOME/*" $path
        set path "~/"(string replace -- "$HOME/" '' $path)
    end

    set -l parts (string split / -- $path)
    set -l current $parts[-1]
    set -l prefix_parts

    # Abbreviate parent directories to first letter
    if test (count $parts) -gt 1
        for part in $parts[1..-2]
            if test -z "$part"
                set -a prefix_parts ''
                continue
            end
            if test "$part" = '~'
                set -a prefix_parts '~'
                continue
            end
            set -a prefix_parts (string replace -r '^(\.?[^/]).*$' '$1' -- $part)
        end
    end

    # Build and print the full path
    set -a prefix_parts "$current"
    set -l result (string join / -- $prefix_parts)
    printf '%s%s%s' "$pwd_color" "$result" "$color_reset"
end
