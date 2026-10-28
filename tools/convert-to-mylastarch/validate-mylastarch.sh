#!/usr/bin/env bash
set -u

TARGET_USER=${SUDO_USER:-}
if [[ ${1:-} == --user && -n ${2:-} ]]; then TARGET_USER=$2; shift 2; fi
[[ $# -eq 0 ]] || { echo "Usage: $0 [--user NAME]" >&2; exit 2; }
[[ -n $TARGET_USER ]] || { echo "Pass --user NAME" >&2; exit 2; }
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
failures=0

check() {
    local description=$1; shift
    if "$@" >/dev/null 2>&1; then printf '[OK]   %s\n' "$description";
    else printf '[FAIL] %s\n' "$description"; ((failures++)); fi
}

check "KDE Plasma is installed" pacman -Q plasma-workspace
check "Cairo-Dock is installed" command -v cairo-dock
check "Cairo-Dock autostarts" test -f "$TARGET_HOME/.config/autostart/cairo-dock.desktop"
check "MyLastArch Cairo-Dock theme exists" test -f "$TARGET_HOME/.config/cairo-dock/current_theme/cairo-dock.conf"
check "MyLastArch Plasma layout exists" test -f "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
check "MyLastArch top panel is configured" grep -q '^location=3$' "$TARGET_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
check "MyLastArch splash is configured" grep -q '^Theme=archsimpleblue$' "$TARGET_HOME/.config/ksplashrc"
check "MyLastArch splash theme exists" test -f "$TARGET_HOME/.local/share/plasma/look-and-feel/archsimpleblue/metadata.json"
check "XScreenSaver settings are visible in Plasma" test -f "$TARGET_HOME/.local/share/applications/mylastarch-xscreensaver-settings.desktop"
check "XScreenSaver image directory is populated" test -f /usr/share/backgrounds/mylastarch/xscreensaver-images/clouds.jpg
check "Dolphin uses the full-width status bar" grep -q '^ShowStatusBar=FullWidth$' "$TARGET_HOME/.config/dolphinrc"
check "Cairo-Dock is running" pgrep -u "$(id -u "$TARGET_USER")" -x cairo-dock
if command -v arch-update >/dev/null 2>&1; then
    check "Arch Update tray autostart exists" test -f "$TARGET_HOME/.config/autostart/arch-update-tray.desktop"
elif grep -q '^Hidden=true$' "$TARGET_HOME/.config/autostart/arch-update-tray.desktop" 2>/dev/null; then
    printf '[OK]   Missing Arch Update does not leave a broken autostart entry\n'
else
    printf '[FAIL] Missing Arch Update has an enabled autostart entry\n'
    ((failures++))
fi
if pacman -Q plank >/dev/null 2>&1 || pacman -Q plank-reloaded-git >/dev/null 2>&1; then
    if pgrep -u "$(id -u "$TARGET_USER")" -x plank >/dev/null 2>&1; then
        printf '[FAIL] Competing Plank dock is still running\n'
        ((failures++))
    else
        printf '[OK]   Competing Plank dock is not running\n'
    fi
fi
check "Vivaldi uses automatic X11/Wayland selection" grep -q '^--ozone-platform-hint=auto$' "$TARGET_HOME/.config/vivaldi-stable.conf"
check "MyLastArch wallpaper exists" test -f /usr/share/wallpapers/MyLastArch/contents/images/mylastarch.png
check "Dolphin actions are installed" test -x /usr/local/bin/mylastarch-dolphin-action
check "Bluetooth is enabled" systemctl is-enabled bluetooth.service
check "Printing is enabled" systemctl is-enabled cups.service
if pacman -Q nss-mdns >/dev/null 2>&1; then
    check ".local hostname resolution is enabled" grep -Eq '^hosts:.*mdns' /etc/nsswitch.conf
fi

display_manager=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)
if [[ ${display_manager##*/} == plasmalogin.service ]]; then
    check "Plasma Login Manager background is configured" grep -q '/var/lib/plasmalogin/wallpapers/01.jpg' /etc/plasmalogin.conf.d/10-mylastarch-wallpaper.conf
    check "Plasma Login Manager background exists" test -f /var/lib/plasmalogin/wallpapers/01.jpg
    check "Plasma Login Manager wallpaper sync is installed" test -x /usr/local/libexec/plm-wallpaper-sync
fi

if (( failures )); then
    printf '\n%d validation check(s) failed.\n' "$failures" >&2
    exit 1
fi
printf '\nMyLastArch conversion validation passed.\n'
