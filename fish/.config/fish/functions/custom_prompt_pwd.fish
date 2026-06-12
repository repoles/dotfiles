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

    # Find the enclosing git repository root, if any. The repo root is kept
    # spelled out in full so the project name stays readable.
    set -l git_root
    set -l dir $PWD
    while test -n "$dir"
        if test -e "$dir/.git"
            set git_root $dir
            break
        end
        set dir (string replace -r '/[^/]*$' '' -- $dir)
    end

    set -l parts (string split / -- $path)
    set -l current $parts[-1]
    set -l prefix_parts

    # Abbreviate parent directories to their first letter, except the git
    # repository root, which is shown in full.
    if test (count $parts) -gt 1
        set -l abs ''
        for part in $parts[1..-2]
            if test "$part" = '~'
                set abs $HOME
                set -a prefix_parts '~'
                continue
            end
            if test -z "$part"
                set abs ''
                set -a prefix_parts ''
                continue
            end
            set abs "$abs/$part"

            if test -n "$git_root"; and test "$abs" = "$git_root"
                set -a prefix_parts $part
            else
                set -a prefix_parts (string replace -r '^(\.?[^/]).*$' '$1' -- $part)
            end
        end
    end

    # Build and print the full path (the current directory is never abbreviated)
    set -a prefix_parts "$current"
    set -l result (string join / -- $prefix_parts)
    printf '%s%s%s' "$pwd_color" "$result" "$color_reset"
end
