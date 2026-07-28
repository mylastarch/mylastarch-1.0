#!/bin/bash
WALL="file:///usr/share/wallpapers/MyLastArch/contents/images/mylastarch.png"
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
var all = desktops();
for (i=0;i<all.length;i++) {
 d = all[i];
 d.wallpaperPlugin = 'org.kde.image';
 d.currentConfigGroup = Array('Wallpaper','org.kde.image','General');
 d.writeConfig('Image','$WALL');
}"
