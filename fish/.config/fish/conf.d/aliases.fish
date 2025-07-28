function ls --wraps eza
    eza --icons --grid $argv
end

function ll --wraps eza
    eza --icons --long $argv
end

function cat --wraps bat
    bat -pp $argv
end

function storage --description "Display storage information on macOS"
    df -H /System/Volumes/Data | awk "{print \$1,\$2,\$3,\$4,\$5}" | column -t
end
