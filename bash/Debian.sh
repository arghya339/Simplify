#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

isJdk="openjdk-21-jdk"
isAutoUpdatesDependencies=true
if [ -f "$simplifyNextJson" ]; then
  jdk=$(jq -r '.jdk' "$simplifyNextJson" 2>/dev/null)
  AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$simplifyNextJson" 2>/dev/null)
else
  jdk="$isJdk"
  AutoUpdatesDependencies="$isAutoUpdatesDependencies"
fi

aptUpdate() {
  apt=${1}
  if grep -q "^$apt" <<< "$aptUpgradesList" 2>/dev/null; then
    echo -e "$running Upgrading $apt package.."
    sudo apt update ${apt} -y >/dev/null 2>&1
  fi
}

aptInstall() {
  apt=${1}
  if grep -q "^$apt" <<< "$aptList" 2>/dev/null; then
    aptUpdate "$apt"
  else
    echo -e "$running Installing $apt package.."
    sudo apt install ${apt} -y >/dev/null 2>&1
  fi
}

aptRemove() {
  apt=${1}
  aptList=$(apt list --installed 2>/dev/null)
  if grep -q "^$apt" <<< "$aptList" 2>/dev/null; then
    echo -e "$running Uninstalling $apt package.."
    sudo apt remove ${apt} -y >/dev/null 2>&1
  fi
}

dependencies() {
  #sudo -i "id" >/dev/null 2>&1
  aptList=$(apt list --installed 2>/dev/null)
  aptUpgradesList=$(sudo apt update 2>/dev/null && apt list --upgradable 2>/dev/null)
  aptInstall "dpkg"
  aptInstall "bash"
  aptInstall "grep"
  aptInstall "gawk"
  aptInstall "sed"
  aptInstall "findutils"
  aptInstall "curl"
  aptInstall "aria2"
  aptInstall "jq"
  aptInstall "libarchive-tools"
  aptInstall "pv"
  if grep -qi "netrunner" /etc/os-release 2>/dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    curl -sL https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" | sudo tee /etc/apt/sources.list.d/adoptium.list
    sudo apt update && sudo apt install temurin-21-jdk -y
  else
    aptInstall "$jdk"
  fi
  aptInstall "adb"
  aptInstall "aapt"
  if ! glow -v >/dev/null 2>&1; then
    if grep -qi "linuxmint" /etc/os-release 2>/dev/null || grep -qi "netrunner" /etc/os-release 2>/dev/null; then
      sudo mkdir -p /etc/apt/keyrings
      curl -sL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
      sudo apt update && sudo apt install glow -y
    elif grep -qi "ubuntu" /etc/os-release 2>/dev/null || grep -qi "zorin" /etc/os-release 2>/dev/null; then
      sudo snap install glow
    else
      aptInstall "glow"
    fi
  fi
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