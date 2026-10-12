function custom_prompt_git
    # Read branch, worktree changes and ahead/behind counts in one Git call.
    set -l git_status (git status --porcelain=v2 --branch --ahead-behind 2>/dev/null)
    or return

    set -l branch
    set -l dirty 0
    set -l ahead 0
    set -l behind 0
    for entry in $git_status
        switch $entry
            case '# branch.head *'
                set branch (string replace '# branch.head ' '' -- $entry)
            case '# branch.ab *'
                set -l counts (string split ' ' -- $entry)
                set ahead (string sub --start 2 -- $counts[3])
                set behind (string sub --start 2 -- $counts[4])
            case '# *'
                # Ignore the other porcelain headers.
            case '*'
                set dirty 1
        end
    end

    test -n "$branch"; or return
    test "$branch" != '(detached)'; or return

    # Section 1: branch
    set -l branch_str
    if set -q custom_prompt_git_branch_symbol
        set branch_str "$custom_prompt_git_branch_symbol $branch"
    else
        set branch_str $branch
    end

    if test $dirty -eq 1
        set -l dirty_symbol "*"
        set -q custom_prompt_git_branch_dirty_symbol; and set dirty_symbol $custom_prompt_git_branch_dirty_symbol
        set branch_str "$branch_str$dirty_symbol"
    end

    set -l branch_output
    if set -q custom_prompt_git_branch_color
        set branch_output (set_color $custom_prompt_git_branch_color)"$branch_str"(set_color normal)
    else
        set branch_output $branch_str
    end

    # Section 2: status (ahead/behind)
    set -l status_str ""
    if test "$ahead" -gt 0
        set -l ahead_symbol ">"
        set -q custom_prompt_git_status_ahead_symbol; and set ahead_symbol $custom_prompt_git_status_ahead_symbol
        set status_str "$status_str$ahead_symbol$ahead"
    end

    if test "$behind" -gt 0
        set -l behind_symbol "<"
        set -q custom_prompt_git_status_behind_symbol; and set behind_symbol $custom_prompt_git_status_behind_symbol
        test -n "$status_str"; and set status_str "$status_str "
        set status_str "$status_str$behind_symbol$behind"
    end

    set -l status_output
    if test -n "$status_str"
        if set -q custom_prompt_git_status_color
            set status_output (set_color $custom_prompt_git_status_color)"$status_str"(set_color normal)
        else
            set status_output $status_str
        end
    end

    if test -n "$status_output"
        echo -n "$branch_output $status_output"
    else
        echo -n "$branch_output"
    end
end
