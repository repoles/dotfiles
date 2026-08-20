function fzf_insert_paths --description "Pick paths with fzf from the current directory and insert them at the cursor"
    if not command --query fzf
        echo "fzf_insert_paths: fzf is not installed" >&2
        commandline --function repaint
        return 1
    end

    # fd honours .gitignore and prints paths relative to the current directory;
    # find is only a fallback for machines where fd is missing
    if command --query fd
        set --function source_command fd --hidden --exclude .git --strip-cwd-prefix
    else
        set --function source_command find . -mindepth 1 -not -path "*/.git/*"
    end

    # whatever is already typed under the cursor seeds the search, so "cp src/fo<Ctrl+F>"
    # starts filtered; the quotes fish would have added around it are not part of the query
    set --function query (string trim --chars='"\'' -- (commandline --current-token))

    set --function fzf_options --multi --scheme=path --query "$query"
    # fzf runs the preview through $SHELL, so this has to parse in fish as well as sh:
    # && and || are the only branching both understand
    set --append fzf_options --preview 'test -d {} && eza --icons --tree --level 2 --color=always -- {} || bat --style=numbers --color=always --line-range :200 -- {}'
    set --append fzf_options --preview-window right,60%

    set --function selected ($source_command 2>/dev/null | fzf $fzf_options)
    set --function fzf_status $status

    if test $fzf_status -ne 0; or test (count $selected) -eq 0
        commandline --function repaint
        return
    end

    # escaping keeps spaces and other special characters usable as a single argument
    commandline --replace --current-token -- (string escape -- $selected | string join ' ')" "
    commandline --function repaint
end
