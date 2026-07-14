# hyperos-accessibility-fix
Stop HyperOS from randomly disabling accessibility services

## What's happening
On Android, when an accessibility app is force-stopped via `ActivityManager`, the [accessibility permission of the app is stripped](https://cs.android.com/android/platform/superproject/+/android-16.0.0_r4:frameworks/base/services/accessibility/java/com/android/server/accessibility/AccessibilityManagerService.java;drc=7f9ce6b127e5d17d7a2ccef1ccc21db212f60084;l=1050).

```java
boolean onPackagesForceStoppedLocked(String[] packages, AccessibilityUserState userState) {
    final Set<String> packageSet = Set.of(packages);
    
    final ArrayList<ComponentName> continuousServices = userState.mInstalledServices.stream()
            .filter(s -> (s.flags & FLAG_REQUEST_ACCESSIBILITY_BUTTON) == FLAG_REQUEST_ACCESSIBILITY_BUTTON)
            .map(AccessibilityServiceInfo::getComponentName)
            .filter(name -> packageSet.contains(name.getPackageName()))
            .collect(Collectors.toCollection(ArrayList::new));

    final boolean enabledServicesChanged = userState.mEnabledServices.removeIf(comp -> {
        if (packageSet.contains(comp.getPackageName())) {
            userState.getBindingServicesLocked().remove(comp);
            userState.getCrashedServicesLocked().remove(comp);
            return true;
        }
        return false;
    });

    if (enabledServicesChanged) {
        persistComponentNamesToSettingLocked(
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            userState.mEnabledServices, userState.mUserId);
    }
}
    ...
```

And HyperOS is hardcoded to trigger a force-stop (not a kill) on 
certain events like when the user is entering Ultra Battery Saver (`LockScreenClean`),
and others:

```log
<ultra battery saver was enabled>
I ActivityManager: Force stopping com.urbandroid.lux appid=10415 user=0: LockScreenClean
D ActivityManager: Force removing proc 8855:com.urbandroid.lux:background/u0a415 (com.urbandroid.lux:background/10415)
```

## How it works
This module installs a background script that monitors the `logcat` stream for accessibility update events 
with minimal system overhead.

On boot, it checks what accessibility services are enabled, and writes them to `a11y_watchlist.txt`. It also listens for signs of manual 
configuration changes (done by user in settings) and updates the watchlist automatically.
 
When an accessibility update event is detected, the script first checks if the device is in the Settings app (as mentioned above).
If not, the script performs a verification of enabled accessibility services against the local `a11y_watchlist.txt`.
And if the list doesn't match up, the changes are reverted instantly.

This script also runs at `OOM` score `-800` to prevent `LMKD` from killing it in the background. And if it still gets killed under memory pressure,
another (monitor) script (that runs at `-900`) is running in background to restart it (provided it wasn't killed aswell lol)

## Why use background scripts, and not zygisk/xposed?
On my device, these two frameworks cause a range of problems for some reason, so i decided to follow this approach instead.

It's also more minimal this way, having almost no requirements.

## Do they really have minimal system overhead?
After 2 days of uptime, the scripts used only ~160 seconds of CPU time (`USER_HZ=100`) in total since they started.

These background scripts have negligible effect on performance and they won't slow the system down.

```bash
$ getconf CLK_TCK
100
```
```bash
$ cat /proc/7562/stat 
7562 (sh) S 1 7562 7562 0 -1 4194560 1303 11306 82 0 3 181 7 25 20 0 1 0 4514 11082203136 720 18446744073709551615 391135674368 391135918392 549159233360 0 0 0 0 6 1208083705 1 0 0 17 0 0 0 0 0 0 391135936512 391135937152 391696969728 549159237033 549159237184 549159237184 549159243753 0

$ cat /proc/7563/stat                                                                                                                                                                                   
7563 (sh) S 1 7563 7563 0 -1 4194304 73566 952234 7750 8335 63 893 1169 3535 20 0 1 0 4515 11065425920 825 18446744073709551615 401645289472 401645533496 549315373280 0 0 0 0 6 1208083705 1 0 0 17 3 0 0 0 0 0 401645551616 401645552256 402234515456 549315376568 549315376704 549315376704 549315383273 0
```
```bash
$ uptime
02:20:46 up 2 days,  6:37,  0 users,  load average: 24.01, 11.73, 8.87
```

## Note
- When Ultra Battery Saver is turned on, the accessibility services will still keep running in the background
- Force stopping an app via App Manager will not (permanently) remove it's accessibility permission anymore.
So be careful at what you enable

## Installation:
* [Download the module archive here](https://github.com/chkndrp/hyperos-accessibility-fix/releases/latest/download/hyperos-accessibility-fix.zip)
* Flash it in magisk app, or using command line

## Requirements
- HyperOS 1.0+ (or any A14+ system)
- KernelSU 1.0.2+
- Magisk 28.0+
