function fish_git_prompt --description 'Custom git prompt'
    # Check if we're in a git repo
    set -l branch (command git symbolic-ref --short HEAD 2>/dev/null)
    or set -l branch (command git describe --tags --exact-match HEAD 2>/dev/null)
    or set -l branch (command git rev-parse --short HEAD 2>/dev/null)
    or return

    set -l use_color false
    if set -q __fish_git_prompt_showcolorhints
        and test "$__fish_git_prompt_showcolorhints" = true
        set use_color true
    end

    set -l color_branch ''
    set -l color_upstream ''
    set -l color_reset ''

    if test "$use_color" = true
        if set -q __fish_git_prompt_color_branch
            set color_branch (set_color $__fish_git_prompt_color_branch)
            set color_reset (set_color normal)
        end
        if set -q __fish_git_prompt_color
            set color_upstream (set_color $__fish_git_prompt_color)
            set color_reset (set_color normal)
        end
    end

    # Dirty indicator
    set -l dirty ''
    if not command git diff --quiet HEAD 2>/dev/null
        or test (command git status --porcelain 2>/dev/null | count) -gt 0
        set dirty '*'
    end

    # Upstream ahead/behind
    set -l upstream ''
    set -l ahead (command git rev-list --count '@{upstream}..HEAD' 2>/dev/null)
    set -l behind (command git rev-list --count 'HEAD..@{upstream}' 2>/dev/null)

    set -l char_ahead '>'
    set -l char_behind '<'
    if set -q __fish_git_prompt_char_upstream_ahead
        set char_ahead $__fish_git_prompt_char_upstream_ahead
    end
    if set -q __fish_git_prompt_char_upstream_behind
        set char_behind $__fish_git_prompt_char_upstream_behind
    end

    if test -n "$ahead" -a "$ahead" -gt 0
        set upstream "$upstream$char_ahead$ahead"
    end
    if test -n "$behind" -a "$behind" -gt 0
        set upstream "$upstream$char_behind$behind"
    end

    # Build output
    set -l result ''
    set -l icon \uf126

    set result "$color_branch$icon $branch$dirty$color_reset"

    if test -n "$upstream"
        set result "$result $color_upstream$upstream$color_reset"
    end

    printf '%s' $result
end
