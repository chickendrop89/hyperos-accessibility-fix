#!/system/bin/sh
# shellcheck shell=ash

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

MISSING=""

for cmd in grep dumpsys logcat read printf echo sleep sed setsid wc kill cut mv settings; 
    do command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done

if [ -n "$MISSING" ]; 
    then
        echo "- required command(s) missing: $MISSING. please install busybox/toybox." >&2
        exit 1
fi
