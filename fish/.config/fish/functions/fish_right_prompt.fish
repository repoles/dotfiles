function fish_right_prompt -d 'Write out the right prompt'
    if contains -- --final-rendering $argv
        set_color brblack
        date '+%H:%M:%S'
    end
end
