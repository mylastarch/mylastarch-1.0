#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="${HOME}/.conf/variety/Downloaded"

if [ ! -d "$WALLPAPER_DIR" ]; then
  echo "Directory not found: $WALLPAPER_DIR" >&2
  exit 1
fi

# Build JS snippet to set slideshow plugin and folder for each desktop
read -r -d '' PLASMA_JS <<'EOF'
var allDesktops = desktops();
for (var i = 0; i < allDesktops.length; i++) {
  var d = allDesktops[i];
  d.wallpaperPlugin = "org.kde.slideshow";
  d.currentConfigGroup = ["Wallpaper","org.kde.slideshow","General"];
  d.writeConfig("ImagePaths", "%WALLPAPER_DIR%");
  d.writeConfig("interval", "300"); // seconds between slides
  d.writeConfig("recursive", "true");
}
EOF

# Escape backslashes and quotes for JS insertion
ESCAPED_DIR=${WALLPAPER_DIR//\\/\\\\}
ESCAPED_DIR=${ESCAPED_DIR//\"/\\\"}
PLASMA_JS="${PLASMA_JS//%WALLPAPER_DIR%/$ESCAPED_DIR}"

# Apply via plasmashell JS
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$PLASMA_JS"

# Restart plasmashell to ensure settings applied
kquitapp5 plasmashell || true
kstart5 plasmashell & disown || true

echo "Plasma wallpaper set to slideshow from: $WALLPAPER_DIR"
