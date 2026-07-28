#!/bin/bash

# Add near the top of set-slideshow.sh
#exec > "${HOME}/set-slideshow.log" 2>&1
#echo "Script started at $(date)"
#echo "DBUS: $DBUS_SESSION_BUS_ADDRESS"
#echo "HOME: $HOME"



# Abort if not running in a KDE Plasma session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
  exit 1
fi

WALLPAPER_DIR="${HOME}/.config/variety/Downloaded"
INTERVAL=300  # 5 minutes in seconds

# Wait until plasmashell is fully operational (up to 60s)
for i in {1..60}; do
  RESULT=$(qdbus org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript "var d = desktops(); print(d.length);" 2>/dev/null)
  if [[ "$RESULT" =~ ^[1-9] ]]; then
    break
  fi
  sleep 1
done

if [[ ! "$RESULT" =~ ^[1-9] ]]; then
  # plasmashell never became ready, exit without self-deleting so it retries next login
  exit 1
fi

qdbus org.kde.plasmashell /PlasmaShell \
  org.kde.PlasmaShell.evaluateScript "
    var allDesktops = desktops();
    for (var i = 0; i < allDesktops.length; i++) {
      var d = allDesktops[i];
      d.wallpaperPlugin = 'org.kde.slideshow';
      d.currentConfigGroup = ['Wallpaper', 'org.kde.slideshow', 'General'];
      d.writeConfig('SlidePaths', '${WALLPAPER_DIR}');
      d.writeConfig('SlideInterval', ${INTERVAL});
    }
  "

# Only self-delete if we got this far (success)
#rm -- "${HOME}/.local/bin/set-slideshow.sh"
#rm -- "${HOME}/.config/autostart/set-wallpaper.desktop"
