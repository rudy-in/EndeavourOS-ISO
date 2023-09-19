#!/usr/bin/env bash

# Made by Fernando "maroto"
# Run anything in the filesystem right before being "mksquashed"
# ISO-NEXT specific cleanup removals and additions (08-2021 + 10-2021) @killajoe and @manuel
# refining and changes november 2021 @killajoe and @manuel

script_path=$(readlink -f "${0%/*}")
work_dir="work"

# Adapted from AIS. An excellent bit of code!
# all pathes must be in quotation marks "path/to/file/or/folder" for now.

arch_chroot() {
    arch-chroot "${script_path}/${work_dir}/x86_64/airootfs" /bin/bash -c "${1}"
}

do_merge() {

arch_chroot "$(cat << EOF

echo "##############################"
echo "# start chrooted commandlist #"
echo "##############################"

cd "/root"

# Init & Populate keys
pacman-key --init
pacman-key --populate archlinux endeavouros
pacman -Syy

# Install liveuser skel (in case of conflicts use overwrite)
pacman -U --noconfirm --overwrite "/etc/skel/.bash_profile","/etc/skel/.bashrc" -- "/root/endeavouros-skel-liveuser/"*".pkg.tar.zst"

# Prepare livesession settings and user
sed -i 's/#\(en_US\.UTF-8\)/\1/' "/etc/locale.gen"
locale-gen
ln -sf "/usr/share/zoneinfo/UTC" "/etc/localtime"

# Set root permission and shell
usermod -s /usr/bin/bash root

# Create liveuser
useradd -m -p "" -g 'liveuser' -G 'sys,rfkill,wheel,uucp,nopasswdlogin,adm,tty' -s /bin/bash liveuser
cp "/root/liveuser.png" "/var/lib/AccountsService/icons/liveuser"
rm "/root/liveuser.png"

# Remove liveuser skel to then install user skel
pacman -Rns --noconfirm -- "endeavouros-skel-liveuser"
rm -rf "/root/endeavouros-skel-liveuser"

# setup theming for root user
cp -a "/root/root-theme" "/root/.config"
rm -R "/root/root-theme"

# Add builddate to motd:
cat "/usr/lib/endeavouros-release" >> "/etc/motd"
echo "------------------" >> "/etc/motd"

# Install locally builded packages on ISO (place packages under airootfs/root/packages)
pacman -U --noconfirm -- "/root/packages/"*".pkg.tar.zst"
rm -rf "/root/packages/"


# Enable systemd services
# --> now in airootfs/etc/systemd/system/multi-user.target.wants
#systemctl enable NetworkManager.service systemd-timesyncd.service bluetooth.service firewalld.service
#systemctl enable intel.service
systemctl set-default multi-user.target


# Set wallpaper for live-session and original for installed system
mv "endeavouros-wallpaper.png" "/etc/calamares/files/endeavouros-wallpaper.png"
mv "/root/livewall.png" "/usr/share/endeavouros/backgrounds/endeavouros-wallpaper.png"
chmod 644 "/usr/share/endeavouros/backgrounds/"*".png"

# TEMPORARY CUSTOM FIXES

# Fix for getting bash configs installed
cp -af "/home/liveuser/"{".bashrc",".bash_profile"} "/etc/skel/"

# Move blacklisting nouveau out of ISO (copy back to target for offline installs)
mv "/usr/lib/modprobe.d/nvidia-utils.conf" "/etc/calamares/files/nv-modprobe"
mv "/usr/lib/modules-load.d/nvidia-utils.conf" "/etc/calamares/files/nv-modules-load"

# Get extra drivers!
mkdir "/opt/extra-drivers"
pacman -Syy
pacman -Sw --noconfirm --cachedir "/opt/extra-drivers" r8168-lts

# install packages
mkdir -p "/usr/share/packages"
pacman -Sw --noconfirm --cachedir "/usr/share/packages" grub eos-dracut kernel-install-for-dracut os-prober xf86-video-intel

# Clean pacman log and package cache
rm "/var/log/pacman.log"
# pacman -Scc seem to fail so:
rm -rf "/var/cache/pacman/pkg/"

#calamares BUG https://github.com/calamares/calamares/issues/2075
rm -rf /home/build

#create package versions file
pacman -Qs | grep "/calamares " | cut -c7- > iso_package_versions
pacman -Qs | grep "/firefox " | cut -c7- >> iso_package_versions
pacman -Qs | grep "/linux " | cut -c7- >> iso_package_versions
pacman -Qs | grep "/mesa " | cut -c7- >> iso_package_versions
pacman -Qs | grep "/xorg-server " | cut -c7- >> iso_package_versions
pacman -Qs | grep "/nvidia-dkms " | cut -c7- >> iso_package_versions
mv "iso_package_versions" "/home/liveuser/"

echo "############################"
echo "# end chrooted commandlist #"
echo "############################"

EOF
)"
}

#################################
########## STARTS HERE ##########
#################################

do_merge
