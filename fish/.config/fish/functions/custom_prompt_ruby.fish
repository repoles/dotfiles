function custom_prompt_ruby
    # Walk up the directory tree looking for a .ruby-version file,
    # which is what mise reads to pick the Ruby version for the project.
    set -l dir $PWD
    set -l version_file
    while true
        if test -f "$dir/.ruby-version"
            set version_file "$dir/.ruby-version"
            break
        end
        test "$dir" = / ; and break
        set dir (dirname -- "$dir")
    end

    test -n "$version_file"; or return

    # The file may contain a bare version (3.4.9) or a "ruby-" prefix.
    set -l ruby_version (string trim -- (cat -- "$version_file" 2>/dev/null)[1])
    set ruby_version (string replace -r '^ruby-' '' -- $ruby_version)
    test -n "$ruby_version"; or return

    set -l ruby_str $ruby_version
    if set -q custom_prompt_ruby_symbol
        set ruby_str "$custom_prompt_ruby_symbol $ruby_version"
    end

    if set -q custom_prompt_ruby_color
        echo -n (set_color $custom_prompt_ruby_color)"$ruby_str"(set_color normal)
    else
        echo -n "$ruby_str"
    end
end
