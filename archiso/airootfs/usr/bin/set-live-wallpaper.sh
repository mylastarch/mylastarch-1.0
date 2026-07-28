#!/bin/sh
sleep 4
WALL=/usr/share/wallpapers/MyWallpaper/mywallpaper.png
KWRITE=/usr/bin/kwriteconfig6
if [ ! -x "$KWRITE" ]; then
echo "$(date): $KWRITE not found or not executable" >> /tmp/set-live-wallpaper.log
exit 1
fi
mkdir -p "$HOME/.config"
"$KWRITE" --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
--group "Containments" --group "1" --group "Applets" --group "1" \
--group "Configuration" --group "Wallpaper" --key "plugin" "org.kde.image"
"$KWRITE" --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
--group "Containments" --group "1" --group "Applets" --group "1" \
--group "Configuration" --group "Wallpaper" --key "image" "$WALL"
if command -v qdbus >/dev/null 2>&1; then
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.reloadConfig || true
fi

