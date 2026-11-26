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

isJdk="openjdk21"
isAutoUpdatesDependencies=true
if [ -f "$simplifyNextJson" ]; then
  jdk=$(jq -r '.jdk' "$simplifyNextJson" 2>/dev/null)
  AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$simplifyNextJson" 2>/dev/null)
else
  jdk="$isJdk"
  AutoUpdatesDependencies="$isAutoUpdatesDependencies"
fi
jv="${jdk#openjdk}"

case "$(sw_vers --productVersion)" in
  27.*) codename="GoldenGate" ;;
  26.*) codename="Tahoe" ;;
  15.*) codename="Sequoia" ;;
  14.*) codename="Sonoma" ;;
  13.*) codename="Ventura" ;;
  12.*) codename="Monterey" ;;
  11.*) codename="BigSur" ;;
  10.15*) codename="Catalina" ;;
  10.14*) codename="Mojave" ;;
  10.13*) codename="HighSierra" ;;
  10.12*) codename="Sierra" ;;
  10.11*) codename="ElCapitan" ;;
  10.10*) codename="Yosemite" ;;
  10.9*) codename="Mavericks" ;;
  10.8*) codename="MountainLion" ;;
  10.7*) codename="Lion" ;;
  10.6*) codename="SnowLeopard" ;;
esac

installPkg() {
  fileName=$(basename $dlUrl)

  echo -e "$running Downloading $fileName from $dlUrl.."
  while true; do
    curl -L --progress-bar -C - -o $HOME/Downloads/$fileName $dlUrl && break || sleep 5
  done

  echo -e "$running Installing $fileName package.."
  sudo installer -pkg ~/Downloads/$fileName -target "/Volumes/Macintosh HD" -allowUntrusted &>/dev/null && { echo "success"; rm -f ~/Downloads/$fileName; } || echo "failure"
}

installPort() {
  ghRespJson=$(curl -sL https://api.github.com/repos/macports/macports-base/releases/latest)
  if jq --version &>/dev/null; then
    dlUrl=$(jq -r --arg ew "-$codename.pkg" '.assets[] | select(.name | endswith($ew)) | .browser_download_url' <<< "$ghRespJson")
  else
    dlUrl=$(grep -o '"browser_download_url": *"[^"]*"' <<< "$ghRespJson" | sed 's/.*"\(https[^"]*\)"/\1/' | grep -- "-${codename}.pkg$")
  fi
  installPkg
}

installBrew() {
  if [ $(uname -m) == "x86_64" ]; then
    dlUrl="https://github.com/Homebrew/brew/releases/download/6.0.22/Homebrew.pkg"; installPkg
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

portUpdate() {
  if grep -q "^$1" <<< "$outdatedPorts"; then
    echo -e "$running Upgrading $1 ports"
    sudo port -N upgrade $1 &>/dev/null
  fi
}

portInstall() {
  if grep -q "$1" <<< "$installedPorts"; then
    portUpdate "$1"
  else
    echo -e "$running Installing $1 ports.."
    sudo port -N install $1 &>/dev/null
  fi
}

portUninstall() {
  installedPorts=$(port installed)
  if grep -q "$1" <<< "$installedPorts"; then
    echo -e "$running Uninstalling $1 ports.."
    sudo port -N uninstall $1
  fi
}

brewUpdate() {
  formulae=$1
  if echo "$outdatedFormulae" | grep -q "^$formulae" 2>/dev/null; then
    echo -e "$running Upgrading $formulae formulae.."
    brew upgrade "$formulae" > /dev/null 2>&1
  fi
}

brewInstall() {
  formulae=$1
  if echo "$formulaeList" | grep -q "$formulae" 2>/dev/null; then
    brewUpdate "$formulae"
  else
    echo -e "$running Installing $formulae formulae.."
    brew install "$formulae" > /dev/null 2>&1
  fi
}

brewUninstall() {
  formulae=$1
  formulaeList=$(brew list 2>/dev/null)
  if echo "$formulaeList" | grep -q "$formulae" 2>/dev/null; then
    echo -e "$running Uninstalling $formulae formulae.."
    brew uninstall "$formulae" > /dev/null 2>&1
  fi
}

pkgUninstall() { grep -qE '^(ca-certificates|android-platform-tools|android-commandlinetools)$' <<< "$1" && brewUninstall "$1" || portUninstall "$1"; }

dependencies() {
  port version &>/dev/null && sudo port selfupdate &>/dev/null || installPort
  installedPorts=$(port installed 2>/dev/null); outdatedPorts=$(port outdated 2>/dev/null)
  brew --version &>/dev/null && brew update &>/dev/null || installBrew
  formulaeList=$(brew list 2>/dev/null); outdatedFormulae=$(brew outdated 2>/dev/null)
  brewInstall "ca-certificates"
  portInstall "bash"
  portInstall "grep"
  curlV=$(curl -V | head -1 | awk '{print $2}')
  if [ $(cut -d. -f1 <<< $curlV) -lt 8 ] || [ $(cut -d. -f2 <<< $curlV) -lt 19 ]; then
    portInstall "curl"
    grep -qF 'export PATH="/opt/local/bin:$PATH"' ~/.zshrc || echo 'export PATH="/opt/local/bin:$PATH"' >> ~/.zshrc
  fi
  portInstall "aria2"
  portInstall "jq"
  portInstall "html2text"
  [ $(uname -m) == "x86_64" ] && portInstall "pv" || pkgInstall "pv"  # brew porvide newer version of pv than port
  portInstall "pup"
  if [ "$(pup --version 2>/dev/null)" != "0.4.0" ]; then
    portInstall "go"
    echo -e "$running Installing pup utility.."
    go install github.com/ericchiang/pup@latest &>/dev/null
    sudo cp ~/go/bin/pup /usr/local/bin/pup
  fi
  portInstall "glow"
  brewInstall "android-platform-tools"
  portInstall "$jdk"
  if [ "$jdk" == "openjdk8" ] || [ "$jdk" == "openjdk11" ] || [ "$jdk" == "openjdk17" ]; then
    grep -qF "export JAVA_HOME=\"/Library/Java/JavaVirtualMachines/$jdk/Contents/Home\"" ~/.zshrc || echo "export JAVA_HOME=\"/Library/Java/JavaVirtualMachines/$jdk/Contents/Home\"" >> ~/.zshrc
  else
    line="export JAVA_HOME=\"$(/usr/libexec/java_home -v $jv)\""; grep -qF "$line" ~/.zshrc 2>/dev/null || echo "$line" >> ~/.zshrc
  fi
  brewInstall "android-commandlinetools"
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
    sudo mv $Download/aria2c /opt/local/bin/aria2c
    if aria2c -v &>/dev/null; then
      aria2c -v | head -1 | awk '{print $3}'
    else
      sudo xattr -d com.apple.quarantine /opt/local/bin/aria2c && aria2c -v | head -1 | awk '{print $3}'
    fi
  fi
  rm -f index.html
}
[ $AutoUpdatesDependencies == true ] && { checkInternet && dependencies; }
/opt/local/bin/curl -V &>/dev/null && export PATH="/opt/local/bin:$PATH"

getSerial

adb -s $serial shell 'su -c "id"' &>/dev/null && su=true || su=false

if [ -n "$serial" ]; then
  Android=$(adb -s $serial shell getprop ro.build.version.release | cut -d. -f1)
  cpuAbi=$(adb -s $serial shell "getprop ro.product.cpu.abi")
  locale=$(adb -s $serial shell getprop persist.sys.locale)  # Get System Locale
  [ -z $locale ] && locale=$(adb -s $serial shell getprop ro.product.locale)  # Get Locale
  lang=$(cut -d'-' -f1 <<< "$locale")  # Extract Language from Locale
  density=$(adb -s $serial shell getprop ro.sf.lcd_density)  # Get the device screen density
fi

aapt2=(/usr/local/share/android-commandlinetools/build-tools/*/aapt2) && aapt2="${aapt2[-1]}"
apksigner=("/usr/local/share/android-commandlinetools/build-tools/"*/apksigner) && apksigner="${apksigner[-1]}"
java="/opt/local/Library/Java/JavaVirtualMachines/jdk-$jv-macports.jdk/Contents/Home/bin/java"
keytool="/opt/local/Library/Java/JavaVirtualMachines/jdk-$jv-macports.jdk/Contents/Home/bin/keytool"