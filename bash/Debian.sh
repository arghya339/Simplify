#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

CreateBinaryLauncherShortcuts() {
  shortcutLabel=${1}
  iconPath=${2}
  binaryPath=${3}
  Interactive=${4:-true}
  PolicyKit=${5:-false}
  Categories=${6:-Utility}
  [ $PolicyKit == true ] && polkit="pkexec " || polkit=""
  cat > "$HOME/.local/share/applications/${shortcutLabel}.desktop" <<EOL
[Desktop Entry]
Name=${shortcutLabel}
Icon=${iconPath}
Exec=${polkit}${binaryPath}
Terminal=${Interactive}
Type=Application
Categories=${Categories};
EOL
}
[ ! -f "$simplifyNext/ic_launcher.png" ] && curl -L --progress-bar -C - -o "$simplifyNext/ic_launcher.png" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/.res/mipmap-xxxhdpi/ic_launcher.png"  # https://raw.githubusercontent.com/bmax121/APatch/main/app/src/main/ic_launcher-playstore.png
[ ! -f "$HOME/.local/share/applications/simplifyx.desktop" ] && CreateBinaryLauncherShortcuts "simplifyx" "$simplifyNext/ic_launcher.png" "$HOME/.simplifyx.sh"

isJdk="openjdk-21-jdk"
isAutoUpdatesDependencies=true
if [ -f "$simplifyNextJson" ]; then
  jdk=$(jq -r '.jdk' "$simplifyNextJson" 2>/dev/null)
  AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$simplifyNextJson" 2>/dev/null)
else
  jdk="$isJdk"
  AutoUpdatesDependencies="$isAutoUpdatesDependencies"
fi

pkgUpdate() {
  apt=${1}
  if grep -q "^$apt" <<< "$aptUpgradesList" 2>/dev/null; then
    echo -e "$running Upgrading $apt package.."
    sudo apt update ${apt} -y >/dev/null 2>&1
  fi
}

pkgInstall() {
  apt=${1}
  if grep -q "^$apt" <<< "$aptList" 2>/dev/null; then
    pkgUpdate "$apt"
  else
    echo -e "$running Installing $apt package.."
    sudo apt install ${apt} -y >/dev/null 2>&1
  fi
}

pkgUninstall() {
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
  pkgInstall "dpkg"
  pkgInstall "bash"
  pkgInstall "grep"
  pkgInstall "gawk"
  pkgInstall "sed"
  pkgInstall "findutils"
  pkgInstall "curl"
  curlV=$(curl -V | head -1 | awk '{print $2}')
  if [ $(cut -d. -f1 <<< $curlV) -lt 8 ] || [ $(cut -d. -f2 <<< $curlV) -lt 19 ]; then
    snap version &>/dev/null || sudo apt install snapd -y
    sudo snap install curl
    if [ "$(basename $SHELL)" == "zsh" ]; then
      grep -qF 'export PATH="/snap/bin:$PATH"' ~/.zshrc || { echo 'export PATH="/snap/bin:$PATH"' >> ~/.zshrc; source ~/.zshrc; }
    else
      grep -qF 'export PATH="/snap/bin:$PATH"' ~/.bashrc || { echo 'export PATH="/snap/bin:$PATH"' >> ~/.bashrc; source ~/.bashrc; }
    fi
    curl.snap-acked >/dev/null
  fi
  pkgInstall "aria2"
  pkgInstall "jq"
  pkgInstall "html2text"
  pkgInstall "libarchive-tools"
  pkgInstall "pv"
  if grep -qi "netrunner" /etc/os-release 2>/dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    curl -sL https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" | sudo tee /etc/apt/sources.list.d/adoptium.list
    sudo apt update && sudo apt install temurin-21-jdk -y
  else
    pkgInstall "$jdk"
  fi
  pkgInstall "adb"
  pkgInstall "aapt"
  if ! glow -v >/dev/null 2>&1; then
    if grep -qi "linuxmint" /etc/os-release 2>/dev/null || grep -qi "pop" /etc/os-release 2>/dev/null || grep -qi "netrunner" /etc/os-release 2>/dev/null; then
      sudo mkdir -p /etc/apt/keyrings
      curl -sL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
      sudo apt update && sudo apt install glow -y
    elif grep -qi "ubuntu" /etc/os-release 2>/dev/null || grep -qi "zorin" /etc/os-release 2>/dev/null; then
      sudo snap install glow
    else
      pkgInstall "glow"
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
  locale=$(adb -s $serial shell getprop persist.sys.locale)  # Get System Locale
  [ -z $locale ] && locale=$(adb -s $serial shell getprop ro.product.locale)  # Get Locale
  lang=$(cut -d'-' -f1 <<< "$locale")  # Extract Language from Locale
  density=$(adb -s $serial shell getprop ro.sf.lcd_density)  # Get the device screen density
fi