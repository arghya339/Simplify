#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

isJdk="jdk21-openjdk"
isAutoUpdatesDependencies=true
if [ -f "$simplifyNextJson" ]; then
  jdk=$(jq -r '.jdk' "$simplifyNextJson" 2>/dev/null)
  AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$simplifyNextJson" 2>/dev/null)
else
  jdk="$isJdk"
  AutoUpdatesDependencies="$isAutoUpdatesDependencies"
fi

pacUpdate() {
  pac=${1}
  if grep -q "^$pac" <<< "$pacUpgradesList" 2>/dev/null; then
    echo -e "$running Upgrading $pac package.."
    sudo pacman -S ${pac} --noconfirm >/dev/null 2>&1
  fi
}

pacInstall() {
  pac=${1}
  if grep -q "^$pac" <<< "$pacList" 2>/dev/null; then
    pacUpdate "$pac"
  else
    echo -e "$running Installing $pac package.."
    sudo pacman -S ${pac} --noconfirm >/dev/null 2>&1
  fi
}

pacRemove() {
  pac=${1}
  pacList=$(pacman -Q 2>/dev/null)
  if grep -q "^$pac" <<< "$pacList" 2>/dev/null; then
    echo -e "$running Uninstalling $pac package.."
    sudo pacman -R ${pac} --noconfirm >/dev/null 2>&1
  fi
}

dependencies() {
  pacList=$(pacman -Q 2>/dev/null)
  pacUpgradesList=$(sudo pacman -Sy 2>/dev/null && pacman -Qu 2>/dev/null)
  pacInstall "bash"
  pacInstall "grep"
  pacInstall "gawk"
  pacInstall "sed"
  pacInstall "findutils"
  pacInstall "curl"
  pacInstall "aria2"
  pacInstall "jq"
  pacInstall "glow"
  pacInstall "tar"
  pacInstall "pv"
  pacInstall "$jdk"
  pacInstall "android-tools"
  if ! yay -V >/dev/null 2>&1; then
    pacInstall "base-devel"
    pacInstall "git"
    git clone https://aur.archlinux.org/yay.git
    ( cd yay && makepkg -si )
    rm -rf yay
  fi
  aapt2 version >/dev/null 2>&1 || yay -S android-sdk-build-tools --noconfirm
  if ! pup --version >/dev/null 2>&1; then
    curl -L --progress-bar -C - -o "$HOME/Downloads/pup_v0.4.0_linux_amd64.zip" "https://github.com/ericchiang/pup/releases/download/v0.4.0/pup_v0.4.0_linux_amd64.zip"
    pv "$HOME/Downloads/pup_v0.4.0_linux_amd64.zip" | sudo bsdtar -xf - -C "/usr/local/bin"
    [ -x "/usr/local/bin/pup" ] || sudo chmod +x /usr/local/bin/pup
    rm -f "$HOME/Downloads/pup_v0.4.0_linux_amd64.zip"
  fi
}
[ "$AutoUpdatesDependencies" == true ] && checkInternet && dependencies

aapt2="/usr/bin/aapt"
java="/usr/bin/java"
keytool="/usr/bin/keytool"

getSerial() {
  deviceCount=$(adb devices | grep -c "device$")
  if [ $deviceCount -eq 0 ]; then
    serial=
  elif [ $deviceCount -eq 1 ]; then
    serial=$(adb devices | grep "device$" | awk '{print $1}')
  else
    serials=($(adb devices | grep "device$" | awk '{print $1}'))
    models=()
    for i in "${!serials[@]}"; do
      serial="${serials[i]}"
      models+=("$(adb -s $serial shell getprop ro.product.model)")
    done
    if menu models bButtons serials; then
      serial="${serials[selected]}"
    fi
  fi
  [ -n "$serial" ] && echo -e "$info serial: $serial"
}; getSerial

adb -s $serial shell 'su -c "id"' &>/dev/null && su=true || su=false

if [ -n "$serial" ]; then
  Android=$(adb -s $serial shell getprop ro.build.version.release | cut -d. -f1)
  cpuAbi=$(adb -s $serial shell "getprop ro.product.cpu.abi")
  locale=$(adb -s $serial shell getprop persist.sys.locale | cut -d'-' -f1)  # Get System Languages
  [ -z $locale ] && locale=$(adb -s $serial shell getprop ro.product.locale | cut -d'-' -f1)  # Get Languages
  density=$(adb -s $serial shell getprop ro.sf.lcd_density)  # Get the device screen density
fi