#!/bin/bash
set -e
##################################################################################################################
#
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
#
##################################################################################################################
echo
echo "################################################################## "
tput setaf 2
echo "Phase 1 : "
echo "- Setting General parameters"
tput sgr0
echo "################################################################## "
echo

	#Let us set the desktop"
	#First letter of desktop is small letter

	desktop="plasma"
	dmDesktop="plasma"

	#mylastarchVersion='26.05.31'

	isoLabel="mylastarch-Rc2-$(date +%Y.%m.%d)-x86_64.iso"

	# setting of the general parameters
	scriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
	repoDir="$(dirname -- "$scriptDir")"
	sourceProfile="$repoDir/archiso"
	readmeFile="$repoDir/archiso.readme"
	archisoRequiredVersion="archiso 89-1"
	buildFolder="$HOME/mylastarch-build"
	outFolder="$HOME/mylastarch-Out"
	archisoVersion="$(pacman -Q archiso)"

	echo "################################################################## "
	echo "Building the desktop                   : "$desktop
	#echo "Building version                       : "$mylastarchVersion
	#echo "Iso label                              : "$isoLabel
	echo "Do you have the right archiso version? : "$archisoVersion
	echo "What is the required archiso version?  : "$archisoRequiredVersion
	echo "Build folder                           : "$buildFolder
	echo "Out folder                             : "$outFolder
	echo "################################################################## "

	if [ "$archisoVersion" == "$archisoRequiredVersion" ]; then
		tput setaf 2
		echo "##################################################################"
		echo "Archiso has the correct version. Continuing ..."
		echo "##################################################################"
		tput sgr0
	else
	tput setaf 1
	echo "###################################################################################################"
	echo "You need to install the correct version of Archiso"
	echo "Use 'sudo downgrade archiso' to do that"
	echo "or update your system"
	echo "###################################################################################################"
	tput sgr0
	exit 1
	fi

echo
echo "################################################################## "
tput setaf 2
echo "Phase 2 :"
echo "- Checking if archiso is installed"
echo "- Saving current archiso version to readme"
tput sgr0
echo "################################################################## "
echo

		echo
		echo "Saving current archiso version to readme"
		sed -i "s/\(^archiso-version=\).*/\1$archisoVersion/" "$readmeFile"

#----------------------------------------------------------------------

package="mylastarch-keyring"

#checking if application is already installed or else install
	if pacman -Qi "$package" &> /dev/null; then
	
	echo "################################################################## "
	echo "mylastarch keyring is already installed"	
	echo "################################################################## "

else

	wget https://github.com/mylastarch/mylastarch_repo/raw/main/x86_64/mylastarch-keyring-1-7-x86_64.pkg.tar.zst -O /tmp/mylastarch-keyring-1-7-x86_64.pkg.tar.zst
	sudo pacman -U --noconfirm --needed /tmp/mylastarch-keyring-1-7-x86_64.pkg.tar.zst

fi

# Just cheking if installtion was successful
if pacman -Qi "$package" &> /dev/null; then

	echo "################################################################## "
	echo "############  "$package" has been installed"
	echo "################################################################## "
fi

#----------------------------------------------------------------------


echo
echo "################################################################## "
tput setaf 2
echo "Phase 3 :"
echo "- Deleting the build folder if one exists"
echo "- Copying the Archiso folder to build folder"
tput sgr0
echo "################################################################## "
echo

	echo "Deleting the build folder if one exists - takes some time"
		if [ -d "$buildFolder" ]; then
			sudo rm -rf -- "$buildFolder"
		fi
	echo
	echo "Copying the Archiso folder to build work"
	echo
		mkdir -p -- "$buildFolder"
		cp -a -- "$sourceProfile" "$buildFolder/archiso"

echo
echo "################################################################## "
tput setaf 2
echo "Phase 4 :"
echo "- Using packages.x86_64 from the copied Archiso profile"
tput sgr0
echo "################################################################## "
echo

echo
echo "################################################################## "
tput setaf 2
echo "Phase 5 : "
echo "- Changing all references"
echo "- Adding time to /etc/dev-rel"
tput sgr0
echo "################################################################## "
echo

		echo "Changing all references"
		echo
		sed -i 's/^iso_name=.*/iso_name="mylastarch-Rc2"/' "$buildFolder/archiso/profiledef.sh"
		sed -i 's/^iso_label=.*/iso_label="mylastarch-Rc2-$(date +%Y%m)"/' "$buildFolder/archiso/profiledef.sh"
		sed -i 's/^ISO_CODENAME=.*/ISO_CODENAME=mylastarch-Rc2/' "$buildFolder/archiso/airootfs/etc/dev-rel"
		printf '%s\n' 'mylastarch-Rc2' > "$buildFolder/archiso/airootfs/etc/hostname"
		sed -i "s/^Session=.*/Session=$dmDesktop/" "$buildFolder/archiso/airootfs/etc/sddm.conf"

	echo "Adding time to /etc/dev-rel"
	date_build=$(date -d now)
		echo "Iso build on : $date_build"
		sed -i "s/^ISO_BUILD=.*/ISO_BUILD=$date_build/" "$buildFolder/archiso/airootfs/etc/dev-rel"


#echo
#echo "################################################################## "
#tput setaf 2
#echo "Phase 6 :"
#echo "- Cleaning the cache from /var/cache/pacman/pkg/"
#tput sgr0
#echo "################################################################## "
#echo

	#echo "Cleaning the cache from /var/cache/pacman/pkg/"
	#yes | sudo pacman -Scc

echo
echo "################################################################## "
tput setaf 2
echo "Phase 7 :"
echo "- Building the iso - this can take a while - be patient"
tput sgr0
echo "################################################################## "
echo

		mkdir -p -- "$outFolder"
		cd "$buildFolder/archiso/"
		sudo mkarchiso -v -w "$buildFolder" -o "$outFolder" "$buildFolder/archiso/"

echo
echo "###################################################################"
tput setaf 2
echo "Phase 8 :"
echo "- Creating checksums"
echo "- Copying pgklist"
tput sgr0
echo "###################################################################"
echo

		cd "$outFolder"

		echo "Creating checksums for : $isoLabel"
	echo "##################################################################"
	echo
	echo "Building sha1sum"
	echo "########################"
		sha1sum "$isoLabel" | tee "$isoLabel.sha1"
	echo "Building sha256sum"
	echo "########################"
		sha256sum "$isoLabel" | tee "$isoLabel.sha256"
	echo "Building md5sum"
	echo "########################"
		md5sum "$isoLabel" | tee "$isoLabel.md5"
	echo
	echo "Moving pkglist.x86_64.txt"
	echo "########################"
		cp "$buildFolder/iso/arch/pkglist.x86_64.txt" "$outFolder/$isoLabel.pkglist.txt"

#echo
#echo "##################################################################"
#tput setaf 2
#echo "Phase 9 :"
#echo "- Making sure we start with a clean slate next time"
#tput sgr0
#echo "################################################################## "
#echo

	#echo "Deleting the build folder if one exists - takes some time"
	#[ -d $buildFolder ] && sudo rm -rf $buildFolder

echo
echo "##################################################################"
tput setaf 2
echo "DONE"
echo "- Check your out folder : $outFolder"
tput sgr0
echo "################################################################## "
echo
