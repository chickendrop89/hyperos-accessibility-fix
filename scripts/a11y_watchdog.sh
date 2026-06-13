#!/system/bin/sh

#  Stop HyperOS from randomly disabling accessibillity services
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

WATCHLIST="$1/a11y_watchlist.txt"
PIDFILE="/tmp/a11y_watchdog.pid"
LOGFILE="$2"

PKG_PATTERN=""
LAST_FORCE_STOP=0
LAST_REPAIR=0

# Write PID to file for monitoring
printf "%d\n" $$ > "$PIDFILE.tmp" && mv -f "$PIDFILE.tmp" "$PIDFILE" || exit 1

# Increase OOM score to prevent getting killed by LMKD
if [[ -f /proc/self/oom_score_adj ]]; 
    then printf "-800" > /proc/self/oom_score_adj
fi

log() {
    if (( $(wc -l < "$LOGFILE") > 100 )); 
        then sed -i '1,50d' "$LOGFILE"
    fi

    printf "$(date '+%m-%d %H:%M') [watchdog] %s\n" "$1" >> "$LOGFILE"
}

get_services() {
    unset out_str
    get_svc_out=$(settings get secure enabled_accessibility_services 2>/dev/null)

    if [[ -z "$get_svc_out" || "$get_svc_out" == "null" ]];
        then return
    fi

    for svc_str in ${get_svc_out//:/ };
        do
            if [[ -z "$svc_str" ]];
                then continue
            fi

            if [[ "$svc_str" == */.* ]]; 
                then
                    package="${svc_str%%/*}"
                    svc_str="$package/$package${svc_str#*/}"
            fi

            out_str="${out_str}${svc_str}:"
    done

    printf '%s\n' "${out_str%?}"
}

repair_database() {
    if (( SECONDS - LAST_REPAIR < 2 ));
        then return
    fi

    rep_cur=$(get_services)
    rep_seen=""

    rep_new=$( { cat "$WATCHLIST" 2>/dev/null; printf '%s\n' "$rep_cur" | tr ':' '\n'; } | while read -r svc_item;
        do
            if [[ -z "$svc_item" || "$rep_seen" == *":$svc_item:"* ]]; 
                then continue
            fi

            printf "%s:" "$svc_item"
            rep_seen="$rep_seen:$svc_item:"
    done | sed 's/:$//' )

    if [[ "$rep_new" != "$rep_cur" && -n "$rep_new" ]]; 
        then
            log "Wipe detected! Restored '$rep_new'"

            settings put secure enabled_accessibility_services "$rep_new"
            settings put secure accessibility_enabled 1
            
            LAST_REPAIR=$SECONDS
    fi
}

sync_live_to_watchlist() {
    sync_cur=$(get_services)

    if [[ -z "$sync_cur" ]];
        then return
    fi

    sync_active=$(printf '%s\n' "$sync_cur" | tr ':' '\n' | grep '/')

    if [[ -z "$sync_active" ]];
        then return
    fi

    if [[ "$(sort <<< "$sync_active")" != "$(sort "$WATCHLIST" 2>/dev/null)" ]]; 
        then
            printf '%s\n' "$sync_active" > "$WATCHLIST"
            log "Watchlist synced with manual user changes: '$sync_cur'"
    fi
}

sync_live_to_watchlist
log "Initialized watchdog daemon"

while read -r watch_svc || [[ -n "$watch_svc" ]]; 
    do
        if [[ -n "$watch_svc" ]]; 
            then
                pkg="${watch_svc%%/*}"

                if [[ "$PKG_PATTERN" != *"$pkg"* ]]; 
                    then PKG_PATTERN="${PKG_PATTERN:+$PKG_PATTERN|}$pkg"
                fi
        fi
done < "$WATCHLIST"

if [[ -z "$PKG_PATTERN" ]];
    then PKG_PATTERN="a^"
fi

logcat -b events -b main -b system -T 1 | \
grep --line-buffered -E "ActivityManager: Force stopping.*($PKG_PATTERN)|accessibility event occurred|Accessibility volume enabled|AccessibilityContentObserver.onChange|ActivityManager: Background started FGS" | \
while read -r log_line; 
    do
        case "$log_line" in
            *"ActivityManager: Force stopping"*)
                if (( SECONDS - LAST_FORCE_STOP > 2 )); 
                    then
                        LAST_FORCE_STOP=$SECONDS
                        sleep 0.5
                        repair_database
                fi
            ;;
            *)
                if (( SECONDS - LAST_REPAIR <= 2 )); 
                    then continue
                fi

                current_activity=$(dumpsys activity activities | grep -E "mCurrentFocus|mFocusedApp")

                if [[ "$current_activity" == *"com.android.settings"* ]];
                    then sync_live_to_watchlist
                    else repair_database
                fi
            ;;
        esac
done
