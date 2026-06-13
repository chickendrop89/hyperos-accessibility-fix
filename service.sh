#!/system/bin/sh

#  Stop HyperOS from randomly disabling accessibility services
#  Copyright (C) 2026 chickendrop89
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, see <https://www.gnu.org/licenses/>.

SCRIPTDIR="$MODPATH/scripts"
WATCHLIST="$MODPATH/a11y_watchlist.txt"
LOGFILE="/tmp/a11y_watchdog.log"
MISSING=""

log() {
    printf "$(date '+%m-%d %H:%M') [service] %s\n" "$1" >> "$LOGFILE"
}

# Wait until /data is decrypted
while [[ "$(getprop sys.boot_completed)" != "1" ]]; 
    do sleep 5
done

for cmd in grep dumpsys logcat read printf echo sleep sed setsid wc kill cut mv settings; 
    do command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done

if [[ ! -f $LOGFILE ]]; 
    then : >> "$LOGFILE"
fi
if [[ -n "$MISSING" ]];
    then
        log "- required command(s) missing: $MISSING. please install busybox/toybox."
        exit 1
fi
if [[ ! -f $WATCHLIST ]]; 
    then : >> "$WATCHLIST"
fi

setsid /system/bin/sh "$SCRIPTDIR/a11y_watchdog.sh" "$MODPATH" "$LOGFILE" > /dev/null 2>&1 < /dev/null &
setsid /system/bin/sh "$SCRIPTDIR/a11y_watchdog_monitor.sh" "$MODPATH" > /dev/null 2>&1 < /dev/null &
