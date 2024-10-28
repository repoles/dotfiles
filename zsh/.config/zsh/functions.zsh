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
zsh_stats() {
  history -n 1 | awk '{gsub(/^sudo /, "")}1' | awk '{print $1}' | sort | uniq -c | sort -rn | awk '{sum+=$1} {lines[NR]=$0} END {for(i=1;i<=20;i++) {split(lines[i],a," "); printf "%2d. %5d %6.2f%% %s\n", i, a[1], (a[1]/sum)*100, a[2]}}'
}

# https://github.com/Phantas0s/.dotfiles
ex() {
  case $1 in
    *.tar.bz2)  tar xjf $1      ;;
    *.tar.gz)   tar xzf $1      ;;
    *.bz2)      bunzip2 $1      ;;
    *.gz)       gunzip $1       ;;
    *.tar)      tar xf $1       ;;
    *.tbz2)     tar xjf $1      ;;
    *.tgz)      tar xzf $1      ;;
    *.zip)      unzip $1        ;;
    *.7z)       7z x $1         ;; # require p7zip
    *.rar)      7z x $1         ;; # require p7zip
    *.iso)      7z x $1         ;; # require p7zip
    *.Z)        uncompress $1   ;;
    *)          echo "'$1' cannot be extracted" ;;
  esac
}

# Fix macOS Terminal title after a SSH session
# https://superuser.com/a/339946/567904
ssh() {
  command ssh "$@"
  printf '\e]0;\a'
}
