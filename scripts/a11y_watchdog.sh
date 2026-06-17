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

WATCHLIST="$1/a11y_watchlist.txt"
PIDFILE="/tmp/a11y_watchdog.pid"
LOGFILE="$2"

# This service is managed automatically by HyperOS on some devices
EXCLUDE_SVC="com.miui.screenshot/com.miui.screenshot.accessibility.ScreenshotAccessibilityService"

# Write PID to file for monitoring
printf "%d\n" $$ > "$PIDFILE.tmp" && mv -f "$PIDFILE.tmp" "$PIDFILE" || exit 1

# Increase OOM score to prevent getting killed by LMKD
if [[ -f /proc/self/oom_score_adj ]]; 
    then printf "-800" > /proc/self/oom_score_adj
fi

log() {
    if (( $(wc -l < "$LOGFILE") > 100 )); 
        then
            tail -n 50 "$LOGFILE" > "$LOGFILE.tmp" 
            mv -f "$LOGFILE.tmp" "$LOGFILE"
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
            if [[ -z "$svc_str" || "$svc_str" == "$EXCLUDE_SVC" ]];
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
    sleep 0.2

    rep_cur=$(get_services)
    rep_seen=""
    rep_new=""

    if [[ -f "$WATCHLIST" ]]; 
        then
            while read -r svc_item; 
                do
                    if [[ -z "$svc_item" || "$rep_seen" == *":$svc_item:"* || "$svc_item" == "$EXCLUDE_SVC" ]];
                        then continue
                    fi

                    rep_new="${rep_new}${svc_item}:"
                    rep_seen="$rep_seen:$svc_item:"
            done < "$WATCHLIST"
    fi

    for svc_item in ${rep_cur//:/ }; 
        do
            if [[ -z "$svc_item" || "$rep_seen" == *":$svc_item:"* || "$svc_item" == "$EXCLUDE_SVC" ]];
                then continue
            fi

            rep_new="${rep_new}${svc_item}:"
            rep_seen="$rep_seen:$svc_item:"
    done

    rep_new="${rep_new%?}"

    if [[ "$rep_new" != "$rep_cur" && -n "$rep_new" ]];
        then
            log "Wipe detected! Restored '$rep_new'"

            settings put secure enabled_accessibility_services "$rep_new"
            settings put secure accessibility_enabled 1
    fi
}

sync_live_to_watchlist() {
    sync_cur=$(get_services)
    sync_active=""

    if [[ -z "$sync_cur" ]];
        then return
    fi

    for item in ${sync_cur//:/ }; 
        do
            if [[ "$item" == *"/"* ]]; 
                then sync_active="${sync_active}${item}\n"
            fi
    done

    if [[ -z "$sync_active" ]];
        then return
    fi

    if [[ "$(cat "$WATCHLIST" 2>/dev/null)" != "$(printf "%b" "$sync_active" | sort)" ]];
        then
            printf '%b' "$sync_active" | sort > "$WATCHLIST"
            log "Watchlist synced with manual user changes: '$sync_cur'"
    fi
}

sync_live_to_watchlist
log "Initialized watchdog daemon"

logcat -b events -b main -b system -T 1 | \
grep --line-buffered -E "accessibility event occurred|Accessibility volume enabled|AccessibilityContentObserver.onChange|ActivityManager: Background started FGS" | \
while read -r _; 
    do
        if dumpsys activity activities | grep -E "mCurrentFocus|mFocusedApp" | grep -q "SubSettings"; 
            then sync_live_to_watchlist
            else repair_database
        fi
done
