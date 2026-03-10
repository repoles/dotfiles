function custom_pwd_prompt --description 'Custom pwd prompt'
    set -l path $PWD
    set -l cwd_color (set_color $fish_color_cwd)
    set -l cwd_bold_color (set_color --bold $fish_color_cwd)
    set -l color_reset (set_color normal)

    if set -q argv[1]
        set path $argv[1]
    end

    if test "$path" = "$HOME"
        set path '~'
    else if string match -q -- "$HOME/*" $path
        set path "~/"(string replace -- "$HOME/" '' $path)
    end

    if test "$path" = '/'
        printf '%s/%s' "$cwd_bold_color" "$color_reset"
        return
    end

    set -l parts (string split / -- $path)
    set -l current $parts[-1]
    set -l prefix_parts

    if test (count $parts) -gt 1
        for part in $parts[1..-2]
            if test -z "$part"
                set prefix_parts $prefix_parts ''
                continue
            end

            if test "$part" = '~'
                set prefix_parts $prefix_parts '~'
                continue
            end

            set prefix_parts $prefix_parts (string replace -r '^(\.?[^/]).*$' '$1' -- $part)
        end
    end

    if test (count $prefix_parts) -gt 0
        set -l prefix (string join / -- $prefix_parts)

        if test -n "$prefix"
            printf '%s%s/' "$cwd_color" "$prefix"
        else
            printf '%s/' "$cwd_color"
        end
    end

    printf '%s%s%s' "$cwd_bold_color" "$current" "$color_reset"
end
