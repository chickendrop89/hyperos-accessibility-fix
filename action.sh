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

LOGFILE="/tmp/a11y_watchdog.log"
MODPROP="$MODPATH/module.prop"

MODULENAME=$(grep '^id=' "$MODPROP" | cut -d'=' -f2)
VERSION=$(grep '^version=' "$MODPROP" | cut -d'=' -f2)

log() {
    printf "$(date '+%m-%d %H:%M') [action] %s\n" "$1"
}

log "$MODULENAME $VERSION"

if [[ -f "$LOGFILE" ]]; 
    then
        cat "$LOGFILE"
        exit 0
    else
        log "Watchdog log is missing. The module service did not run!"
        exit 1
fi
