#!/bin/sh
# tmux-toast.sh - show a transient notification in a tmux floating pane.
# Usage: tmux-toast.sh [-l error|warn|ok|info] [-d seconds] [-w width]
#                     [-s style] line [line...]
# An explicit -s overrides -l regardless of option order.
#
# Needs tmux 3.7+ (the new-pane command). The pane is created detached so it
# never steals focus. It is anchored to the bottom right corner, and one raised
# while another is up stacks above it; floating panes do not re-anchor on
# resize, but a toast is short lived enough not to care.

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

# 8 is a judgement call: two columns go to padding, and narrower than this
# even a short word is chopped, so the message becomes a column of fragments.
# A leading zero is rejected because $(( )) would read it as octal: 010 would
# fold the text at 6 columns inside a 10 column box, and 08 is an error.
case $width in
  ''|*[!0-9]*|[0-7]|0?*) die "invalid width '$width' (use 8 columns or more)" ;;
esac

# Keep every operation on the same window even if the user switches away.
window_id=$(tmux display-message -p '#{window_id}') || exit 1

# Reserve two border columns and a two-column margin on each side. Only the
# right margin is laid out, by the offset below; the left one is this cap
# alone, and without it the widest toast rests against the left edge while
# still standing clear of the right. The window is measured here rather than
# inside the format that places the pane: the vertical offset is arithmetic
# over the stack now, and the two offsets are read side by side.
window_width=$(tmux display-message -p -t "$window_id" '#{window_width}') || exit 1
case $window_width in ''|*[!0-9]*) die "cannot read the window width" ;; esac
max_width=$((window_width - 6))
[ "$max_width" -ge 8 ] || die "window is too narrow (need at least 14 columns)"
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
# Wrap within width - 2 so a column of padding stands on either side: the
# left one is written out, the right one is the column the text stops before.
# Cap the height to leave room for borders and a row of margin above and
# below, the same way the width leaves a margin on either side: past the
# window height new-pane fails outright and no toast is shown at all.
window_height=$(tmux display-message -p -t "$window_id" '#{window_height}') || exit 1
case $window_height in ''|*[!0-9]*) die "cannot read the window height" ;; esac
max_height=$((window_height - 4))
[ "$max_height" -ge 1 ] || die "window is too short (need at least 5 lines)"
text_width=$((width - 2))

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

# Serialize the stack update per window, through marking and cleanup. The
# timer is asynchronous, so the lock is released while the toast is still up.
# The channel has no owner, so a script killed between the -L and the -U
# leaves it locked for good and every later toast waits there. The window is
# some tens of milliseconds, too narrow to be worth the machinery of a
# recovery; tmux wait-for -U toast-<window id> is what clears it by hand.
lock="toast-$window_id"
tmux wait-for -L "$lock" || exit 1
trap 'tmux wait-for -U "$lock" 2>/dev/null' 0
trap 'exit 1' HUP INT TERM

# Every toast up now, each with the row its text starts on. #{@toast} would
# answer for a pane that never carried the mark, because a user option falls
# back to the window, session and global scopes; show -p reads the pane and
# nothing else. Only floating panes are asked, so the sweep costs one call in
# the usual case.
live=$(tmux list-panes -t "$window_id" -F '#{pane_id} #{pane_floating_flag} #{pane_top}' |
  awk '$2 == "1" { print $1, $3 }' |
  while read -r pane top; do
    [ "$(tmux show -pv -t "$pane" @toast 2>/dev/null)" = 1 ] &&
      printf '%s %s\n' "$pane" "$top"
  done)

# The new toast goes above the highest one up, and the floor stands in for a
# toast just off the bottom edge so the first one lands by the same rule. The
# row of margin that rule leaves is also what separates two toasts: their
# borders alone, laid one against the other, read as a single thick rule
# rather than as two cards.
anchor=$(printf '%s\n' "$live" |
  awk -v floor="$((window_height + 1))" '
    NF == 2 && (top == "" || $2 < top) { top = $2 }
    END { print (top == "" ? floor : top) }')

# Above the stack there is no room left for this one; of the rows over the
# toast above, four go to this one's two borders and to the row of margin
# under and over it. A message folded down to a row or two is worth less
# than the ones already read: drop the stack and start again from the bottom,
# where the height the text was folded to is certain to fit. What is dropped
# is named here and killed at the end: nothing below is certain to work, and
# a toast on screen is worth more than the one that failed to replace it.
replaced=
if [ "$height" -gt "$((anchor - 5))" ]; then
  replaced=$(printf '%s\n' "$live" | awk 'NF == 2 { print $1 }')
  anchor=$((window_height + 1))
fi

# -x/-y size the content, so the border adds one cell on each side. The offsets
# leave a 2 column / 1 line margin, which reads as even given cell proportions.
# -I fills the pane from stdin and runs no command in it, so the toast carries
# no process and no file of its own: nothing is left to clean up after it.
pane_id=$(printf '%s' "$text" | tmux new-pane -t "$window_id" -d -I -P -F '#{pane_id}' \
  -x "$width" -y "$height" \
  -X "$((window_width - width - 3))" \
  -Y "$((anchor - height - 3))" \
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
tmux run-shell -t "$window_id" -b -d "$duration" \
  "'$tmux_bin' -S '#{socket_path}' kill-pane -t $pane_id || true" || {
  tmux kill-pane -t "$pane_id" 2>/dev/null
  exit 1
}

# The new toast is up and booked to go, so the stack it displaced can be
# dropped.
for pane in $replaced; do tmux kill-pane -t "$pane" 2>/dev/null; done
# A dropped toast may have expired meanwhile; that does not undo this success.
exit 0
