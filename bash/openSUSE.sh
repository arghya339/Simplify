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

pkgUpdate() {
  pkg=${1}
  if grep -q "$pkg" <<< "$pkgUpgradesList" 2>/dev/null; then
    echo -e "$running Upgrading $pkg package.."
    sudo zypper -n update ${pkg} >/dev/null 2>&1
  fi
}

pkgInstall() {
  pkg=${1}
  if grep -q "^$pkg" <<< "$pkgList" 2>/dev/null; then
    pkgUpdate "$pkg"
  else
    echo -e "$running Installing $pkg package.."
    sudo zypper -n install ${pkg} >/dev/null 2>&1
  fi
}

pkgRemove() {
  pkg=${1}
  pkgList=$(rpm -qa)
  if grep -q "^$pkg" <<< "$pkgList" 2>/dev/null; then
    echo -e "$running Uninstalling $pkg package.."
    sudo zypper -n remove ${pkg} >/dev/null 2>&1
  fi
}

dependencies() {
  #pkgList=$(zypper search --installed-only)
  pkgList=$(rpm -qa)
  pkgUpgradesList=$(sudo zypper refresh >/dev/null 2>&1 && sudo zypper list-updates)
  pkgInstall "bash"
  pkgInstall "grep"
  pkgInstall "gawk"
  pkgInstall "sed"
  pkgInstall "findutils"
  pkgInstall "curl"
  pkgInstall "aria2"
  pkgInstall "jq"
  pkgInstall "bsdtar"
  pkgInstall "pv"
  pkgInstall "glow"
  pkgInstall "$jdk"
  sudo update-alternatives --install /usr/bin/java java /usr/lib64/jvm/$jdk-$(cut -d'-' -f2 <<< "$jdk")/bin/java 4000
  pkgInstall "android-tools"
  
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
keytool="/usr/lib64/jvm/$jdk-$(cut -d'-' -f2 <<< "$jdk")/bin/keytool"

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