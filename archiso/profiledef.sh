#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="mylastarch"
iso_label="MLA_20260901"
iso_publisher="MY LAST ARCH Linux <https://www.dccwebsite.com/mylastarch.html>"
iso_application="MY LAST ARCH Linux Live/Rescue DVD"
iso_version="2026.09.01"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/root/.gnupg"]="0:0:400"
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/etc/sudoers.d"]="0:0:750"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/mylastarch-before"]="0:0:755"
  ["/usr/local/bin/mylastarch-final"]="0:0:755"
  ["/usr/local/sbin/mylastarch-grub-kernel-titles"]="0:0:755"
  ["/usr/local/sbin/mylastarch-arch-update-safety"]="0:0:755"
  ["/usr/local/libexec/plm-wallpaper-sync"]="0:0:755"
  ["/usr/local/bin/get-nemesis-on-mylastarch"]="0:0:755"
  ["/usr/local/bin/set-wallpaper.sh"]="0:0:755"
  ["/usr/local/bin/set-timezone.sh"]="0:0:755"
  ["/etc/NetworkManager/dispatcher.d/90-set-timezone"]="0:0:755"
  ["/usr/local/bin/mylastarch-dolphin-action"]="0:0:755"
  ["/usr/share/kio/servicemenus/mylastarch-actions.desktop"]="0:0:755"
  ["/usr/share/kio/servicemenus/mylastarch-convert-image.desktop"]="0:0:755"
  ["/usr/share/kio/servicemenus/mylastarch-hidden-files.desktop"]="0:0:755"
  ["/etc/skel/calamares.desktop"]="0:0:755"
  ["/etc/skel/Desktop/calamares.desktop"]="0:0:755"
  ["/var/lib/iwd"]="0:0:700"
  ["/opt/vivaldi/initial_preferences"]="0:0:644"
)
