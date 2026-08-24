# This lives in conf.d, and not in config.fish, because fish sources conf.d for
# every shell it starts — interactive or not. Non-interactive shells are the
# ones tmux uses to run the claude/codex windows, and activating mise from
# inside `status is-interactive` left them with the system runtimes.
# The homebrew formula used to ship this same file as vendor_conf.d/mise-activate.fish.
if status is-interactive
    $HOME/.local/bin/mise activate fish | source
else
    # Shims resolve the version from the directory the command runs in, rather
    # than freezing whichever one was current when the shell started.
    $HOME/.local/bin/mise activate fish --shims | source
end
