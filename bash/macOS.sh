#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

CreateAppIcon() {
  source="$simplifyNext/ic_launcher.png"
  [ ! -f "$source" ] && curl -L --progress-bar -C - -o "$source" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/.res/mipmap-xxxhdpi/ic_launcher.png"  # https://raw.githubusercontent.com/bmax121/APatch/main/app/src/main/ic_launcher-playstore.png
  PointSizeNames=("16x16" "16x16@2x" "32x32" "32x32@2x" "128x128" "128x128@2x" "256x256" "256x256@2x" "512x512" "512x512@2x")
  PixelResolutions=("16" "32" "32" "64" "128" "256" "256" "512" "512" "1024")
  iconset="$simplifyNext/ic_launcher.iconset"
  mkdir -p $iconset
  for ((i=0; i<${#PointSizeNames[@]}; i++)); do
    [ ${PixelResolutions[i]} -eq 1024 ] && cp $source $iconset/icon_${PointSizeNames[i]}.png || sips -z ${PixelResolutions[i]} ${PixelResolutions[i]} $source --out $iconset/icon_${PointSizeNames[i]}.png
  done
  iconutil -c icns $iconset -o $simplifyNext/ic_launcher.icns && rm -rf $iconset
}
CreateScriptLaunchpadShortcuts() {
  shortcutLabel=${1}
  scriptPath=${2}
  Interactive=${3:-true}
  [ ! -f "$simplifyNext/ic_launcher.icns" ] && CreateAppIcon
  mkdir -p "/Applications/${shortcutLabel}.app/Contents/Resources"
  cp "$simplifyNext/ic_launcher.icns" "/Applications/${shortcutLabel}.app/Contents/Resources/ic_launcher.icns"
  mkdir -p "/Applications/${shortcutLabel}.app/Contents/MacOS"
  [ $Interactive == true ] && echo -e "#!/bin/bash\nosascript -e 'tell application \"Terminal\" to do script \"bash ${scriptPath}\"'\nosascript -e 'tell application \"System Events\" to set frontmost of process \"Terminal\" to true'" > "/Applications/${shortcutLabel}.app/Contents/MacOS/launcher" || echo -e "#!/bin/bash\nexport PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"\nsource ${scriptPath}" > "/Applications/${shortcutLabel}.app/Contents/MacOS/launcher"
  chmod +x "/Applications/${shortcutLabel}.app/Contents/MacOS/launcher"
  cat > "/Applications/${shortcutLabel}.app/Contents/Info.plist" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIconFile</key>
    <string>ic_launcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
EOL
  touch /Applications/${shortcutLabel}.app
  killall Dock
}
[ ! -d "/Applications/simplifyx.app/" ] && CreateScriptLaunchpadShortcuts "simplifyx" "$HOME/.simplifyx.sh"

isJdk="openjdk@21"
isAutoUpdatesDependencies=true
if [ -f "$simplifyNextJson" ]; then
  jdk=$(jq -r '.jdk' "$simplifyNextJson" 2>/dev/null)
  AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$simplifyNextJson" 2>/dev/null)
else
  jdk="$isJdk"
  AutoUpdatesDependencies="$isAutoUpdatesDependencies"
fi

formulaeUpdate() {
  formulae=$1
  if echo "$outdatedFormulae" | grep -q "^$formulae" 2>/dev/null; then
    echo -e "$running Upgrading $formulae formulae.."
    brew upgrade "$formulae" > /dev/null 2>&1
  fi
}

formulaeInstall() {
  formulae=$1
  if echo "$formulaeList" | grep -q "$formulae" 2>/dev/null; then
    formulaeUpdate "$formulae"
  else
    echo -e "$running Installing $formulae formulae.."
    brew install "$formulae" > /dev/null 2>&1
  fi
}

formulaeUninstall() {
  formulaeList=$(brew list 2>/dev/null)
  formulae=$1
  if echo "$formulaeList" | grep -q "$formulae" 2>/dev/null; then
    echo -e "$running Uninstalling $formulae formulae.."
    brew uninstall "$formulae" > /dev/null 2>&1
  fi
}

dependencies() {
  formulaeList=$(brew list 2>/dev/null)
  outdatedFormulae=$(brew outdated 2>/dev/null)
  
  brew --version >/dev/null 2>&1 && brew update > /dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  formulaeInstall "bash"
  formulaeInstall "grep"
  curlV=$(curl -V | head -1 | awk '{print $2}')
  if [ $(cut -d. -f1 <<< $curlV) -lt 8 ] || [ $(cut -d. -f2 <<< $curlV) -lt 19 ]; then
    formulaeInstall "curl"
    grep -qF 'export PATH="/usr/local/opt/curl/bin:$PATH"' ~/.zshrc || { echo 'export PATH="/usr/local/opt/curl/bin:$PATH"' >> ~/.zshrc; source ~/.zshrc; }
  fi
  formulaeInstall "aria2"
  formulaeInstall "ca-certificate"
  formulaeInstall "jq"
  formulaeInstall "pv"
  formulaeInstall "pup"
  formulaeInstall "grep"
  formulaeInstall "glow"
  formulaeInstall "android-platform-tools"
  
  formulaeInstall "$jdk"
  if [ "$jdk" == "openjdk@8" ] || [ "$jdk" == "openjdk@11" ] || [ "$jdk" == "openjdk@17" ]; then
    sudo ln -sfn /usr/local/opt/$jdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/$(sed 's|@|-|g' <<< $jdk).jdk
  fi
  grep -q "export PATH=\"/usr/local/opt/$jdk/bin:\$PATH\"" ~/.zshrc 2>/dev/null || echo "export PATH=\"/usr/local/opt/$jdk/bin:\$PATH\"" >> ~/.zshrc
  
  formulaeInstall "android-commandlinetools"
  aapt2=(/usr/local/share/android-commandlinetools/build-tools/*/aapt2) && aapt2="${aapt2[-1]}"
  if [ ! -f $aapt2 ]; then
    yes | /usr/local/bin/sdkmanager --licenses
    /usr/local/bin/sdkmanager $(/usr/local/bin/sdkmanager --list | grep "^  build-tools;" | awk '{print $1}' | tail -1)
  fi

  # https://github.com/aria2/aria2/issues/1920
  aria2c -q -U "User-Agent: $USER_AGENT" --header="Referer: https://one.one.one.one/" --ca-certificate="/etc/ssl/cert.pem" --async-dns=true --async-dns-server="$cloudflareIP" "https://one.one.one.one/" >/dev/null 2>&1
  # https://aria2.github.io/manual/en/html/aria2c.html#exit-status
  if [ $? -eq 28 ]; then
    [ $(uname -m) == "x86_64" ] && Arch=amd64 || Arch=arm64
    curl -L --progress-bar -C - -o $Download/aria2c-macos-$Arch.tar https://github.com/tofuliang/aria2/releases/download/20240919/aria2c-macos-$Arch.tar
    pv "$Download/aria2c-macos-$Arch.tar" | tar -xf - -C "$Download" && rm -f "$Download/aria2c-macos-$Arch.tar"
    sudo mv $Download/aria2c /usr/local/bin/aria2c
    if aria2c -v &>/dev/null; then
      aria2c -v | head -1 | awk '{print $3}'
    else
      sudo xattr -d com.apple.quarantine /usr/local/bin/aria2c && aria2c -v | head -1 | awk '{print $3}'
    fi
  fi
  rm -f index.html
}
[ "$AutoUpdatesDependencies" == true ] && checkInternet && dependencies

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

aapt2=(/usr/local/share/android-commandlinetools/build-tools/*/aapt2) && aapt2="${aapt2[-1]}"
java="/usr/local/opt/$jdk/bin/java"
keytool="/usr/local/opt/$jdk/bin/keytool"