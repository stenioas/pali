#!/bin/sh
#
# Personal Arch Linux Installer (pali)
# ----------------------------------------------------------------------#
#
# author    : stenioas
#             https://github.com/stenioas
# project   : https://github.com/stenioas/stenio
#
# ----------------------------------------------------------------------#
#
# References:
#   Arch Wiki - wiki.archlinux.org
#   Archfi script by Matmaoul - github.com/Matmoul
#   Aui script by Helmuthdu - github.com/helmuthdu
#   pos-alpine script by terminalroot - github.com/terroo
#
# ----------------------------------------------------------------------#
#
# The MIT License (MIT)
#
# Copyright (c) 2018 Marcos Oliveira
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
    APP_TITLE="pali"
    APP_VERSION="0.01"
    LANGUAGE="pt_BR"
    GRUB_NAME="Archlinux"
    T_COLS=$(tput cols)
    T_LINES=$(tput lines)
    TRIM=0
    SPIN="/-\|" #SPINNER POSITION

  # --- MOUNTPOINTS
    EFI_PARTITION="/dev/sda1"
    EFI_MOUNTPOINT="/boot"
    ROOT_PARTITION="/dev/sda3"
    ROOT_MOUNTPOINT="/mnt"

  # --- PROMPT
    PS3="${BYELLOW}> ${RESET}"

# ----------------------------------------------------------------------#

### TEST FUNCTIONS

_check_connection() {
    _connection_test() {
      ping -q -w 1 -c 1 "$(ip r | grep default | awk 'NR==1 {print $3}')" &> /dev/null && return 0 || return 1
    }
    if ! _connection_test; then
      _print_title "CONNECTION"
      echo
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
  _initial_readme
  _initial
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
  _install_desktop
  _install_display_manager
  _finish_config
  exit 0
}

_setup_user(){
  [[ $(id -u) != 1000 ]] && {
    _print_warning "Only for 'normal user'.\n"
    exit 1
  }
  _initial_user
  _install_extra_pkgs
  _install_laptop_pkgs
  _install_apps
  _install_aurhelper
  exit 0
}

# ----------------------------------------------------------------------#

### BASE FUNCTIONS

# --- INSTALL SECTION --- >

_initial_readme() {
  _print_title "README"
  cat <<EOF

  - This script supports ${BYELLOW}UEFI${RESET} only.

  - This script, for now, will install ${BYELLOW}GRUB${RESET} as default bootloader.

  - This script will only consider two partitions, ${BYELLOW}ESP${RESET} and ${BYELLOW}ROOT${RESET}.

  - This script will format the root partition in ${BYELLOW}BTRFS${RESET} format.

  - The ESP partition can be formatted if the user wants to.

  - This script does not support ${BYELLOW}SWAP${RESET}.

  - This script will create three subvolumes:
        ${BYELLOW}@${RESET} for /
        ${BYELLOW}@home${RESET} for /home
        ${BYELLOW}@.snapshots${RESET} for /.snapshots

  - This script can be cancelled at any time with ${BYELLOW}CTRL+C${RESET}.

${BRED}  - This script is not yet complete!${RESET}
  
${BWHITE}  - Btw, thank's for your time!${RESET}
EOF
  _pause_function
}

_initial() {
  _print_title "LOADING REQUIRED DATA..."
  T_COLS=$(tput cols)
  T_LINES=$(tput lines)
  echo
  _print_action "Running" "timedatectl set-ntp true"
  timedatectl set-ntp true & PID=$!; _progress $PID
  _print_action "Updating" "archlinux-keyring"
  pacman -Sy --noconfirm archlinux-keyring &> /dev/null & PID=$!; _progress $PID
}

_rank_mirrors() {
  _print_title "MIRRORS"
  SAVEIFS=$IFS
  IFS=$'\n'
  COUNTRIES_LIST=($((reflector --list-countries) | sed 's/[0-9]//g' | sed 's/\s*$//g' | sed -r 's/(.*) /\1./' | cut -d '.' -f 1 | sed 's/\s*$//g'))
  IFS=$SAVEIFS
  _print_subtitle_select "Select your country:"
  select COUNTRY_CHOICE in "${COUNTRIES_LIST[@]}"; do
    if _contains_element "${COUNTRY_CHOICE}" "${COUNTRIES_LIST[@]}"; then
      COUNTRY_CHOICE="${COUNTRY_CHOICE}"
      break
    else
      _invalid_option
    fi
  done
  if [[ ! -f /etc/pacman.d/mirrorlist.backup ]]; then
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
  fi
  echo
  _print_action "Running" "reflector -c ${COUNTRY_CHOICE} --sort score --save /etc/pacman.d/mirrorlist"
  reflector -c ${COUNTRY_CHOICE} --sort score --save /etc/pacman.d/mirrorlist & PID=$!; _progress $PID
  echo
  _read_input_option "Edit your mirrorlist file? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    nano /etc/pacman.d/mirrorlist
    _print_title "MIRRORS"
  fi
  _print_subtitle "Updating"
  pacman -Syy
  _pause_function
}

_select_disk() {
  _print_title "PARTITION THE DISKS"
  DEVICES_LIST=($(lsblk -d | awk '{print "/dev/" $1}' | grep 'sd\|hd\|vd\|nvme\|mmcblk'))
  _print_subtitle_select "Select disk:"
  select DEVICE in "${DEVICES_LIST[@]}"; do
    if _contains_element "${DEVICE}" "${DEVICES_LIST[@]}"; then
      break
    else
      _invalid_option
    fi
  done
  INSTALL_DISK=${DEVICE}
  echo
  _print_line
  _read_input_option "Edit disk partitions? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    cfdisk ${INSTALL_DISK}
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
    _print_subtitle_select "Select ${BYELLOW}ROOT${RESET}${BCYAN} partition:${RESET}"
    _print_danger "All data on the partition will be LOST!"
    echo
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
    echo
    _print_action "Format" "${ROOT_PARTITION}"
    mkfs.btrfs -f -L Archlinux ${ROOT_PARTITION} &> /dev/null & PID=$!; _progress $PID
    mount ${ROOT_PARTITION} ${ROOT_MOUNTPOINT} &> /dev/null
    _print_action "Create subvolume" "@"
    btrfs su cr ${ROOT_MOUNTPOINT}/@ &> /dev/null & PID=$!; _progress $PID
    _print_action "Create subvolume" "@home"
    btrfs su cr ${ROOT_MOUNTPOINT}/@home &> /dev/null & PID=$!; _progress $PID
    _print_action "Create subvolume" "@.snapshots"
    btrfs su cr ${ROOT_MOUNTPOINT}/@.snapshots &> /dev/null & PID=$!; _progress $PID
    umount -R ${ROOT_MOUNTPOINT} &> /dev/null
    _print_action "Mount" "@"
    mount -o noatime,compress=lzo,space_cache,commit=120,subvol=@ ${ROOT_PARTITION} ${ROOT_MOUNTPOINT} &> /dev/null & PID=$!; _progress $PID
    mkdir -p ${ROOT_MOUNTPOINT}/{home,.snapshots} &> /dev/null
    _print_action "Mount" "@home"
    mount -o noatime,compress=lzo,space_cache,commit=120,subvol=@home ${ROOT_PARTITION} ${ROOT_MOUNTPOINT}/home &> /dev/null & PID=$!; _progress $PID
    _print_action "Mount" "@.snapshots"
    mount -o noatime,compress=lzo,space_cache,commit=120,subvol=@.snapshots ${ROOT_PARTITION} ${ROOT_MOUNTPOINT}/.snapshots &> /dev/null & PID=$!; _progress $PID
    _check_mountpoint "${ROOT_PARTITION}" "${ROOT_MOUNTPOINT}"
    _pause_function
  }

  _format_efi_partition() {
    _print_title "FORMAT THE PARTITIONS / MOUNT THE FILE SYSTEMS"
    _print_subtitle_select "Select ${BYELLOW}EFI${RESET}${BCYAN} partition:${RESET}"
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
      _read_input_option "${BRED}All data will be LOST! Confirm format EFI partition? [y/N]: ${RESET}"
      if [[ $OPTION == y || $OPTION == Y ]]; then
        echo
        _print_action "Format" "${EFI_PARTITION}"
        mkfs.fat -F32 ${EFI_PARTITION} &> /dev/null & PID=$!; _progress $PID
        mkdir -p ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null
        _print_action "Mount" "${EFI_PARTITION}"
        mount -t vfat ${EFI_PARTITION} ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null & PID=$!; _progress $PID
      else
        echo
        mkdir -p ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null
        _print_action "Mount" "${EFI_PARTITION}"
        mount -t vfat ${EFI_PARTITION} ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null & PID=$!; _progress $PID
      fi
    else
      echo
      mkdir -p ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null
      _print_action "Mount" "${EFI_PARTITION}"
      mount -t vfat ${EFI_PARTITION} ${ROOT_MOUNTPOINT}${EFI_MOUNTPOINT} &> /dev/null & PID=$!; _progress $PID
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
      _print_info "Partition(s) successfully mounted!"
      _disable_partition "$1"
    else
      echo
      _print_warning "Partition(s) not successfully mounted!"
    fi
  }
  _format_root_partition
  _format_efi_partition
  _pause_function
}

_install_base() {
  _print_title "BASE"
  _print_subtitle_select "Select ${BYELLOW}KERNEL${RESET}${BCYAN} version:${RESET}"
  KERNEL_LIST=("Linux" "Linux-lts" "Linux-zen" "Linux-hardened" "Another")
  select KERNEL_CHOICE in "${KERNEL_LIST[@]}"; do
    if _contains_element "${KERNEL_CHOICE}" "${KERNEL_LIST[@]}"; then
      KERNEL_CHOICE="${KERNEL_CHOICE}"
      break;
    else
      _invalid_option
    fi
  done
  case $KERNEL_CHOICE in
    Linux)
      KERNEL_VERSION="linux"
      ;;
    Linux-lts)
      KERNEL_VERSION="linux-lts"
      ;;
    Linux-zen)
      KERNEL_VERSION="linux-zen"
      ;;
    Linux-hardened)
      KERNEL_VERSION="linux-hardened"
      ;;
    Another)
      echo
      _read_input_text "Type the kernel package name do you want install:"
      read -r KERNEL_VERSION
      echo
      while [[ "${KERNEL_VERSION}" = "" ]]; do
        _print_warning "You must be type a kernel name!"
        echo
        _read_input_text "Type the kernel package name do you want install:"
        read -r KERNEL_VERSION
        echo
      done
      ;;
  esac
  _print_title "BASE"
  _print_subtitle_select "Select your microcode:${RESET}"
  MICROCODE_LIST=("amd-ucode" "intel-ucode" "none")
  select MICROCODE_CHOICE in "${MICROCODE_LIST[@]}"; do
    if _contains_element "${MICROCODE_CHOICE}" "${MICROCODE_LIST[@]}"; then
      MICROCODE_CHOICE="${MICROCODE_CHOICE}"
      break;
    else
      _invalid_option
    fi
  done
  case ${MICROCODE_CHOICE} in
    amd-ucode)
      MICROCODE_VERSION=${MICROCODE_CHOICE}
      ;;
    intel-ucode)
      MICROCODE_VERSION=${MICROCODE_CHOICE}
      ;;
    none)
      MICROCODE_VERSION=${MICROCODE_CHOICE}
      ;;
  esac
  _print_title "BASE"
  echo
  echo -e "${BBLUE}Kernel version: ${RESET}${KERNEL_VERSION}"
  echo -e "${BBLUE}Microcode:      ${RESET}${MICROCODE_VERSION}"
  echo
  _print_subtitle "Packages"
  _pacstrap_install "base base-devel"
  _pacstrap_install "${KERNEL_VERSION}"
  _pacstrap_install "${KERNEL_VERSION}-headers"
  _pacstrap_install "linux-firmware"
  if [[ "${MICROCODE_VERSION}" != "none" ]]; then
    _pacstrap_install "${MICROCODE_VERSION}"
  fi
  _pacstrap_install "btrfs-progs"
  _pacstrap_install "networkmanager"
  _print_subtitle "Services"
  _print_action "Enabling" "NetworkManager"
  arch-chroot ${ROOT_MOUNTPOINT} systemctl enable NetworkManager &> /dev/null & PID=$!; _progress $PID
  _pause_function
}

_fstab_generate() {
  _print_title "FSTAB"
  echo
  _print_action "Running" "genfstab -U ${ROOT_MOUNTPOINT} > ${ROOT_MOUNTPOINT}/etc/fstab"
  genfstab -U ${ROOT_MOUNTPOINT} > ${ROOT_MOUNTPOINT}/etc/fstab & PID=$!; _progress $PID
  echo
  _print_line
  _read_input_option "Edit your fstab file? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    nano ${ROOT_MOUNTPOINT}/etc/fstab
  fi
}

_set_timezone_and_clock() {
  _print_title "TIME ZONE AND SYSTEM CLOCK"
  # ZONE SECTION
  ZONE_LIST=($(timedatectl list-timezones | sed 's/\/.*$//' | uniq))
  _print_subtitle_select "Select your zone:"
  select ZONE in "${ZONE_LIST[@]}"; do
    if _contains_element "$ZONE" "${ZONE_LIST[@]}"; then
      SUBZONE_LIST=($(timedatectl list-timezones | grep "${ZONE}" | sed 's/^.*\///'))
      _print_title "TIME ZONE AND SYSTEM CLOCK"
      _print_subtitle_select "Select your subzone:"
      select SUBZONE in "${SUBZONE_LIST[@]}"; do
        if _contains_element "$SUBZONE" "${SUBZONE_LIST[@]}"; then
          break
        else
          _invalid_option
        fi
      done
      break
    else
      _invalid_option
    fi
  done
  # CLOCK SECTION
  _print_title "TIME ZONE AND SYSTEM CLOCK"
  CLOCK_LIST=("UTC" "Localtime")
  _print_subtitle_select "Select timescale:"
  select CLOCK_CHOICE in "${CLOCK_LIST[@]}"; do
    if _contains_element "${CLOCK_CHOICE}" "${CLOCK_LIST[@]}"; then
      CLOCK_CHOICE="${CLOCK_CHOICE}"
      break;
    else
      _invalid_option
    fi
  done
  _print_title "TIME ZONE AND SYSTEM CLOCK"
  echo
  echo -e "${BBLUE}Timezone:       ${RESET}${ZONE}/${SUBZONE}"
  echo -e "${BBLUE}Hardware Clock: ${RESET}${CLOCK_CHOICE}"
  echo
  _print_action "Running" "timedatectl set-ntp true"
  arch-chroot ${ROOT_MOUNTPOINT} timedatectl set-ntp true &> /dev/null & PID=$!; _progress $PID
  _print_action "Running" "ln -sf /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime"
  arch-chroot ${ROOT_MOUNTPOINT} ln -sf /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime &> /dev/null & PID=$!; _progress $PID
  arch-chroot ${ROOT_MOUNTPOINT} sed -i '/#NTP=/d' /etc/systemd/timesyncd.conf
  arch-chroot ${ROOT_MOUNTPOINT} sed -i 's/#Fallback//' /etc/systemd/timesyncd.conf
  arch-chroot ${ROOT_MOUNTPOINT} echo \"FallbackNTP=a.st1.ntp.br b.st1.ntp.br 0.br.pool.ntp.org\" >> /etc/systemd/timesyncd.conf 
  arch-chroot ${ROOT_MOUNTPOINT} systemctl enable systemd-timesyncd.service &> /dev/null
  if [[ "${CLOCK_CHOICE}" = "UTC" ]]; then
    _print_action "Running" "hwclock --systohc --utc"
    arch-chroot ${ROOT_MOUNTPOINT} hwclock --systohc --utc &> /dev/null & PID=$!; _progress $PID
  else
    _print_action "Running" "hwclock --systohc --localtime"
    arch-chroot ${ROOT_MOUNTPOINT} hwclock --systohc --localtime &> /dev/null & PID=$!; _progress $PID
  fi
  _pause_function
}

_set_localization() {
  _print_title "LOCALIZATION"
  LOCALE_LIST=($(grep UTF-8 /etc/locale.gen | sed 's/\..*$//' | sed '/@/d' | awk '{print $1}' | uniq | sed 's/#//g'))
  _print_subtitle_select "Select your language:"
  select LOCALE in "${LOCALE_LIST[@]}"; do
    if _contains_element "$LOCALE" "${LOCALE_LIST[@]}"; then
      LOCALE_UTF8="${LOCALE}.UTF-8"
      break
    else
      _invalid_option
    fi
  done
  _print_title "LOCALIZATION"
	KEYMAP_LIST=($(find /usr/share/kbd/keymaps/ -type f -printf "%f\n" | sort -V | sed 's/.map.gz//g'))
  KEYMAP_CHOICE="br-abnt2"
  echo
  _print_info "The default keymap will be set to 'br-abnt2' !"
  echo
  _read_input_option "Change default keymap? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    echo
    _read_input_text "Type your keymap:"
    read -r KEYMAP_CHOICE
    while ! _contains_element "${KEYMAP_CHOICE}" "${KEYMAP_LIST[@]}"; do
      _print_title "LOCALIZATION"
      echo
      _print_warning "This option is not available!"
      echo
      _read_input_text "Type your keymap:"
      read -r KEYMAP_CHOICE
    done
  fi
  _print_title "LOCALIZATION"
  echo
  echo -e "${BBLUE}Language: ${RESET}${LOCALE}"
  echo -e "${BBLUE}Keymap:   ${RESET}${KEYMAP_CHOICE}"
  echo
  sed -i 's/#\('${LOCALE}'\)/\1/' ${ROOT_MOUNTPOINT}/etc/locale.gen
  _print_action "Running" "locale-gen"
  arch-chroot ${ROOT_MOUNTPOINT} locale-gen &> /dev/null & PID=$!; _progress $PID
  _print_action "Running" "echo LANG=${LOCALE_UTF8} > ${ROOT_MOUNTPOINT}/etc/locale.conf"
  echo 'LANG="'"${LOCALE_UTF8}"'"' > ${ROOT_MOUNTPOINT}/etc/locale.conf & PID=$!; _progress $PID
  _print_action "Running" "echo KEYMAP=${KEYMAP_CHOICE} > ${ROOT_MOUNTPOINT}/etc/vconsole.conf"
  echo "KEYMAP=${KEYMAP_CHOICE}" > ${ROOT_MOUNTPOINT}/etc/vconsole.conf & PID=$!; _progress $PID
  _pause_function  
}

_set_network() {
  _print_title "NETWORK CONFIGURATION"
  echo
  _read_input_text "Type a hostname:"
  read -r HOSTNAME
  echo
  while [[ "${HOSTNAME}" == "" ]]; do
    _print_title "NETWORK CONFIGURATION"
    echo
    _print_warning "You must be type a hostname!"
    echo
    _read_input_text "Type a hostname:"
    read -r HOSTNAME
    echo
  done
  HOSTNAME=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]')
  _print_action "Setting" "hostname file"
  echo ${HOSTNAME} > ${ROOT_MOUNTPOINT}/etc/hostname & PID=$!; _progress $PID
  _print_action "Setting" "hosts file"
  echo -e "127.0.0.1 localhost.localdomain localhost" > ${ROOT_MOUNTPOINT}/etc/hosts
  echo -e "::1 localhost.localdomain localhost" >> ${ROOT_MOUNTPOINT}/etc/hosts
  echo -e "127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}" >> ${ROOT_MOUNTPOINT}/etc/hosts & PID=$!; _progress $PID
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
  echo
  arch-chroot ${ROOT_MOUNTPOINT} passwd && PASSWD_CHECK=1;
  while [[ $PASSWD_CHECK == 0 ]]; do
    _print_title "ROOT PASSWORD"
    echo
    _print_warning "The password does not match!"
    echo
    arch-chroot ${ROOT_MOUNTPOINT} passwd && PASSWD_CHECK=1;
  done
  _pause_function
}

_grub_generate() {
  _print_title "BOOTLOADER"
  echo
  _read_input_text "Type a grub name entry:"
  read -r GRUB_NAME
  while [[ "${GRUB_NAME}" == "" ]]; do
    _print_title "BOOTLOADER"
    echo
    _print_warning "You must be type a grub name entry!"
    echo
    _read_input_text "Type a grub name entry:"
    read -r GRUB_NAME
  done
  _print_subtitle "Packages"
  _pacstrap_install "grub grub-btrfs efibootmgr"
  echo
  _read_input_option "Install os-prober? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    echo
    _pacstrap_install "os-prober"
  fi
  _print_subtitle "Grub install"
  arch-chroot ${ROOT_MOUNTPOINT} grub-install --target=x86_64-efi --efi-directory=${EFI_MOUNTPOINT} --bootloader-id=${GRUB_NAME} --recheck
  _print_subtitle "Grub configuration file"
  arch-chroot ${ROOT_MOUNTPOINT} grub-mkconfig -o /boot/grub/grub.cfg
  _pause_function  
}

_finish_install() {
  _print_title "FIRST STEP FINISHED"
  echo
  _print_info "Your new system has been installed! CHECK YOUR CONFIGURATION!"
  echo
  echo -e "${BBLUE}Disk:           ${RESET}${INSTALL_DISK}"
  echo -e "${BBLUE}Root partition: ${RESET}${ROOT_PARTITION}"
  echo -e "${BBLUE}EFI partition:  ${RESET}${EFI_PARTITION}"
  echo -e "${BBLUE}Kernel version: ${RESET}${KERNEL_VERSION}"
  echo -e "${BBLUE}Microcode:      ${RESET}${MICROCODE_VERSION}"
  echo -e "${BBLUE}Timezone:       ${RESET}${ZONE}/${SUBZONE}"
  echo -e "${BBLUE}Hardware Clock: ${RESET}${CLOCK_CHOICE}"
  echo -e "${BBLUE}Language:       ${RESET}${LOCALE}"
  echo -e "${BBLUE}Keymap:         ${RESET}${KEYMAP_CHOICE}"
  echo -e "${BBLUE}Hostname:       ${RESET}${HOSTNAME}"
  echo -e "${BBLUE}Grubname:       ${RESET}${GRUB_NAME}"
  echo
  _read_input_option "Save a copy of this script in root directory? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    echo
    _package_install "wget"
    _print_action "Downloading" "pali.sh"
    wget -O ${ROOT_MOUNTPOINT}/root/ "stenioas.github.io/pali/pali.sh" &> /dev/null & PID=$!; _progress $PID
  fi
  cp /etc/pacman.d/mirrorlist.backup ${ROOT_MOUNTPOINT}/etc/pacman.d/mirrorlist.backup
  echo
  _print_line
  _read_input_option "${BRED}Reboot system now? [y/N]: ${RESET}"
  if [[ $OPTION == y || $OPTION == Y ]]; then
    clear
    reboot
  else
    _print_bye
    exit 0
  fi
}

# --- END INSTALL SECTION --- >

# --- CONFIG SECTION --- >

_create_new_user() {
  _print_title "NEW USER"
  echo
  _read_input_text "Type your username:"
  read -r USERNAME
  while [[ "${USERNAME}" == "" ]]; do
    _print_title "NEW USER"
    echo
    _print_warning "You must be type a username!"
    echo
    _read_input_text "Type your username:"
    read -r USERNAME
  done
  USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')
  if [[ "$(grep ${USERNAME} /etc/passwd)" == "" ]]; then
    echo
    _print_action "Create user" "${USERNAME}"
    useradd -m -g users -G wheel ${USERNAME} & PID=$!; _progress $PID
    sed -i '/%wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers
    echo
    _print_info "Privileges added."
  else
    echo
    _print_info "User ${USERNAME} already exists!"
  fi
  _print_subtitle_select "Type a new user password:"
  PASSWD_CHECK=0
  passwd ${USERNAME} && PASSWD_CHECK=1;
  while [[ $PASSWD_CHECK == 0 ]]; do
    echo
    _print_warning "The password does not match!"
    _print_subtitle_select "Type a new user password:"
    passwd ${USERNAME} && PASSWD_CHECK=1;
  done
  _pause_function
}

_enable_multilib(){
  _print_title "MULTILIB"
  ARCHI=$(uname -m)
  if [[ $ARCHI == x86_64 ]]; then
    local _has_multilib=$(grep -n "\[multilib\]" /etc/pacman.conf | cut -f1 -d:)
    if [[ -z $_has_multilib ]]; then
      echo
      _print_action "Enabling" "Multilib"
      echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf & PID=$!; _progress $PID
    else
      echo
      _print_action "Enabling" "Multilib"
      sed -i "${_has_multilib}s/^#//" /etc/pacman.conf
      local _has_multilib=$(( _has_multilib + 1 ))
      sed -i "${_has_multilib}s/^#//" /etc/pacman.conf & PID=$!; _progress $PID
    fi
  fi
  _print_action "Running" "pacman -Syy"
  pacman -Syy &> /dev/null & PID=$!; _progress $PID
  _pause_function
}

_install_essential_pkgs() {
  _print_title "ESSENTIAL PACKAGES"
  _print_subtitle "Packages"
  _package_install "dosfstools mtools udisks2 dialog wget git nano reflector bash-completion xdg-utils xdg-user-dirs"
  _pause_function
}

_install_xorg() {
  _print_title "XORG"
  _print_subtitle "Packages"
  _group_package_install "xorg"
  _group_package_install "xorg-apps"
  _package_install "xorg-xinit xterm"
  _pause_function
}

_install_vga() {
  _print_title "VIDEO DRIVER"
  VIDEO_CARD_LIST=("Intel" "Virtualbox");
  _print_subtitle_select "Select ${BYELLOW}VIDEO${RESET}${BCYAN} driver:${RESET}"
  select VIDEO_CARD in "${VIDEO_CARD_LIST[@]}"; do
    if _contains_element "${VIDEO_CARD}" "${VIDEO_CARD_LIST[@]}"; then
      break
    else
      _invalid_option
    fi
  done
  if [[ "$VIDEO_CARD" == "Intel" ]]; then
    _print_subtitle "Packages"
    _package_install "xf86-video-intel mesa mesa-libgl libvdpau-va-gl"
  elif [[ "$VIDEO_CARD" == "AMD" ]]; then
    _print_warning "It's not working yet..."
  elif [[ "$VIDEO_CARD" == "Nvidia" ]]; then
    _print_warning "It's not working yet..."
  elif [[ "$VIDEO_CARD" == "Virtualbox" ]]; then
    _print_subtitle "Packages"
    _package_install "xf86-video-vmware virtualbox-guest-utils virtualbox-guest-dkms mesa mesa-libgl libvdpau-va-gl"

  else
    _invalid_option
    exit 0
  fi
  _pause_function
}

_install_desktop() {
  _print_title "DESKTOP OR WINDOW MANAGER"
  DESKTOP_LIST=("Gnome" "Plasma" "Xfce" "i3-gaps" "Bspwm" "Awesome" "Openbox" "Qtile" "None");
  _print_subtitle_select "Select your desktop or wm:"
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
    _print_title "GNOME DESKTOP"
    _print_subtitle "Packages"
    _group_package_install "gnome"
    _group_package_install "gnome-extra"
    _package_install "gnome-tweaks"

  elif [[ "${DESKTOP}" == "Plasma" ]]; then
    _print_title "PLASMA DESKTOP"
    _print_subtitle "Packages"
    _package_install "plasma kde-applications packagekit-qt5"

  elif [[ "${DESKTOP}" == "Xfce" ]]; then
    _print_title "XFCE DESKTOP"
    _print_subtitle "Packages"
    _package_install "xfce4 xfce4-goodies xarchiver network-manager-applet"

  elif [[ "${DESKTOP}" == "i3-gaps" ]]; then
    _print_title "I3-GAPS"
    _print_subtitle "Packages"
    _package_install "i3-gaps i3status i3blocks i3lock dmenu rofi arandr feh nitrogen picom lxappearance xfce4-terminal xarchiver network-manager-applet"

  elif [[ "${DESKTOP}" == "Bspwm" ]]; then
    _print_title "BSPWM"
    _print_subtitle "Packages"
    _print_warning "It's not working yet..."

  elif [[ "${DESKTOP}" == "Awesome" ]]; then
    _print_title "AWESOME WM"
    _print_subtitle "Packages"
    _print_warning "It's not working yet..."

  elif [[ "${DESKTOP}" == "Openbox" ]]; then
    _print_title "OPENBOX"
    _print_subtitle "Packages"
    _package_install "openbox obconf dmenu rofi arandr feh nitrogen picom lxappearance xfce4-terminal xarchiver network-manager-applet"

  elif [[ "${DESKTOP}" == "Qtile" ]]; then
    _print_title "QTILE"
    _print_subtitle "Packages"
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
  DMANAGER_LIST=("Lightdm" "Lxdm" "Slim" "GDM" "SDDM" "Xinit" "None");
  _print_subtitle_select "Select display manager:"
  select DMANAGER in "${DMANAGER_LIST[@]}"; do
    if _contains_element "${DMANAGER}" "${DMANAGER_LIST[@]}"; then
      break
    else
      _invalid_option
    fi
  done
  _print_title "DISPLAY MANAGER"
  DMANAGER_CHOICE=$(echo "${DMANAGER}" | tr '[:lower:]' '[:upper:]')

  if [[ "${DMANAGER}" == "Lightdm" ]]; then
    _print_subtitle "Packages"
    _package_install "lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
    _print_subtitle "Services"
    _print_action "Enabling" "LightDM"
    sudo systemctl enable lightdm &> /dev/null & PID=$!; _progress $PID

  elif [[ "${DMANAGER}" == "Lxdm" ]]; then
    _print_warning "It's not working yet..."

  elif [[ "${DMANAGER}" == "Slim" ]]; then
    _print_warning "It's not working yet..."

  elif [[ "${DMANAGER}" == "GDM" ]]; then
    _print_subtitle "Packages"
    _package_install "gdm"
    _print_subtitle "Services"
    _print_action "Enabling" "GDM"
    sudo systemctl enable gdm &> /dev/null & PID=$!; _progress $PID

  elif [[ "${DMANAGER}" == "SDDM" ]]; then
    _print_subtitle "Packages"
    _package_install "sddm"
    _print_subtitle "Services"
    _print_action "Enabling" "SDDM"
    sudo systemctl enable sddm &> /dev/null & PID=$!; _progress $PID

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

_finish_config() {
  _print_title "SECOND STEP FINISHED"
  echo
  _print_info "Proceed to the last step for install apps. Use ${BYELLOW}-u${RESET} ${BWHITE}option.${RESET}"
  _pause_function
  exit 0
}

# --- END CONFIG SECTION --- >

# --- USER SECTION --- >

_initial_user() {
  _print_title "UPDATE MIRRORS"
  sudo pacman -Syy
  _pause_function
}

_install_extra_pkgs() {
  _print_title "EXTRA PACKAGES"
  _print_subtitle "Utilities"
  _package_install "usbutils lsof dmidecode neofetch bashtop htop avahi nss-mdns logrotate sysfsutils mlocate"
  _print_subtitle "Compression tools"
  _package_install "zip unzip unrar p7zip lzop"
  _print_subtitle "Filesystem tools"
  _package_install "ntfs-3g autofs fuse fuse2 fuse3 fuseiso mtpfs"
  _print_subtitle "Sound tools"
  _package_install "alsa-utils pulseaudio"
  _pause_function
}

_install_laptop_pkgs() {
  _print_title "LAPTOP PACKAGES"
  echo
  _read_input_option "Install laptop packages? [y/N]: "
  if [[ $OPTION == y || $OPTION == Y ]]; then
    _print_subtitle "Packages"
    _package_install "wpa_supplicant wireless_tools bluez bluez-utils pulseaudio-bluetooth xf86-input-synaptics"
    _print_subtitle "Services"
    _print_action "Enabling" "Bluetooth"
    systemctl enable bluetooth &> /dev/null & PID=$!; _progress $PID
    _pause_function
  fi
}

_install_apps() {
  _print_title "CUSTOM APPS"
  echo
  _read_input_option "Install custom apps? [y/N]: "
  echo
  if [[ $OPTION == y || $OPTION == Y ]]; then
    _package_install "libreoffice-fresh libreoffice-fresh-pt-br"
    _package_install "firefox firefox-i18n-pt-br"
    _package_install "steam"
    _package_install "gimp"
    _package_install "inkscape"
    _package_install "vlc"
    _package_install "telegram-desktop"
    if [[ ${DESKTOP} = "Plasma" ]]; then
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
    _pause_function
  fi
}

_install_aurhelper() {
  _print_title "YAY"
  echo
  _read_input_option "Install yay? [y/N]: "
  echo
  if [[ "${OPTION}" == "y" || "${OPTION}" == "Y" ]]; then
    if ! _is_package_installed "yay" ; then
      _print_subtitle "Packages"
      _package_install "base-devel git go"
      sudo pacman -D --asdeps go
      [[ -d yay ]] && rm -rf yay
      git clone https://aur.archlinux.org/yay.git yay
      cd yay
      makepkg -csi --noconfirm
      _pause_function
    else
      _print_info "Yay is already installed!"
      _pause_function
    fi
  fi
}

# --- END USER SECTION --- >

### OTHER FUNCTIONS

_print_line() {
  T_COLS=$(tput cols)
  T_LINES=$(tput lines)
  echo -e "${CYAN}`seq -s '-' $(( T_COLS + 1 )) | tr -d [:digit:]`${RESET}"
}

#_print_title() {
#  clear
#  T_COLS=$(tput cols)
#  T_LINES=$(tput lines)
#  BORDER_COLOR=${BBLACK}
#  T_APP_TITLE=${#APP_TITLE}
#  T_TITLE=${#1}
#  T_LEFT="${BORDER_COLOR}█▓▒░${RESET}${BWHITE}   $1   ${RESET}${BORDER_COLOR}░▒▓${RESET}"
#  T_RIGHT="${BORDER_COLOR}▓▒░${RESET}${BBLACK}   ${APP_TITLE}${RESET}"
#  echo -ne "${T_LEFT}"
#  echo -ne "${BORDER_COLOR}`seq -s '█' $(( T_COLS - T_TITLE - T_APP_TITLE - 19 )) | tr -d [:digit:]`${RESET}"
#  echo -e "${T_RIGHT}"
#}

_print_title() {
  clear
  T_COLS=$(tput cols)
  T_LINES=$(tput lines)
  BORDER_COLOR=${CYAN}
  COLS_APP_VERSION=${#APP_VERSION}
  COLS_APP_TITLE=${#APP_TITLE}
  echo -ne "${BORDER_COLOR}`seq -s '-' $(( T_COLS - COLS_APP_TITLE - COLS_APP_VERSION - 2 )) | tr -d [:digit:]`${RESET}"; echo -e "${BBLACK} ${APP_TITLE} ${APP_VERSION}${RESET}"
  echo -e "${BWHITE} $1${RESET}"
  echo -e "${BORDER_COLOR}`seq -s '=' $(( T_COLS + 1 )) | tr -d [:digit:]`${RESET}"
}

#_print_subtitle() {
#  BORDER_COLOR=${BCYAN}
#  echo -e "\n${BORDER_COLOR}::${RESET}${BCYAN} $1 ${RESET}${BORDER_COLOR}::${RESET}\n"
#}

_print_subtitle() {
  BORDER_COLOR=${BCYAN}
  echo -e "\n${BWHITE}:: $1${RESET}\n"
}

_print_subtitle_select() {
  echo -e "\n${BWHITE}$1${RESET}\n"
}

_print_info() {
  T_COLS=$(tput cols)
  T_LINES=$(tput lines)
  echo -e "${BBLUE}INFO:${RESET}${WHITE} $1${RESET}" | fold -sw $(( T_COLS - 1 ))
}

_print_info() {
  T_COLS=$(tput cols)
  T_LINES=$(tput lines)
  echo -e "${BBLUE}INFO:${RESET}${WHITE} $1${RESET}" | fold -sw $(( T_COLS - 1 ))
}

_print_warning() {
  T_COLS=$(tput cols)
  T_LINES=$(tput lines)
  echo -e "${BYELLOW}WARNING:${RESET}${WHITE} $1${RESET}" | fold -sw $(( T_COLS - 1 ))
}

_print_danger() {
  T_COLS=$(tput cols)
  T_LINES=$(tput lines)
  echo -e "${BRED}DANGER:${RESET}${WHITE} $1${RESET}" | fold -sw $(( T_COLS - 1 ))
}

_print_action() {
  T_COLS=$(tput cols)
  T_LINES=$(tput lines)
  REM_COLS=$(( ${#1} + ${#2} ))
  REM_DOTS=$(( T_COLS - 13 - REM_COLS ))
  echo -ne "${CYAN}$1${RESET}${BWHITE} $2 ${RESET}"
  echo -ne "${BBLACK}`seq -s '.' $(( REM_DOTS )) | tr -d [:digit:]`${RESET}"
  echo -ne "${BBLACK} [        ]${RESET}"
  tput sc
}

_progress() {
  _spinny() {
    echo -ne "\b${BBLUE}${SPIN:i++%${#SPIN}:1}${RESET}"
  }
  while true; do
    kill -0 "$PID" &> /dev/null;
    if [[ $? == 0 ]]; then
      tput rc
      tput cub 5
      _spinny
      sleep 0.2
    else
      wait "$PID"
      RETCODE=$?
      if [[ $RETCODE == 0 ]] || [[ $RETCODE == 255 ]]; then
        tput rc
        tput cub 6
        echo -e "${GREEN}OK${RESET}"
      else
        tput rc
        tput cub 8
        echo -e "${BRED}FAILED${RESET}"
      fi
      break
    fi
  done
}

_print_bye() {
  echo -e "\n${BGREEN}Bye!${RESET}\n"
}

_read_input_text() {
  printf "%s" "${BBLUE}$1 ${RESET}"
}

_read_input_option() {
  printf "%s" "${YELLOW}$1${RESET}"
  read -r OPTION
}

_contains_element() {
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && break; done;
}

_invalid_option() {
  echo
  _print_warning "Invalid option. Try again..."
}

_pause_function() {
  echo
  _print_line
  read -e -sn 1 -p "${WHITE}Press any key to continue...${RESET}"
}

_umount_partitions() {
  echo
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
  for PKG in $1; do
    if ! _is_package_installed "${PKG}"; then
      _print_action "Installing" "${PKG}"
      if [[ $(id -u) == 0 ]]; then
        pacman -S --noconfirm --needed "${PKG}" &> /dev/null & PID=$!; _progress $PID
      else
        sudo pacman -S --noconfirm --needed "${PKG}" &> /dev/null & PID=$!; _progress $PID
      fi
    else
      _print_action "Installing" "${PKG}"
      tput rc
      tput cub 8
      echo -e "${YELLOW}EXISTS${RESET}"
    fi
  done
}

_group_package_install() { # install a package group
  _package_install "$(pacman -Sqg ${1})"
}

_pacstrap_install() { # install pacstrap package
  for PKG in $1; do
    _print_action "Installing" "${PKG}"
    pacstrap "${ROOT_MOUNTPOINT}" "${PKG}" &> /dev/null & PID=$!; _progress $PID
  done
}

_setfont() {
  _print_title "FONT SIZE"
  _print_subtitle_select "Select a console font:"
  FONTS_LIST=("Very small (ter-112n)" "Small (ter-114n)" "Small bold (ter-114b)" "Normal (ter-116n)" "Normal bold (ter-116b)" "Large (ter-118n)" "Large bold (ter-118b)" "Very large (ter-120n)" "Very large bold (ter-120b)" "Unchanged")
  select FONT in "${FONTS_LIST[@]}"; do
    if _contains_element "${FONT}" "${FONTS_LIST[@]}"; then
      FONT="${FONT}"
      break
    else
      _invalid_option
    fi
  done
  if [[ "$FONT" = "Very small (ter-112n)" ]]; then
    setfont ter-112n
  elif [[ "$FONT" = "Small (ter-114n)" ]]; then
    setfont ter-114n
  elif [[ "$FONT" = "Small bold (ter-114b)" ]]; then
    setfont ter-114b
  elif [[ "$FONT" = "Normal (ter-116n)" ]]; then
    setfont ter-116n
  elif [[ "$FONT" = "Normal bold (ter-116b)" ]]; then
    setfont ter-116b
  elif [[ "$FONT" = "Large (ter-118n)" ]]; then
    setfont ter-118n
  elif [[ "$FONT" = "Large bold (ter-118b)" ]]; then
    setfont ter-118b
  elif [[ "$FONT" = "Very large (ter-120n)" ]]; then
    setfont ter-120n
  elif [[ "$FONT" = "Very large bold (ter-120b)" ]]; then
    setfont ter-120b
  fi
}

usage() {
  cat <<EOF

usage: ${0##*/} [flags]

  Flag options:

    --install | -i         First step, only root user.
    --config  | -c         Second step, only root user.
    --user    | -u         Last step, only normal user.

arch-setup 0.1

EOF
}

_start_screen() {
  T_COLS=$(tput cols)
  T_LINES=$(tput lines)
  COLS_LOGO=47
  echo -e "\n\n\n\n\n"
  tput cuf $(( (T_COLS - ${COLS_LOGO})/2 )); echo -e "${BBLACK}┌─────────────────────────────────────────────┐${RESET}"
  tput cuf $(( (T_COLS - ${COLS_LOGO})/2 )); echo -e "${BBLACK}│    ________  ________  ___       ___        │${RESET}"
  tput cuf $(( (T_COLS - ${COLS_LOGO})/2 )); echo -e "${BBLACK}│   |\   __  \|\   __  \|\  \     |\  \       │${RESET}"
  tput cuf $(( (T_COLS - ${COLS_LOGO})/2 )); echo -e "${BBLACK}│   \ \  \|\  \ \  \|\  \ \  \    \ \  \      │${RESET}"
  tput cuf $(( (T_COLS - ${COLS_LOGO})/2 )); echo -e "${BBLACK}│    \ \   ____\ \   __  \ \  \    \ \  \     │${RESET}"
  tput cuf $(( (T_COLS - ${COLS_LOGO})/2 )); echo -e "${BBLACK}│     \ \  \___|\ \  \ \  \ \  \____\ \  \    │${RESET}"
  tput cuf $(( (T_COLS - ${COLS_LOGO})/2 )); echo -e "${BBLACK}│      \ \__\    \ \__\ \__\ \_______\ \__\   │${RESET}"
  tput cuf $(( (T_COLS - ${COLS_LOGO})/2 )); echo -e "${BBLACK}│       \|__|     \|__|\|__|\|_______|\|__|   │${RESET}"
  tput cuf $(( (T_COLS - ${COLS_LOGO})/2 )); echo -e "${BBLACK}│                                             │${RESET}"
  tput cuf $(( (T_COLS - ${COLS_LOGO})/2 )); echo -e "${BBLACK}└─────── ${PURPLE}Personal Arch Linux Installer${RESET}${BBLACK} ───────┘${RESET}"
  echo
  tput cuf $(( (T_COLS - 17)/2 )); echo -e "${BGREEN}By Stenio Silveira${RESET}"
  echo -e "\n\n\n"
  tput cuf $(( (T_COLS - 23)/2 )); read -e -sn 1 -p "${BWHITE}Press any key to start!${RESET}"
  _setfont
}

# ----------------------------------------------------------------------#

### EXECUTION

[[ -z $1 ]] && {
    usage
    exit 1
}
clear
setfont ter-116b
_start_screen
_check_connection

while [[ "$1" ]]; do
  case "$1" in
    --install|-i) _setup_install;;
    --config|-c) _setup_config;;
    --user|-u) _setup_user;;
  esac
  shift
  setfont
  _print_bye && exit 0
done
