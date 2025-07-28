function storage --description 'Display storage information on macOS'
    df -H /System/Volumes/Data | awk "{print \$1,\$2,\$3,\$4,\$5}" | column -t
end
