function mysql --wraps=mysql
    # The client writes $MYSQL_HISTFILE but will not create its directory, and
    # .my.cnf has no hook to do it. Creating it here keeps the cost on the rare
    # mysql call instead of on every shell startup.
    mkdir -p (dirname $MYSQL_HISTFILE)
    command mysql $argv
end
