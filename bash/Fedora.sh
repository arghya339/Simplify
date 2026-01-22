#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

isJdk="java-21-openjdk"
isAutoUpdatesDependencies=true
if [ -f "$simplifyNextJson" ]; then
  jdk=$(jq -r '.jdk' "$simplifyNextJson" 2>/dev/null)
  AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$simplifyNextJson" 2>/dev/null)
else
  jdk="$isJdk"
  AutoUpdatesDependencies="$isAutoUpdatesDependencies"
fi

dnfUpdate() {
  dnf=${1}
  if grep -q "^$dnf" <<< "$dnfUpgradesList" 2>/dev/null; then
    echo -e "$running Upgrading $dnf package.."
    sudo dnf update "$dnf" -y >/dev/null 2>&1
  fi
}

dnfInstall() {
  dnf=${1}
  if grep -q "^$dnf" <<< "$dnfList" 2>/dev/null; then
    dnfUpdate "$dnf"
  else
    echo -e "$running Installing $dnf package.."
    sudo dnf install "$dnf" -y >/dev/null 2>&1
  fi
}

dnfRemove() {
  dnf=${1}
  dnfList=$(dnf list --installed 2>/dev/null)
  if grep -q "^$dnf" <<< "$dnfList" 2>/dev/null; then
    echo -e "$running Uninstalling $dnf package.."
    sudo dnf remove "$dnf" -y >/dev/null 2>&1
  fi
}

dependencies() {
  dnfList=$(dnf list --installed 2>/dev/null)
  dnfUpgradesList=$(dnf --refresh list --upgrades 2>/dev/null)
  dnfInstall "bash"
  dnfInstall "grep"
  dnfInstall "gawk"
  dnfInstall "sed"
  dnfInstall "findutils"
  dnfInstall "curl"
  dnfInstall "aria2"
  dnfInstall "jq"
  dnfInstall "bsdtar"
  dnfInstall "pv"
  dnfInstall "glow"
  dnfInstall "$jdk"
  sudo alternatives --set java /usr/lib/jvm/$jdk/bin/java
  dnfInstall "android-tools"  # (adb, fastboot)
  
  if [ ! -f "$HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager" ]; then
    cmdlinetoolslatest=$(curl -sL https://developer.android.com/studio | grep -o "https://dl.google.com/android/repository/commandlinetools-linux-[0-9]*_latest.zip" | head -1 | awk -F'[-_]' '{print $3}')
    curl -L --progress-bar -C - -o "$HOME/Downloads/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip" "https://dl.google.com/android/repository/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip"
    mkdir -p ~/Android/Sdk/cmdline-tools/latest
    pv "$HOME/Downloads/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip" | bsdtar -xf - -C "$HOME/Android/Sdk/cmdline-tools/latest" --strip-components 1
    rm -f "$HOME/Downloads/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip"
    chmod +x ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager
    ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --version
    yes | ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --licenses
    ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager $($HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --list | grep "^  build-tools;" | awk '{print $1}' | tail -1)
    grep -qxF 'export PATH="$HOME/Android/Sdk/build-tools/$(ls $HOME/Android/Sdk/build-tools | sort -V | tail -1):$PATH"' ~/.android-env || echo 'export PATH="$HOME/Android/Sdk/build-tools/$(ls $HOME/Android/Sdk/build-tools | sort -V | tail -1):$PATH"' >> ~/.android-env && source ~/.android-env
  fi

  if ! pup --version >/dev/null 2>&1; then
    curl -L --progress-bar -C - -o "$HOME/Downloads/pup_v0.4.0_linux_amd64.zip" "https://github.com/ericchiang/pup/releases/download/v0.4.0/pup_v0.4.0_linux_amd64.zip"
    pv "$HOME/Downloads/pup_v0.4.0_linux_amd64.zip" | sudo bsdtar -xf - -C "/usr/local/bin"
    [ -x "/usr/local/bin/pup" ] || sudo chmod +x /usr/local/bin/pup
    rm -f "$HOME/Downloads/pup_v0.4.0_linux_amd64.zip"
  fi
}
[ "$AutoUpdatesDependencies" == true ] && checkInternet && dependencies

aapt2=("$HOME/Android/Sdk/build-tools/"*/aapt2) && aapt2="${aapt2[-1]}"
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