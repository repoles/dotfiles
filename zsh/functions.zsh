# https://github.com/Mach-OS/Machfiles
# https://www.youtube.com/watch?v=bTLYiNvRIVI

# Function to source files if they exist
zsh_add_file() {
  [ -f "$1" ] && source "$1"
}

zsh_add_plugin() {
  PLUGIN_DIR="$XDG_DATA_HOME/zsh_plugins"
  PLUGIN_NAME=$(echo $1 | cut -d "/" -f 2)
  if [ -d "$PLUGIN_DIR/$PLUGIN_NAME" ]; then
    zsh_add_file "$PLUGIN_DIR/$PLUGIN_NAME/$PLUGIN_NAME.plugin.zsh" || \
    zsh_add_file "$PLUGIN_DIR/$PLUGIN_NAME/$PLUGIN_NAME.zsh" || \
    zsh_add_file "$PLUGIN_DIR/$PLUGIN_NAME/$2"
  else
    git clone --depth=1 "https://github.com/$1.git" "$PLUGIN_DIR/$PLUGIN_NAME" && \
    zsh_add_plugin "$@"
  fi
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

# https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/functions.zsh
zsh_stats() {
  fc -l 1 \
    | awk '{ CMD[$2]++; count++; } END { for (a in CMD) print CMD[a] " " CMD[a]*100/count "% " a }' \
    | grep -v "./" | sort -nr | head -n 20 | column -c3 -s " " -t | nl
}

# Corrige o título do terminal após fechar uma sessão ssh
# https://superuser.com/a/339946/567904
ssh() {
  command ssh "$@"
  printf '\e]0;\a'
}

# https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/encode64/encode64.plugin.zsh
encode64() {
  if [[ $# -eq 0 ]]; then
    cat | base64
  else
    printf '%s' $1 | base64
  fi
}

decode64() {
  if [[ $# -eq 0 ]]; then
    cat | base64 --decode
  else
    printf '%s' $1 | base64 --decode
  fi
}

# This function will create all the necessary parent
# directories for the given file path, but it will
# not create the file itself. Created by ChatGPT 4.
create_directories_for_file() {
  # Extract the directory path from the full file path
  dir_path=$(dirname "$1")

  # Create the directory path, if it doesn't exist
  mkdir -p "$dir_path"
}
