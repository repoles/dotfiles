function __rake_list_tasks
    set -l rake_cmd rake
    if test -x bin/rake
        set rake_cmd bin/rake
    else if type -q bundle; and test -f Gemfile
        set rake_cmd bundle exec rake
    end

    eval $rake_cmd -T 2>/dev/null \
        | string replace -rf '^rake (\S+)\s+#\s+(.*)$' '$1\t$2'
end

function __rake_complete_tasks
    test -f Rakefile; or return

    set -l cache_file tmp/.rake_tasks~
    set -l deps Rakefile
    test -f Gemfile.lock; and set -a deps Gemfile.lock

    set -l stale 1
    if test -f $cache_file
        set stale 0
        for dep in $deps
            if test $dep -nt $cache_file
                set stale 1
                break
            end
        end
    end

    if test $stale -eq 1
        if test -d tmp; or mkdir -p tmp 2>/dev/null
            __rake_list_tasks >$cache_file
        else
            __rake_list_tasks
            return
        end
    end

    cat $cache_file 2>/dev/null
end

complete -c rake -f -a '(__rake_complete_tasks)'
