function fish_user_key_bindings
    # CMD+Left/CMD+Right send Shift+Home/Shift+End from the terminal.
    # Mirror VSCode-style line navigation in the shell.
    bind \e\[1\;2H beginning-of-line
    bind \e\[1\;2F end-of-line
end
