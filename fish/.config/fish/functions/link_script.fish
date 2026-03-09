function link_script --description 'Create symlinks for scripts in a destination directory'
    set -l usage "Usage: link_script [--keep-ext] <script_name> <target_directory>"
    argparse h/help keep-ext -- $argv
    or begin
        echo $usage >&2
        return 1
    end

    if set -q _flag_help
        echo $usage
        echo "By default, the link name removes the script extension."
        echo "Use --keep-ext to keep the extension in the link name."
        return 0
    end

    if test (count $argv) -ne 2
        echo $usage >&2
        return 1
    end

    set script_input "$argv[1]"
    set target_dir_input "$argv[2]"

    if not test -e "$script_input"
        echo "Error: script not found: $script_input" >&2
        return 1
    end

    if test -d "$script_input"
        echo "Error: the provided path is a directory: $script_input" >&2
        return 1
    end

    if not test -d "$target_dir_input"
        echo "Error: target directory does not exist: $target_dir_input" >&2
        return 1
    end

    set script_path (path resolve -- "$script_input")
    set target_dir (path resolve -- "$target_dir_input")
    set script_name (path basename -- "$script_path")

    if set -q _flag_keep_ext
        set link_name "$script_name"
    else
        set link_name (string replace -r '\.[^.]+$' '' -- "$script_name")
    end

    if test -z "$link_name"
        echo "Error: could not determine the link name." >&2
        return 1
    end

    set link_path "$target_dir/$link_name"

    if test -e "$link_path"; or test -L "$link_path"
        echo "Error: a file or symlink already exists at: $link_path" >&2
        return 1
    end

    ln -s "$script_path" "$link_path"
    or begin
        echo "Error: failed to create symlink at: $link_path" >&2
        return 1
    end

    echo "Link created: $link_path -> $script_path"
end
