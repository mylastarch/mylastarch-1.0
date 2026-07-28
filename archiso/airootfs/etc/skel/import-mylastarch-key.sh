#!/usr/bin/env bash
# shellcheck disable=SC2034

echo "Run the alias 'fix-pacman-keyserver'"
echo "In a terminal first to have the correct"
echo "keyservers in our /etc/pacman.d/gnupg/gpg.conf"

sleep 5

echo "get the mylastarch key in"
sudo pacman-key --recv-keys C8B25E49B0428123 --keyserver keyserver.ubuntu.com
#sudo pacman-key --recv-keys C8B25E49B0428123 --keyserver hkp://pool.sks-keyservers.net:80
echo "Lsign the keys"
sudo pacman-key --lsign-key C8B25E49B0428123

echo "###################################################################"
echo "###################        DONE            ########################"
echo "###################################################################"
