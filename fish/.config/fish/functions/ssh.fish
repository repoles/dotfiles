# Fix macOS Terminal title after a SSH session
# https://superuser.com/a/339946/567904
function ssh
    command ssh $argv
    printf '\e]0;\a'
end
