#!/bin/sh
# tmux-toast.sh - show a transient notification in a tmux floating pane.
# Usage: tmux-toast.sh [-l error|warn|ok|info] [-d seconds] [-w width]
#                     [-s style] line [line...]
# An explicit -s overrides -l regardless of option order.
#
# Needs tmux 3.7+ (the new-pane command). The pane is created detached so it
# never steals focus. It is anchored to the bottom right corner; floating panes
# do not re-anchor on resize, but a toast is short lived enough not to care.

die() { printf 'tmux-toast: %s\n' "$1" >&2; exit 2; }

duration=4; width=34; level=info; style=
while getopts d:w:s:l: option; do
  case $option in
    d) duration=$OPTARG ;; w) width=$OPTARG ;; s) style=$OPTARG ;; l) level=$OPTARG ;;
    ?) exit 2 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || exit 0

case $duration in
  ''|*[!0-9.]*|*.*.*|.) die "invalid duration '$duration' (use non-negative seconds)" ;;
esac

# 8 is a judgement call: one column goes to padding, and narrower than this
# even a short word is chopped, so the message becomes a column of fragments.
# A leading zero is rejected because $(( )) would read it as octal: 010 would
# fold the text at 7 columns inside a 10 column box, and 08 is an error.
case $width in
  ''|*[!0-9]*|[0-7]|0?*) die "invalid width '$width' (use 8 columns or more)" ;;
esac

# Reserve two border columns and the two-column right margin.
max_width=$(tmux display-message -p '#{e|-:#{window_width},4}') || exit 1
case $max_width in ''|*[!0-9-]*) die "cannot read the window width" ;; esac
[ "$max_width" -ge 8 ] || die "window is too narrow (need at least 12 columns)"
# Compare digit counts first so oversized input cannot overflow shell integers.
if [ "${#width}" -gt "${#max_width}" ] || [ "$width" -gt "$max_width" ]; then
  die "invalid width '$width' (use at most $max_width columns in this window)"
fi

# Backgrounds share the error tone's luminance so only hue signals severity:
# a brighter green would make success shout louder than failure.
case $level in
  info)  background='#11151c' ;;
  ok)    background='#0e2518' ;;
  warn)  background='#291f0f' ;;
  error) background='#3a1518' ;;
  *) die "unknown level '$level' (use error, warn, ok or info)" ;;
esac
[ -n "$style" ] || style="bg=$background,fg=colour223"

# Fold so the pane height matches the rendered line count; otherwise tmux
# wraps the text itself and the top scrolls out of view.
# Wrap within width - 1 to reserve left padding on every line.
# Cap the height to leave room for borders and the bottom margin: past the
# window height new-pane fails outright and no toast is shown at all.
max_height=$(tmux display-message -p '#{e|-:#{window_height},3}') || exit 1
case $max_height in ''|*[!0-9-]*) die "cannot read the window height" ;; esac
[ "$max_height" -ge 1 ] || die "window is too short (need at least 4 lines)"
text_width=$((width - 1))

# Use UTF-8 while preparing the text so fold measures display columns. C.UTF-8
# adds nothing but the encoding, so take it when it is there and settle for any
# other UTF-8 locale; with none installed the empty value leaves LC_ALL unset
# rather than naming a locale that does not exist and measuring bytes anyway.
locales=$(locale -a 2>/dev/null)
utf8_locale=$(printf '%s\n' "$locales" | grep -Eix -m1 'C\.utf-?8' ||
              printf '%s\n' "$locales" | grep -Ei -m1 '\.utf-?8$')

# Drop the control characters a message may carry: a carriage return would eat
# the padding and an escape would repaint the pane, and both spend columns that
# fold has already counted. Tab and newline are left to expand and fold. Done
# bytewise, so no multibyte character is cut apart; what survives an escape is
# printable text and nothing more.
# Omit the final newline so the pane does not scroll. The row count trails the
# text rather than leading it: a toast may well end in blank lines, and command
# substitution would strip those unless something comes after them.
rendered=$(export LC_ALL="$utf8_locale"
  printf '%s\n' "$@" | LC_ALL=C tr -d '\001-\010\013-\037\177' |
  expand | fold -s -w "$text_width" |
  awk -v max_height="$max_height" '
    NR <= max_height { line[NR] = $0 }
    END {
      total = (NR > max_height ? max_height : NR)
      for (i = 1; i <= total; i++)
        printf("%s %s", (i == 1 ? "" : "\n"),
               (NR > max_height && i == total) ? "…" : line[i])
      printf("\n%d", total)
    }')
newline='
'
height=${rendered##*"$newline"}
text=${rendered%"$newline"*}

# The kill scheduled below runs in a shell, which needs tmux by path.
tmux_bin=$(command -v tmux) || die "cannot find tmux"

# Whatever toast is up now, named here and dismissed at the end: nothing below
# is certain to work, and a toast on screen is worth more than the one that
# failed to replace it. #{@toast} would answer for a pane that never carried
# the mark, because a user option falls back to the window, session and global
# scopes; show -p reads the pane and nothing else. Only floating panes are
# asked, so the sweep costs one call in the usual case.
stale=$(tmux list-panes -F '#{pane_id} #{pane_floating_flag}' |
  awk '$2 == "1" { print $1 }' |
  while read -r pane; do
    [ "$(tmux show -pv -t "$pane" @toast 2>/dev/null)" = 1 ] && printf '%s\n' "$pane"
  done)

# -x/-y size the content, so the border adds one cell on each side. The offsets
# leave a 2 column / 1 line margin, which reads as even given cell proportions.
# -I fills the pane from stdin and runs no command in it, so the toast carries
# no process and no file of its own: nothing is left to clean up after it.
pane_id=$(printf '%s' "$text" | tmux new-pane -d -I -P -F '#{pane_id}' \
  -x "$width" -y "$height" \
  -X "#{e|-:#{window_width},$((width + 3))}" \
  -Y "#{e|-:#{window_height},$((height + 2))}" \
  -s "$style" -R "$style") || exit 1
tmux set -p -t "$pane_id" @toast 1

# Removed from outside on purpose: a pane whose own command exits fires the
# pane-exited hook, so a toast wired to that hook would retrigger itself.
# A toast replaced before its timer fires leaves this kill with no pane to find,
# and tmux reports that: with -C the error goes to the status line of every
# attached client, and from a shell the exit status drops the current pane into
# view mode. Only stderr is ignored, so the kill has to end in success instead.
# The socket is spelled out because the shell inherits the server's environment
# rather than ours.
tmux run-shell -b -d "$duration" \
  "'$tmux_bin' -S '#{socket_path}' kill-pane -t $pane_id || true" || {
  tmux kill-pane -t "$pane_id" 2>/dev/null
  exit 1
}

# The new toast is up and booked to go, so the old one can be dropped.
for pane in $stale; do tmux kill-pane -t "$pane" 2>/dev/null; done
# An old toast may have expired meanwhile; that does not undo this success.
exit 0
