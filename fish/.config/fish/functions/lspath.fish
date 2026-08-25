function lspath --description "List PATH entries with line numbers"
    printf '%s\n' $PATH | nl
end
