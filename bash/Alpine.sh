#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

isJdk="openjdk21-jdk"
isAutoUpdatesDependencies=true
if [ -f "$simplifyNextJson" ]; then
  jdk=$(jq -r '.jdk' "$simplifyNextJson" 2>/dev/null)
  AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$simplifyNextJson" 2>/dev/null)
else
  jdk="$isJdk"
  AutoUpdatesDependencies="$isAutoUpdatesDependencies"
fi

apkUpgrade() {
  apk=${1}
  if grep -q "^$apk" <<< "$apkUpgradesList" 2>/dev/null; then
    echo -e "$running Upgrading $apk package.."
    sudo apk upgrade "$apk" >/dev/null 2>&1
  fi
}

apkAdd() {
  apk=${1}
  if grep -q "^$apk" <<< "$apkInfo" 2>/dev/null; then
    apkUpgrade "$apk"
  else
    echo -e "$running Installing $apk package.."
    sudo apk add "$apk" >/dev/null 2>&1
  fi
}

apkDel() {
  apk=${1}
  apkInfo=$(apk info 2>/dev/null)
  if grep -q "^$apk" <<< "$apkInfo" 2>/dev/null; then
    echo -e "$running Uninstalling $apk package.."
    sudo apk del "$apk" >/dev/null 2>&1
  fi
}

dependencies() {
  apkInfo=$(apk info 2>/dev/null)
  apkUpgradesList=$(sudo apk update && apk list -u 2>/dev/null)
  bash --version &>/dev/null || su -c "apk add bash" &>/dev/null
  apkAdd "bash"  # install
  apkAdd "busybox"  # upgrade
  #apkAdd "grep"  # part of busybox: apk info --who-owns $(which grep)
  #apkAdd "gawk"  # gnu awk installation not required, becouse awk comes with busybox
  #apkAdd "sed"  # comes with busybox
  #apkAdd "findutils" # gnu findutils not needed due to busybox provide find: apk info --who-owns $(which find)
  apkAdd "curl"  # install
  apkAdd "aria2"  # install
  apkAdd "jq"  # install
  apkAdd "pup"  # install
  apkAdd "libarchive-tools"  # install
  apkAdd "pv"  # install
  grep -qxF "http://dl-cdn.alpinelinux.org/alpine/edge/testing" /etc/apk/repositories || echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" | sudo tee -a /etc/apk/repositories &>/dev/null && sudo apk update &>/dev/null
  apkAdd "glow"  # install
  apkAdd "$jdk"  # install
  apkAdd "android-tools"  # (adb, fastboot)
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
  apkAdd "gcompat"  # install
  apkAdd "xdg-utils"  # install
  apkAdd "util-linux"  # install
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