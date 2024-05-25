# https://www.youtube.com/watch?v=bTLYiNvRIVI
zsh_add_plugin() {
  PLUGIN_DIR="$XDG_DATA_HOME/zsh/plugins"
  PLUGIN_NAME=$(echo $1 | cut -d "/" -f 2)
  if [ -d "$PLUGIN_DIR/$PLUGIN_NAME" ]; then
    zsh_add_file "$PLUGIN_DIR/$PLUGIN_NAME/$PLUGIN_NAME.zsh" || \
    zsh_add_file "$PLUGIN_DIR/$PLUGIN_NAME/$PLUGIN_NAME.plugin.zsh" || \
    zsh_add_file "$PLUGIN_DIR/$PLUGIN_NAME/$PLUGIN_NAME.zsh-theme"
  else
    echo "Installing $PLUGIN_NAME..."
    git clone --depth=1 --quiet "https://github.com/$1.git" "$PLUGIN_DIR/$PLUGIN_NAME" && \
    zsh_add_plugin "$@"
  fi
}

zsh_add_file() {
  [ -f "$1" ] && source "$1"
}

# https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/functions.zsh
function zsh_stats() {
  fc -l 1 \
    | awk '{ CMD[$2]++; count++; } END { for (a in CMD) print CMD[a] " " CMD[a]*100/count "% " a }' \
    | grep -v "./" | sort -nr | head -n 20 | column -c3 -s " " -t | nl
}

# Fix macOS Terminal title after a SSH session
# https://superuser.com/a/339946/567904
ssh() {
  command ssh "$@"
  printf '\e]0;\a'
}
