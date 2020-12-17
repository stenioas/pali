#!/bin/sh
#
# arch-setup: Install and Config Archlinux
#
# ----------------------------------------------------------------------#
#
# References:
#   Archfi script by Matmaoul - github.com/Matmoul
#   Aui script by Helmuthdu - github.com/helmuthdu
#   pos-alpine script by terminalroot - github.com/terroo
#
# ----------------------------------------------------------------------#
#
# The MIT License (MIT)
#
# Copyright (c) 2020 Stenio Silveira
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# ----------------------------------------------------------------------#

### VARS

    # --- COLORS
      BOLD=$(tput bold)
      UNDERLINE=$(tput sgr 0 1)
      RESET=$(tput sgr0)

      # Regular Colors
      BLACK=$(tput setaf 0)
      RED=$(tput setaf 1)
      GREEN=$(tput setaf 2)
      YELLOW=$(tput setaf 3)
      BLUE=$(tput setaf 4)
      PURPLE=$(tput setaf 5)
      CYAN=$(tput setaf 6)
      WHITE=$(tput setaf 7)

      # Bold Colors
      BBLACK=${BOLD}${BLACK}
      BRED=${BOLD}${RED}
      BGREEN=${BOLD}${GREEN}
      BYELLOW=${BOLD}${YELLOW}
      BBLUE=${BOLD}${BLUE}
      BPURPLE=${BOLD}${PURPLE}
      BCYAN=${BOLD}${CYAN}
      BWHITE=${BOLD}${WHITE}

      # Background Colors
      BG_BLACK=$(tput setab 0)
      BG_RED=$(tput setab 1)
      BG_GREEN=$(tput setab 2)
      BG_YELLOW=$(tput setab 3)
      BG_BLUE=$(tput setab 4)
      BG_PURPLE=$(tput setab 5)
      BG_CYAN=$(tput setab 6)
      BG_WHITE=$(tput setab 7)

    # --- ESSENTIALS
      APP_TITLE="myarch-setup 0.1"
      NEW_LANGUAGE="pt_BR"
      NEW_ZONE="America"
      NEW_SUBZONE="Fortaleza"
      NEW_GRUB_NAME="Archlinux"
      T_COLS=$(tput cols)
      T_LINES=$(tput lines)
      TRIM=0

    # --- MOUNTPOINTS
      EFI_PARTITION="/dev/sda1"
      EFI_MOUNTPOINT="/boot/efi"
      ROOT_PARTITION="/dev/sda3"
      ROOT_MOUNTPOINT="/mnt"

    # --- PROMPT
      PROMPT1="${BGREEN}→ ${RESET}"

# ----------------------------------------------------------------------#

### TESTS

_check_connection() {
    _connection_test() {
      ping -q -w 1 -c 1 "$(ip r | grep default | awk 'NR==1 {print $3}')" &> /dev/null && return 0 || return 1
    }
    if ! _connection_test; then
      _print_title_alert "CONNECTION"
      _print_warning "You are not connected. Solve this problem and run this script again."
      _print_bye
      exit 1
    fi
}

# ----------------------------------------------------------------------#

### CORE FUNCTIONS

_setup_install(){
    [[ $(id -u) != 0 ]] && {
      _print_warning "Only for 'root'.\n"
      exit 1
    }
    _initial_info
    _rank_mirrors
    _select_disk
    _format_partitions
    _install_base
    _fstab_generate
    _set_timezone_and_clock
    _set_localization
    _set_network
    _mkinitcpio_generate
    _root_passwd
    _grub_generate
    _finish_install
    exit 0
}

_setup_config(){
    [[ $(id -u) != 0 ]] && {
      _print_warning "Only for 'root'.\n"
      exit 1
    }
    _create_new_user
    _enable_multilib
    _install_essential_pkgs
    _install_xorg
    _install_vga
    _install_extra_pkgs
    _install_laptop_pkgs
    _finish_config
    exit 0
}

_setup_desktop(){
    [[ $(id -u) != 0 ]] && {
      _print_warning "Only for 'root'.\n"
      exit 1
    }
    _install_desktop
    _install_display_manager
    _finish_desktop
    exit 0
}

_setup_user(){
    [[ $(id -u) != 1000 ]] && {
      _print_warning "Only for 'normal user'.\n"
      exit 1
    }
    _install_apps
    _install_pamac
    exit 0
}

# ----------------------------------------------------------------------#

### BASE FUNCTIONS

# --- INSTALL SECTION --- >

_initial_info() {
  _print_title_alert "IMPORTANT"
  cat <<EOF

${CYAN}  * This script supports ${RESET}${BYELLOW}UEFI only${RESET}.
${CYAN}  * This script, for now, will install ${RESET}${BYELLOW}GRUB${RESET}${CYAN} as default bootloader.${RESET}
${CYAN}  * This script installs the following kernels and their respective headers:${RESET}
${CYAN}      - ${RESET}${BYELLOW}linux${RESET}
${CYAN}      - ${RESET}${BYELLOW}linux-lts${RESET}
${CYAN}  * This script will only consider two partitions, ${RESET}${BYELLOW}ESP${RESET}${CYAN} and${RESET}${BYELLOW} ROOT.${RESET}
${CYAN}  * This script will format the root partition in ${RESET}${BYELLOW}BTRFS${RESET}${CYAN} format.${RESET}
${CYAN}  * The ESP partition can be formatted if the user wants to.${RESET}
${CYAN}  * This script does not support ${BYELLOW}SWAP${RESET}.
${CYAN}  * This script will create three subvolumes:${RESET}
${CYAN}      - ${BYELLOW}@${RESET}${CYAN} for /${RESET}
${CYAN}      - ${BYELLOW}@home${RESET}${CYAN} for /home${RESET}
${CYAN}      - ${BYELLOW}@.snapshots${RESET}${CYAN} for /.snapshots${RESET}
${CYAN}  * This script, for now, sets zoneinfo as America/Fortaleza.${RESET}
${CYAN}  * This script sets hwclock as UTC.${RESET}
  
${BYELLOW}  * This script is not yet complete!${RESET}
  
${BWHITE}  * Btw, thank's for your time!${RESET}
EOF
  echo -e "${RED}`seq -s '─' $(( T_COLS + 1 )) | tr -d [:digit:]`${RESET}"
  read -e -sn 1 -p "${BRED} Press any key to continue...${RESET}"
}

_rank_mirrors() {
  _print_title "MIRRORS"
  if [[ ! -f /etc/pacman.d/mirrorlist.backup ]]; then
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
  fi
  _print_subtitle "Running..."
  _print_item "reflector -c Brazil --sort score --save /etc/pacman.d/mirrorlist"
  reflector -c Brazil --sort score --save /etc/pacman.d/mirrorlist && _print_ok
  _print_item "pacman -Syy"
  pacman -Syy &> /dev/null && _print_ok
  _read_input_option "Edit your mirrorlist file? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    nano /etc/pacman.d/mirrorlist
  else
    _pause_function
  fi
}

_select_disk() {
  _print_title "PARTITION THE DISKS"
  PS3="$PROMPT1"
  DEVICES_LIST=($(lsblk -d | awk '{print "/dev/" $1}' | grep 'sd\|hd\|vd\|nvme\|mmcblk'))
  _print_subtitle "Select disk:"
  select DEVICE in "${DEVICES_LIST[@]}"; do
    if _contains_element "${DEVICE}" "${DEVICES_LIST[@]}"; then
      break
    else
      _invalid_option
    fi
  done
  INSTALL_DISK=${DEVICE}
  _read_input_option "Edit disk partitions? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    cfdisk ${INSTALL_DISK}
  else
    _pause_function
  fi
}

_format_partitions() {
  _print_title "FORMAT THE PARTITIONS / MOUNT THE FILE SYSTEMS"
  BLOCK_LIST=($(lsblk | grep 'part\|lvm' | awk '{print substr($1,3)}'))

  PARTITIONS_LIST=()
  for OPT in "${BLOCK_LIST[@]}"; do
    PARTITIONS_LIST+=("/dev/${OPT}")
  done

  if [[ ${#BLOCK_LIST[@]} -eq 0 ]]; then
    _print_warning "No partition found."
    exit 0
  fi

  _format_root_partition() {
    echo
    _print_danger "All data on the partition will be LOST!"
    tput cuu 1
    _print_select_partition "ROOT"
    PS3="$PROMPT1"
    select PARTITION in "${PARTITIONS_LIST[@]}"; do
      if _contains_element "${PARTITION}" "${PARTITIONS_LIST[@]}"; then
        PARTITION_NUMBER=$((REPLY -1))
        ROOT_PARTITION="$PARTITION"
        break;
      else
        _invalid_option
      fi
    done
    if mount | grep "${ROOT_PARTITION}" &> /dev/null; then
      umount -R ${ROOT_MOUNTPOINT}
    fi
    _print_subtitle "Setting partition..."
    _print_action "Format" "${ROOT_PARTITION}"
    mkfs.btrfs -f -L Archlinux ${ROOT_PARTITION} &> /dev/null && _print_ok
    mount ${ROOT_PARTITION} ${ROOT_MOUNTPOINT} &> /dev/null
    _print_action "Create subvolume" "@"
    btrfs su cr ${ROOT_MOUNTPOINT}/@ &> /dev/null && _print_ok
    _print_action "Create subvolume" "@home"
    btrfs su cr ${ROOT_MOUNTPOINT}/@home &> /dev/null && _print_ok
    _print_action "Create subvolume" "@.snapshots"
    btrfs su cr ${ROOT_MOUNTPOINT}/@.snapshots &> /dev/null && _print_ok
    umount -R ${ROOT_MOUNTPOINT} &> /dev/null
    _print_action "Mount" "@"
    mount -o noatime,compress=lzo,space_cache,commit=120,subvol=@ ${ROOT_PARTITION} ${ROOT_MOUNTPOINT} &> /dev/null && _print_ok
    mkdir -p ${ROOT_MOUNTPOINT}/{home,.snapshots} &> /dev/null
    _print_action "Mount" "@home"
    mount -o noatime,compress=lzo,space_cache,commit=120,subvol=@home ${ROOT_PARTITION} ${ROOT_MOUNTPOINT}/home &> /dev/null && _print_ok
    _print_action "Mount" "@.snapshots"
    mount -o noatime,compress=lzo,space_cache,commit=120,subvol=@.snapshots ${ROOT_PARTITION} ${ROOT_MOUNTPOINT}/.snapshots &> /dev/null && _print_ok
    _check_mountpoint "${ROOT_PARTITION}" "${ROOT_MOUNTPOINT}"
  }

  _format_efi_partition() {
    _print_select_partition "EFI"
    PS3="$PROMPT1"
    select PARTITION in "${PARTITIONS_LIST[@]}"; do
      if _contains_element "${PARTITION}" "${PARTITIONS_LIST[@]}"; then
        EFI_PARTITION="${PARTITION}"
        break;
      else
        _invalid_option
      fi
    done
    _read_input_option "Format EFI partition? [y/N]: "
    if [[ $OPTION == y || $OPTION == Y ]]; then
      _print_danger "All data on the partition will be LOST!"
      tput cuu 1
      _read_input_option "${BPURPLE}Confirm format EFI partition? [y/N]: ${RESET}"
      if [[ $OPTION == y || $OPTION == Y ]]; then
        _print_subtitle "Setting partition..."
        _print_action "Format" "${EFI_PARTITION}"
        mkfs.fat -F32 ${EFI_PARTITION} &> /dev/null && _print_ok
        mkdir -p ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null
        _print_action "Mount" "${EFI_PARTITION}"
        mount -t vfat ${EFI_PARTITION} ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null && _print_ok
      else
        _print_subtitle "Setting partition..."
        mkdir -p ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null
        _print_action "Mount" "${EFI_PARTITION}"
        mount -t vfat ${EFI_PARTITION} ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null && _print_ok
      fi
    else
      _print_subtitle "Setting partition..."
      mkdir -p ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null
      _print_action "Mount" "${EFI_PARTITION}"
      mount -t vfat ${EFI_PARTITION} ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null && _print_ok
    fi
    _check_mountpoint "${EFI_PARTITION}" "${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT}"
  }

  _disable_partition() {
    unset PARTITIONS_LIST["${PARTITION_NUMBER}"]
    PARTITIONS_LIST=("${PARTITIONS_LIST[@]}")
  }

  _check_mountpoint() {
    if mount | grep "$2" &> /dev/null; then
      echo
      _print_info "Partition successfully mounted!"
      _disable_partition "$1"
    else
      echo
      _print_warning "Partition not successfully mounted!"
    fi
  }
  _format_root_partition
  _format_efi_partition
  _pause_function
}

_install_base() {
  _print_title "BASE"
  _print_subtitle "Installing packages..."
  _pacstrap_install "base base-devel"
  _pacstrap_install "linux linux-headers linux-lts linux-lts-headers linux-firmware"
  _pacstrap_install "intel-ucode"
  _pacstrap_install "btrfs-progs"
  _pacstrap_install "networkmanager"
  _print_subtitle "Enabling services..."
  _print_item "NetworkManager"
  arch-chroot ${ROOT_MOUNTPOINT} systemctl enable NetworkManager &> /dev/null && _print_ok
  _pause_function
}

_fstab_generate() {
  _print_title "FSTAB"
  _print_subtitle "Generating fstab..."
  _print_item "genfstab -U ${ROOT_MOUNTPOINT} > ${ROOT_MOUNTPOINT}/etc/fstab"
  genfstab -U ${ROOT_MOUNTPOINT} > ${ROOT_MOUNTPOINT}/etc/fstab && _print_ok
  _read_input_option "Edit your fstab file? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    nano ${ROOT_MOUNTPOINT}/etc/fstab
  else
    _pause_function
  fi
}
genfstab -U /mnt > /mnt/etc/fstab
_set_timezone_and_clock() {
  _print_title "TIME ZONE AND SYSTEM CLOCK"
  _print_subtitle "Running..."
  _print_item "timedatectl set-ntp true"
  arch-chroot ${ROOT_MOUNTPOINT} timedatectl set-ntp true &> /dev/null && _print_ok
  _print_item "ln -sf /usr/share/zoneinfo/${NEW_ZONE}/${NEW_SUBZONE} /etc/localtime"
  arch-chroot ${ROOT_MOUNTPOINT} ln -sf /usr/share/zoneinfo/${NEW_ZONE}/${NEW_SUBZONE} /etc/localtime &> /dev/null && _print_ok
  arch-chroot ${ROOT_MOUNTPOINT} sed -i '/#NTP=/d' /etc/systemd/timesyncd.conf
  arch-chroot ${ROOT_MOUNTPOINT} sed -i 's/#Fallback//' /etc/systemd/timesyncd.conf
  arch-chroot ${ROOT_MOUNTPOINT} echo \"FallbackNTP=a.st1.ntp.br b.st1.ntp.br 0.br.pool.ntp.org\" >> /etc/systemd/timesyncd.conf 
  arch-chroot ${ROOT_MOUNTPOINT} systemctl enable systemd-timesyncd.service &> /dev/null
  _print_item "hwclock --systohc --utc"
  arch-chroot ${ROOT_MOUNTPOINT} hwclock --systohc --utc &> /dev/null && _print_ok
  sed -i 's/#\('pt_BR'\)/\1/' ${ROOT_MOUNTPOINT}/etc/locale.gen
  _pause_function
}

_set_localization() {
  _print_title "LOCALIZATION"
  _print_subtitle "Running..."
  _print_item "locale-gen"
  arch-chroot ${ROOT_MOUNTPOINT} locale-gen &> /dev/null && _print_ok
  _print_item "echo LANG=pt_BR.UTF-8 > ${ROOT_MOUNTPOINT}/etc/locale.conf"
  echo "LANG=pt_BR.UTF-8" > ${ROOT_MOUNTPOINT}/etc/locale.conf && _print_ok
  _print_item "echo KEYMAP=br-abnt2 > ${ROOT_MOUNTPOINT}/etc/vconsole.conf"
  echo "KEYMAP=br-abnt2" > ${ROOT_MOUNTPOINT}/etc/vconsole.conf && _print_ok
  _pause_function  
}

_set_network() {
  _print_title "NETWORK CONFIGURATION"
  _read_input_text "Type a hostname: "
  read -r NEW_HOSTNAME
  while [[ "${NEW_HOSTNAME}" == "" ]]; do
    _print_title "NETWORK CONFIGURATION"
    echo
    _print_warning "You must be type a hostname!"
    _read_input_text "Type a hostname: "
    read -r NEW_HOSTNAME
  done
  NEW_HOSTNAME=$(echo "$NEW_HOSTNAME" | tr '[:upper:]' '[:lower:]')
  _print_subtitle "Setting..."
  _print_item "hostname file"
  echo ${NEW_HOSTNAME} > ${ROOT_MOUNTPOINT}/etc/hostname && _print_ok
  _print_item "hosts file"
  echo -e "127.0.0.1 localhost.localdomain localhost" > ${ROOT_MOUNTPOINT}/etc/hosts
  echo -e "::1 localhost.localdomain localhost" >> ${ROOT_MOUNTPOINT}/etc/hosts
  echo -e "127.0.1.1 ${NEW_HOSTNAME}.localdomain ${NEW_HOSTNAME}" >> ${ROOT_MOUNTPOINT}/etc/hosts && _print_ok
  _print_subtitle "Hosts file content:"
  cat <<EOF 
127.0.0.1 localhost.localdomain localhost
::1 localhost.localdomain localhost
127.0.1.1 ${YELLOW}${NEW_HOSTNAME}${RESET}.localdomain ${YELLOW}${NEW_HOSTNAME}${RESET}
EOF
  _pause_function  
}

_mkinitcpio_generate() {
  _print_title "INITRAMFS"
  echo
  arch-chroot ${ROOT_MOUNTPOINT} mkinitcpio -P
  _pause_function
}

_root_passwd() {
  PASSWD_CHECK=0
  _print_title "ROOT PASSWORD"
  _print_subtitle "Type root password:"
  echo -ne "${CYAN}"
  arch-chroot ${ROOT_MOUNTPOINT} passwd && PASSWD_CHECK=1;
  echo -ne "${RESET}"
  while [[ $PASSWD_CHECK == 0 ]]; do
    _print_title "ROOT PASSWORD"
    echo
    _print_warning "The password does not match!"
    tput cuu 1
    _print_subtitle "Type root password:"
    echo -ne "${CYAN}"
    arch-chroot ${ROOT_MOUNTPOINT} passwd && PASSWD_CHECK=1;
    echo -ne "${RESET}"
  done
  _pause_function
}

_grub_generate() {
  _print_title "GRUB BOOTLOADER"
  _read_input_text "Type a grub name entry: "
  read -r NEW_GRUB_NAME
  while [[ "${NEW_GRUB_NAME}" == "" ]]; do
    _print_title "GRUB BOOTLOADER"
    echo
    _print_warning "YOU MUST BE TYPE A GRUB NAME ENTRY!"
    _read_input_text "Type a grub name entry: "
    read -r NEW_GRUB_NAME
  done
  _print_subtitle "Installing Packages..."
  _pacstrap_install "grub grub-btrfs efibootmgr"
  _print_subtitle "Installing GRUB..."
  echo -ne "${CYAN}"
  arch-chroot ${ROOT_MOUNTPOINT} grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=${NEW_GRUB_NAME} --recheck
  echo -ne "${RESET}"
  _print_subtitle "Generating grub.cfg..."
  echo -ne "${CYAN}"
  arch-chroot ${ROOT_MOUNTPOINT} grub-mkconfig -o /boot/grub/grub.cfg
  echo -ne "${RESET}"
  _pause_function  
}

_finish_install() {
  _print_title "FIRST STEP FINISHED"
  _read_input_option "Save a copy of this script in root directory? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    if ! _is_package_installed "wget"; then
      _package_install "wget"
    fi
    _print_subtitle "Downloading..."
    _print_action "Download" "setup.sh"
    wget -O ${ROOT_MOUNTPOINT}/root/setup.sh "stenioas.github.io/myarch/setup.sh" &> /dev/null && _print_ok
  fi
  cp /etc/pacman.d/mirrorlist.backup ${ROOT_MOUNTPOINT}/etc/pacman.d/mirrorlist.backup
  _read_input_option "Reboot system? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    _umount_partitions
    reboot
  fi
  _print_bye
  exit 0
}

# --- END INSTALL SECTION --- >

# --- CONFIG SECTION --- >

_create_new_user() {
  _print_title "NEW USER"
  _read_input_text "Type your username: "
  read -r NEW_USER
  while [[ "${NEW_USER}" == "" ]]; do
    _print_title "NEW USER"
    _print_warning "You must be type a username!"
    _read_input_text "Type your username: "
    read -r NEW_USER
  done
  NEW_USER=$(echo "$NEW_USER" | tr '[:upper:]' '[:lower:]')
  if [[ "$(grep ${NEW_USER} /etc/passwd)" == "" ]]; then
    useradd -m -g users -G wheel ${NEW_USER}
    _print_action "Create user" "${NEW_USER}"
    _print_subtitle "Type user password:"
    passwd ${NEW_USER}
    _print_info "Privileges added."
    sed -i '/%wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers
  else
    _print_info "User ${NEW_USER} already exists!"
  fi
  _pause_function
}

_enable_multilib(){
  _print_title "MULTILIB"
  ARCHI=$(uname -m)
  if [[ $ARCHI == x86_64 ]]; then
    local _has_multilib=$(grep -n "\[multilib\]" /etc/pacman.conf | cut -f1 -d:)
    if [[ -z $_has_multilib ]]; then
      _print_item "Multilib"
      echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf && _print_ok
    else
      sed -i "${_has_multilib}s/^#//" /etc/pacman.conf
      local _has_multilib=$(( _has_multilib + 1 ))
      sed -i "${_has_multilib}s/^#//" /etc/pacman.conf
    fi
  fi
  _print_subtitle "Updating mirrors..."
  pacman -Syy
  _pause_function
}

_install_essential_pkgs() {
  _print_title "ESSENTIAL PACKAGES"
  _package_install "dosfstools mtools udisks2 dialog wget git nano reflector bash-completion xdg-utils xdg-user-dirs"
  _pause_function
}

_install_xorg() {
  _print_title "XORG"
  _group_package_install "xorg"
  _group_package_install "xorg-apps"
  _package_install "xorg-xinit xterm"
  _pause_function
}

_install_vga() {
  _print_title "VIDEO DRIVER"
  PS3="$PROMPT1"
  VIDEO_CARD_LIST=("Intel" "AMD" "Nvidia" "Virtualbox");
  _print_subtitle "Select video card:\n"
  select VIDEO_CARD in "${VIDEO_CARD_LIST[@]}"; do
    if _contains_element "${VIDEO_CARD}" "${VIDEO_CARD_LIST[@]}"; then
      break
    else
      _invalid_option
    fi
  done
  _print_title "VIDEO DRIVER"
  echo -e "${BGREEN}==> ${BWHITE}${VIDEO_CARD}${RESET} ${BGREEN}[ SELECTED ]${RESET}"

  if [[ "$VIDEO_CARD" == "Intel" ]]; then
    _package_install "xf86-video-intel mesa mesa-libgl libvdpau-va-gl"

  elif [[ "$VIDEO_CARD" == "AMD" ]]; then
    _print_warning "It's not working yet..."

  elif [[ "$VIDEO_CARD" == "Nvidia" ]]; then
    _print_warning "It's not working yet..."

  elif [[ "$VIDEO_CARD" == "Virtualbox" ]]; then
    _package_install "xf86-video-vmware virtualbox-guest-utils virtualbox-guest-dkms mesa mesa-libgl libvdpau-va-gl"

  else
    _invalid_option
    exit 0
  fi
  _pause_function
}

_install_extra_pkgs() {
  _print_title "EXTRA PACKAGES"
  _print_subtitle "Installing Utils"
  _package_install "usbutils lsof dmidecode neofetch bashtop htop avahi nss-mdns logrotate sysfsutils mlocate"
  _print_subtitle "Installing compression tools"
  _package_install "zip unzip unrar p7zip lzop"
  _print_subtitle "Installing extra filesystem tools"
  _package_install "ntfs-3g autofs fuse fuse2 fuse3 fuseiso mtpfs"
  _print_subtitle "Installing sound tools"
  _package_install "alsa-utils pulseaudio"
  _pause_function
}

_install_laptop_pkgs() {
  _print_title "LAPTOP PACKAGES"
  PS3="$PROMPT1"
  _read_input_option "Install laptop packages? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    _print_title "LAPTOP PACKAGES"
    _print_subtitle "Packages"
    _package_install "wpa_supplicant wireless_tools bluez bluez-utils pulseaudio-bluetooth xf86-input-synaptics"
    _print_subtitle "Services"
    _print_item "Bluetooth"
    systemctl enable bluetooth &> /dev/null && _print_ok
  else
    -_print_info "Nothing to do!"
  fi
  _pause_function
}

_finish_config() {
  _print_title "SECOND STEP FINISHED"
  _pause_function
  exit 0
}

# --- END CONFIG SECTION --- >

# --- DESKTOP SECTION --- >

_install_desktop() {
  _print_title "DESKTOP OR WINDOW MANAGER"
  PS3="$PROMPT1"
  DESKTOP_LIST=("Gnome" "Plasma" "Xfce" "i3-gaps" "Bspwm" "Awesome" "Openbox" "Qtile" "None");
  _print_warning " * Select your option:\n"
  select DESKTOP in "${DESKTOP_LIST[@]}"; do
    if _contains_element "${DESKTOP}" "${DESKTOP_LIST[@]}"; then
      break
    else
      _invalid_option
    fi
  done
  _print_title "DESKTOP OR WINDOW MANAGER"
  DESKTOP_CHOICE=$(echo "${DESKTOP}" | tr '[:lower:]' '[:upper:]')
  echo -e " ${PURPLE}${DESKTOP_CHOICE}${RESET}"
  echo
  
  if [[ "${DESKTOP}" == "Gnome" ]]; then
    _group_package_install "gnome"
    _group_package_install "gnome-extra"
    _package_install "gnome-tweaks"

  elif [[ "${DESKTOP}" == "Plasma" ]]; then
    _package_install "plasma kde-applications packagekit-qt5"

  elif [[ "${DESKTOP}" == "Xfce" ]]; then
    _package_install "xfce4 xfce4-goodies xarchiver network-manager-applet"

  elif [[ "${DESKTOP}" == "i3-gaps" ]]; then
    _package_install "i3-gaps i3status i3blocks i3lock dmenu rofi arandr feh nitrogen picom lxappearance xfce4-terminal xarchiver network-manager-applet"

  elif [[ "${DESKTOP}" == "Bspwm" ]]; then
    _print_warning "It's not working yet..."

  elif [[ "${DESKTOP}" == "Awesome" ]]; then
    _print_warning "It's not working yet..."

  elif [[ "${DESKTOP}" == "Openbox" ]]; then
    _package_install "openbox obconf dmenu rofi arandr feh nitrogen picom lxappearance xfce4-terminal xarchiver network-manager-applet"

  elif [[ "${DESKTOP}" == "Qtile" ]]; then
    _package_install "qtile dmenu rofi arandr feh nitrogen picom lxappearance xfce4-terminal xarchiver network-manager-applet"

  elif [[ "${DESKTOP}" == "None" ]]; then
    _print_info "Nothing to do!"

  else
    _invalid_option
    exit 0
  fi
  localectl set-x11-keymap br
  _pause_function
}

_install_display_manager() {
  _print_title "DISPLAY MANAGER"
  PS3="$PROMPT1"
  DMANAGER_LIST=("Lightdm" "Lxdm" "Slim" "GDM" "SDDM" "Xinit" "None");
  _print_warning " * Select your option:\n"
  select DMANAGER in "${DMANAGER_LIST[@]}"; do
    if _contains_element "${DMANAGER}" "${DMANAGER_LIST[@]}"; then
      break
    else
      _invalid_option
    fi
  done
  _print_title "DISPLAY MANAGER"
  DMANAGER_CHOICE=$(echo "${DMANAGER}" | tr '[:lower:]' '[:upper:]')
  echo -e " ${PURPLE}${DMANAGER_CHOICE}${RESET}\n"

  if [[ "${DMANAGER}" == "Lightdm" ]]; then
    _package_install "lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
    _print_subtitle "Services"
    _print_item "LightDM"
    sudo systemctl enable lightdm &> /dev/null && _print_ok

  elif [[ "${DMANAGER}" == "Lxdm" ]]; then
    _print_warning "It's not working yet..."

  elif [[ "${DMANAGER}" == "Slim" ]]; then
    _print_warning "It's not working yet..."

  elif [[ "${DMANAGER}" == "GDM" ]]; then
    _package_install "gdm"
    _print_subtitle "Services"
    _print_item "GDM"
    sudo systemctl enable gdm &> /dev/null && _print_ok

  elif [[ "${DMANAGER}" == "SDDM" ]]; then
    _package_install "sddm"
    _print_subtitle "Services"
    _print_item "SDDM"
    sudo systemctl enable sddm &> /dev/null && _print_ok

  elif [[ "${DMANAGER}" == "Xinit" ]]; then
    _print_warning "It's not working yet..."

  elif [[ "${DMANAGER}" == "None" ]]; then
    _print_info "Nothing to do!"

  else
    _invalid_option
    exit 0
  fi
  _pause_function
}

_finish_desktop() {
  _print_title "THIRD STEP FINISHED"
  _print_info "[ OPTIONAL ] Proceed to the last step for install apps. Use ${BYELLOW}-u${RESET} ${BWHITE}option.${RESET}"
  _pause_function
  exit 0
}

# --- END DESKTOP SECTION --- >

# --- USER SECTION --- >

_install_apps() {
  _print_title "CUSTOM APPS"
  PS3="$PROMPT1"
  _read_input_option "Install custom apps? [y/N]: "
  echo -e "\n"
  if [[ $OPTION == y || $OPTION == Y ]]; then
    _package_install "libreoffice-fresh libreoffice-fresh-pt-br"
    _package_install "firefox firefox-i18n-pt-br"
    _package_install "steam"
    _package_install "gimp"
    _package_install "inkscape"
    _package_install "vlc"
    _package_install "telegram-desktop"
    if ${DESKTOP} == "Plasma" ; then
      _package_install "transmission-qt"
    else
      _package_install "transmission-gtk"
    fi
    _package_install "simplescreenrecorder"
    _package_install "redshift"
    _package_install "ranger"
    _package_install "cmatrix"
    _package_install "adapta-gtk-theme"
    _package_install "arc-gtk-theme"
    _package_install "papirus-icon-theme"
    _package_install "capitaine-cursors"
    _package_install "ttf-dejavu"
  else
    echo -e " ${BYELLOW}* Nothing to do!${RESET}"
  fi
  _pause_function
}

_install_pamac() {
  _print_title "PAMAC"
  PS3="$PROMPT1"
  _read_input_option "Install pamac? [y/N]: "
  echo -e "\n"
  if [[ "${OPTION}" == "y" || "${OPTION}" == "Y" ]]; then
    if ! _is_package_installed "pamac"; then
      [[ -d pamac ]] && rm -rf pamac
      git clone https://aur.archlinux.org/pamac-aur.git pamac
      cd pamac
      makepkg -csi --noconfirm
    else
      echo -e " ${BCYAN}Pamac${RESET} - ${BYELLOW}Is already installed!${RESET}"
    fi
  else
    echo -e " ${BYELLOW}* Nothing to do!${RESET}"
  fi
  _pause_function
}

# --- END USER SECTION --- >

### OTHER FUNCTIONS

_print_line() {
  echo -e "${BWHITE}`seq -s '─' $(( T_COLS + 1 )) | tr -d [:digit:]`${RESET}"
}

_print_dline() {
  T_COLS=$(tput cols)
  echo -e "${BWHITE}`seq -s '═' $(( T_COLS + 1 )) | tr -d [:digit:]`${RESET}"
}

_print_line_red() {
  echo -e "${RED}`seq -s '─' $(( T_COLS + 1 )) | tr -d [:digit:]`${RESET}"
}

_print_dline_red() {
  T_COLS=$(tput cols)
  echo -e "${RED}`seq -s '═' $(( T_COLS + 1 )) | tr -d [:digit:]`${RESET}"
}

_print_line_bblack() {
  echo -e "${BBLACK}`seq -s '─' $(( T_COLS + 1 )) | tr -d [:digit:]`${RESET}"
}

_print_dline_bblack() {
  T_COLS=$(tput cols)
  echo -e "${BBLACK}`seq -s '═' $(( T_COLS + 1 )) | tr -d [:digit:]`${RESET}"
}

_print_title() {
  clear
  T_COLS=$(tput cols)
  T_APP_TITLE=$(echo ${#APP_TITLE})
  T_TITLE=$(echo ${#1})
  T_LEFT="${BBLACK}█▓▒░${RESET}${BWHITE}    $1    ${RESET}${BBLACK}░▒▓█${RESET}"
  T_RIGHT="${BBLACK}█▓▒░${RESET}${BBLACK}    ${APP_TITLE}${RESET}"
  echo -ne "${T_LEFT}"
  echo -ne "${BBLACK}`seq -s '█' $(( T_COLS - T_TITLE - T_APP_TITLE - 24 )) | tr -d [:digit:]`${RESET}"
  echo -e "${T_RIGHT}"
  _print_dline_bblack
}

_print_title_alert() {
  clear
  T_COLS=$(tput cols)
  T_APP_TITLE=$(echo ${#APP_TITLE})
  T_TITLE=$(echo ${#1})
  T_LEFT="${RED}█▓▒░${RESET}${BWHITE}    $1    ${RESET}${RED}░▒▓█${RESET}"
  T_RIGHT="${RED}█▓▒░${RESET}${BBLACK}    ${APP_TITLE}${RESET}"
  echo -ne "${T_LEFT}"
  echo -ne "${RED}`seq -s '█' $(( T_COLS - T_TITLE - T_APP_TITLE - 24 )) | tr -d [:digit:]`${RESET}"
  echo -e "${T_RIGHT}"
  _print_dline_red
}

_print_subtitle() {
  COLS_SUBTITLE=${#1}
  echo -e "\n${BWHITE}$1${RESET}"
  echo -e "${BBLACK}`seq -s '-' $(( COLS_SUBTITLE + 1 )) | tr -d [:digit:]`${RESET}"
}

_print_select_partition() {
  COLS_SUBTITLE=${#1}
  echo -e "\n${BWHITE}Select${RESET}${BYELLOW} $1${RESET}${BWHITE} partition:${RESET}"
  echo -e "${BBLACK}`seq -s '-' $(( COLS_SUBTITLE + 19 )) | tr -d [:digit:]`${RESET}"
}

_print_info() {
  T_COLS=$(tput cols)
  echo -e "${BBLUE}INFO:${RESET}${CYAN} $1${RESET}" | fold -sw $(( T_COLS - 1 ))
}

_print_warning() {
  T_COLS=$(tput cols)
  echo -e "${BYELLOW}WARNING:${RESET}${CYAN} $1${RESET}" | fold -sw $(( T_COLS - 1 ))
}

_print_danger() {
  T_COLS=$(tput cols)
  echo -e "${BRED}DANGER:${RESET}${CYAN} $1${RESET}" | fold -sw $(( T_COLS - 1 ))
}

_print_action() {
  COLS_VAR=$(( ${#1} + ${#2} + 1 ))
  echo -ne "${BBLACK}[      ]${RESET}${BBLACK} $1${RESET}${WHITE} $2${RESET}"
}

_print_item() {
  COLS_VAR=${#1}
  echo -ne "${BBLACK}[      ]${RESET}${WHITE} $1${RESET}"
}

_print_ok() {
  tput cub $(( COLS_VAR + 6 ))
  echo -e "${BGREEN}OK${RESET}"
}

_print_error() {
  tput cub $(( COLS_VAR + 6 ))
  echo -e "${BRED}FAIL${RESET}"
}

_print_bye() {
  echo
  _print_line_bblack
  echo -e "${BGREEN} Bye!${RESET}\n"
}

_read_input_text() {
  echo
  printf "%s" "${BWHITE}$1${RESET}"
}

_read_input_option() {
  echo
  printf "%s" "${PURPLE}$1${RESET}"
  read -r OPTION
}

_contains_element() {
    for e in "${@:2}"; do [[ "$e" == "$1" ]] && break; done;
}

_invalid_option() {
    _print_warning "Invalid option. Try again..."
}

_pause_function() {
  _print_line_bblack
  read -e -sn 1 -p "${BBLACK} Press any key to continue...${RESET}"
}

_umount_partitions() {
  _print_info "UMOUNTING PARTITIONS"
  umount -R ${ROOT_MOUNTPOINT}
}

_is_package_installed() {
  for PKG in $1; do
    pacman -Q "$PKG" &> /dev/null && return 0;
  done
  return 1
}

_package_install() { # install pacman package
  _package_was_installed() {
    for PKG in $1; do
      if [[ $(id -u) == 0 ]]; then
        pacman -S --noconfirm --needed "${PKG}" &> /dev/null && return 0;
      else
        sudo pacman -S --noconfirm --needed "${PKG}" &> /dev/null && return 0;
      fi
    done
    return 1
  }
  for PKG in $1; do
    if ! _is_package_installed "${PKG}"; then
      _print_item "${PKG}"
      if _package_was_installed "${PKG}"; then
        _print_ok
      else
        _print_error
      fi
    else
      _print_item "${PKG}"
      _print_ok
    fi
  done
}

_group_package_install() { # install a package group
  _package_install "$(pacman -Sqg ${1})"
}

_pacstrap_install() { # install pacstrap package
  _pacstrap_was_installed() {
    for PKG in $1; do
      pacstrap "${ROOT_MOUNTPOINT}" "${PKG}" &> /dev/null && return 0;
    done
    return 1
  }
  for PKG in $1; do
    _print_item "${PKG}"
    if _pacstrap_was_installed "${PKG}"; then
      _print_ok
    else
      _print_error
    fi
  done
}

usage() {
    cat <<EOF

usage: ${0##*/} [flags]

  Flag options:

    --install | -i         First step, only root user.
    --config  | -c         Second step, only root user.
    --desktop | -d         Third step, only root user.
    --user    | -u         Last step, only normal user.

arch-setup 0.1

EOF
}

_start_screen() {
  tput bold; tput setaf 2
  cat <<"EOF"

                 -@
                .##@
               .####@
               @#####@
             . *######@
            .##@o@#####@
           /############@
          /##############@
         @######@**%######@
        @######`     %#####o
       @######@       ######%               
     -@#######h       ######@.`
    /#####h**``       `**%@####@
   @H@*`                    `*%#@
  *`                            `*

EOF
  tput sgr0
  echo -e "${BBLACK}  My Personal ${RESET}${PURPLE}Arclinux${RESET}${BBLACK} Installer${RESET}"
  echo -e "${BBLACK}  By Stenio Silveira${RESET}"
  echo -e "${BGREEN}  https://github.com/stenioas/myarch${RESET}\n"
}

# ----------------------------------------------------------------------#

### EXECUTION

[[ -z $1 ]] && {
    usage
    exit 1
}
_check_connection
clear
setfont
timedatectl set-ntp true
_start_screen

while [[ "$1" ]]; do
  read -e -sn 1 -p "${BWHITE}  Press any key to start!${RESET}"
  case "$1" in
    --install|-i) _setup_install;;
    --config|-c) _setup_config;;
    --desktop|-d) _setup_desktop;;
    --user|-u) _setup_user;;
  esac
  shift
  _print_bye && exit 0
done