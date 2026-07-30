function custom_prompt_ssh
    # Only show the user@host section when the shell was reached over SSH.
    # SSH_CONNECTION and SSH_CLIENT come from sshd, SSH_TTY only when a tty
    # was allocated, so checking all three covers the usual setups.
    set -q SSH_CONNECTION; or set -q SSH_CLIENT; or set -q SSH_TTY; or return

    set -l ssh_str "$USER@"(prompt_hostname)
    if set -q custom_prompt_ssh_symbol
        set ssh_str "$custom_prompt_ssh_symbol $ssh_str"
    end

    if set -q custom_prompt_ssh_color
        echo -n (set_color $custom_prompt_ssh_color)"$ssh_str"(set_color normal)
    else
        echo -n "$ssh_str"
    end
end
