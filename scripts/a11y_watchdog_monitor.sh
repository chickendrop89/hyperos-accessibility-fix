#!/system/bin/sh

#  Stop HyperOS from randomly disabling accessibility services
#  Copyright (C) 2026 chkndrp
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

MODPATH="$1"
SCRIPTDIR="$MODPATH/scripts"

PIDFILE="/tmp/a11y_watchdog.pid"
LOGFILE="/tmp/a11y_watchdog.log"

# Increase OOM score to prevent getting killed by LMKD
if [[ -f /proc/self/oom_score_adj ]]; 
    then printf "-900" > /proc/self/oom_score_adj
fi

log() {
    if (( $(wc -l < "$LOGFILE") > 100 )); 
        then sed -i '1,50d' "$LOGFILE"
    fi

    printf "$(date '+%m-%d %H:%M') [monitor] %s\n" "$1" >> "$LOGFILE"
}

restart_watchdog() {
    lock_file="/tmp/a11y_watchdog.restart.lock"
    lock_timeout=50

    attempts=0
    waited=0
    file_pid=0

    while ! (set -o noclobber; printf "%s\n" "$$" > "$lock_file") 2>/dev/null && (( waited < lock_timeout )); 
        do
            sleep 0.1
            (( waited++ ))
    done

    if kill -0 "$PID" 2>/dev/null; 
        then
            rm -f "$lock_file"
            log "Watchdog process ($PID) recovered during lock wait"
            return 0
    fi
    
    log "Restarting watchdog process..."
    setsid /system/bin/sh "$SCRIPTDIR/a11y_watchdog.sh" "$MODPATH" "$LOGFILE" > /dev/null 2>&1 < /dev/null &

    while (( attempts < 30 )); 
        do
            if read -r file_pid < "$PIDFILE" && kill -0 "$file_pid" 2>/dev/null; 
                then
                    rm -f "$lock_file"
                    log "Watchdog restarted successfully (PID: $file_pid)"
                    return 0
            fi

            sleep 0.1
            (( attempts++ ))
    done
    
    rm -f "$lock_file"
    log "Failed to verify watchdog restart"
    return 1
}

while true; 
    do
        sleep 60

        if ! read -r PID < "$PIDFILE" 2>/dev/null || [[ -z $PID ]] || ! kill -0 "$PID" 2>/dev/null; 
            then
                log "Watchdog process dead or PID missing, restarting watchdog"
                restart_watchdog
        fi
done
