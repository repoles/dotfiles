function custom_prompt_git
    set -l branch (git branch --show-current 2>/dev/null)
    test -n "$branch"; or return

    # Section 1: branch
    set -l branch_str
    if set -q custom_prompt_git_branch_symbol
        set branch_str "$custom_prompt_git_branch_symbol $branch"
    else
        set branch_str $branch
    end

    if test -n "$(git status --porcelain 2>/dev/null)"
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
    if git rev-parse @{upstream} &>/dev/null
        set -l ahead (git rev-list --count @{upstream}..HEAD 2>/dev/null)
        set -l behind (git rev-list --count HEAD..@{upstream} 2>/dev/null)

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
