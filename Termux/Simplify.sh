#!/usr/bin/bash

# --- Downloading latest Simplify.sh file from GitHub ---
curl -fsSL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/Simplify.sh"

# Check if symlink doesn't already exist
if [ ! -f "$PREFIX/bin/simplify" ]; then
  ln -s "$HOME/.Simplify.sh" "$PREFIX/bin/simplify"  # symlink (shortcut of Simplify.sh)
fi
chmod +x "$HOME/.Simplify.sh"  # give execute permission to the Simplify.sh

# Colored log indicators
good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

<<comment
# --- dash supports ANSI escape codes for terminal text formatting ---
Color Forground_Color_Code Background_Color_Code
Black 30 40
Red 31 41
Green 32 42
Yellow 33 43
Blue 34 44
Magenta 35 45
Cyan 36 46
White 37 47

Gray_Background_Code 48
Default_background_Code 49

Color Bright_Color_Code
Bright-Black(Gray) 90
Bright-Red 91
Bright-Green 92
Bright-Yellow 93
Bright-Blue 94
Bright-Magenta 95
Bright-Cyan 96
Bright-White 97

Text_Format Code
Reset 0
Bold 1
Dim 2
Italic 3
Underline 4
Bold 5
Less Bold 6
Text with Background 7
invisible 8
Strikethrough 9

Examples
echo -e "\e[32mThis is green text\e[0m"
echo -e "\e[47mThis is a white background\e[0m"
echo -e "\e[32;47mThis is green text on white background\e[0m"
echo -e "\e[1;32;47mThis is bold green text on white background\e[0m"
comment

# ANSI color code
Green="\033[92m"
BoldGreen="\033[92;1m"
Red="\033[91m"
Blue="\033[94m"
White="\033[37m"
Yellow="\033[93m"
Reset="\033[0m"

# Construct the simplify shape using string concatenation
print_simplify=$(cat <<'EOF'
    https://github.com/arghya339/Simplify
      .------------------------------.
      | ▄▀▀ █ █▄ ▄█ █▀▄ █   █ █▀ ▀▄▀ |
      | ▄██ █ █ ▀ █ █▀  █▄▄ █ █▀  █  |
      |      >_𝒟𝑒𝓋𝑒𝓁𝑜𝓅𝑒𝓇: @𝒶𝓇𝑔𝒽𝓎𝒶𝟥𝟥𝟫 |
      '------------------------------'
EOF
)

<<comment
# Construct the simplify shape using string concatenation
print_simplify=$(cat <<'EOF'
   https://github.com/arghya339/Simplify\n       ▄▀▀ █ █▄ ▄█ █▀▄ █   █ █▀ ▀▄▀\n       ▄██ █ █ ▀ █ █▀  █▄▄ █ █▀  █\n            >_𝒟𝑒𝓋𝑒𝓁𝑜𝓅𝑒𝓇: @𝒶𝓇𝑔𝒽𝓎𝒶𝟥𝟥𝟫
EOF
)
comment

Android=$(getprop ro.build.version.release | cut -d. -f1)  # Get major Android version

# --- Storage Permission Check Logic ---
if ! ls /sdcard/ 2>/dev/null | grep -E -q "^(Android|Download)"; then
  echo -e "${notice} ${Yellow}Storage permission not granted!${Reset}\n$running ${Green}termux-setup-storage${Reset}.."
  if [ "$Android" -gt 5 ]; then  # for Android 5 storage permissions grant during app installation time, so Termux API termux-setup-storage command not required
    count=0
    while true; do
      if [ "$count" -ge 2 ]; then
        echo -e "$bad Failed to get storage permissions after $count attempts!"
        echo -e "$notice Please grant permissions manually in Termux App info > Permissions > Files > File permission → Allow."
        am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.termux &> /dev/null
        exit 0
      fi
      termux-setup-storage  # ask Termux Storage permissions
      sleep 3  # wait 3 seconds
      if ls /sdcard/ 2>/dev/null | grep -q "^Android" || ls "$HOME/storage/shared/" 2>/dev/null | grep -q "^Android"; then
        if [ "$Android" -lt 8 ]; then
          exit 0  # Exit the script
        fi
        break
      fi
      ((count++))
    done
  fi
fi

# --- enabled allow-external-apps ---
isOverwriteTermuxProp=0
if [ "$Android" -eq 6 ] && [ ! -f "$HOME/.termux/termux.properties" ]; then
  mkdir -p "$HOME/.termux" && echo "allow-external-apps = true" > "$HOME/.termux/termux.properties"
  isOverwriteTermuxProp=1
  echo -e "$notice 'termux.properties' file has been created successfully & 'allow-external-apps = true' line has been add (enabled) in Termux \$HOME/.termux/termux.properties."
  termux-reload-settings
fi
if [ "$Android" -ge 6 ]; then
  if grep -q "^# allow-external-apps" "$HOME/.termux/termux.properties"; then
    # other Android applications can send commands into Termux.
    # termux-open utility can send an Android Intent from Termux to Android system to open apk package file in pm.
    # other Android applications also can be Access Termux app data (files).
    sed -i '/allow-external-apps/s/# //' "$HOME/.termux/termux.properties"  # uncomment 'allow-external-apps = true' line
    isOverwriteTermuxProp=1
    echo -e "$notice 'allow-external-apps = true' line has been uncommented (enabled) in Termux \$HOME/.termux/termux.properties."
    if [ "$Android" -eq 7 ] || [ "$Android" -eq 6 ]; then
      termux-reload-settings  # reload (restart) Termux settings required for Android 6 after enabled allow-external-apps, also required for Android 7 due to 'Package installer has stopped' err
    fi
  fi
fi

# --- Checking Internet Connection ---
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 ; then
  echo -e "${bad} ${Red}Oops! No Internet Connection available.\nConnect to the Internet and try again later."
  exit 1
fi

# --- Global Variables ---
cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
serial=$(su -c 'getprop ro.serialno')  # Get Serial Number required root
model=$(getprop ro.product.model)  # Get Device Model
pkg update > /dev/null 2>&1 || apt update >/dev/null 2>&1  # It downloads latest package list with versions from Termux remote repository, then compares them to local (installed) pkg versions, and shows a list of what can be upgraded if they are different.
outdatedPKG=$(apt list --upgradable 2>/dev/null)  # list of outdated pkg
if [ -z "$(head -2 <<< "$outdatedPkg" | tail -1)" ]; then
  # If package installation was interrupted (lost connection, app force closed, etc.)
  # This command configures unpacked but unconfigured packages by creating symlinks, running post-install scripts, and setting up configuration files
  pkill apt && yes "N" | dpkg --configure -a; pkill apt  # The 'yes "N"' command continuously outputs "N" followed by newline (Enter). The pipe (|) feeds this output as automatic input to any prompts from dpkg
fi
installedPKG=$(pkg list-installed 2>/dev/null)  # list of installed pkg
jdkVersion="21"
SimplUsr="/sdcard/Simplify"
Simplify="$HOME/Simplify"
RV="$Simplify/RV"
RVX="$Simplify/RVX"
pikoTwitter="$Simplify/pikoTwitter"
Dropped="$Simplify/Dropped"
LSPatch="$Simplify/LSPatch"
POST_INSTALL="$Simplify/POST_INSTALL"
mkdir -p "$Simplify" "$RV" "$RVX" "$pikoTwitter" "$Dropped" "$LSPatch" "$SimplUsr" "$POST_INSTALL"
Download="/sdcard/Download"
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
isPreRelease=0  # Default value (false/off/0) for isPreRelease, it's enabled latest release for Patches source
isRipLocale=1  # Default value (true/on/1) for RipLocale, it's delete locale from patched apk file except device specific locale by default
isRipDpi=1  # Default value (true/on/1) for RipDpi, it's delete dpi from patched apk file except device specific dpi by default
isRipLib=1  # Default value (true/on/1) for RipLib, it's delete lib dir from patched apk file except device specific arch lib by default
isChangeRVXSource=0  # Default value (false/off/0) for ChangeRVXSource, means patches source remain unchange ie. official source (inotia00) for RVX Patches
isReadPatchesFile=0  # Default value (false/off/0) for ReadPatchesFile, means recommended PatchesOptions loading from script.
branding="google_family"
isCheckTermuxUpdate=1
CheckTermuxUpdate=$(jq -r '.CheckTermuxUpdate' "$simplifyJson" 2>/dev/null)  # Get CheckTermuxUpdate value from json
isJdkVersion=21
jdkVersion=$(jq -r '.openjdk' "$simplifyJson" 2>/dev/null)
isU=0  # Install Package for 0 (default-user), possible 1 (all-users)
isK=0  # Allow Downgrade with keeps App data 0 (false) because it's required reboot after pkg install, possible 1 (true)
isG=0  # Grant All Runtime Permissions 0 (false) due to Security Risk, possible 1
isT=0  # Installed as test-only app 0, possible 1
isL=1  # Bypass Low Target SDK Bolck 1 (true) it's allow Android 14+ to install apps that target below API level 23 (Android 6 and below), possible value 0
isV=1  # Disable Play Protect Package Verification 1 (true), possible 0
isI="com.android.vending"  # default: PlayStore | possible Installer: com.android.packageinstaller (PackageInstaller), com.android.shell (Shell), adb
isR=1  # Reinstall Existing Installed Package 1 (true) because without this app can't be installed if installed and to-be-installed version are same, possible 0
isB=0  # Enable Version Roolback 0, possible 1

# --- pkg uninstall function ---
pkgUninstall() {
  local pkg=$1
  if echo "$installedPKG" | grep -q "^$pkg/" 2>/dev/null; then
    echo -e "$running Uninstalling $pkg pkg.."
    pkg uninstall "$pkg" -y > /dev/null 2>&1
  fi
}

# --- pkg upgrade function ---
pkgUpdate() {
  local pkg=$1
  if echo "$outdatedPKG" | grep -q "^$pkg/" 2>/dev/null; then
    echo -e "$running Upgrading $pkg pkg.."
    pkg reinstall "$pkg" -y > /dev/null 2>&1
  fi
}

# --- pkg install/update function ---
pkgInstall() {
  local pkg=$1
  if echo "$installedPKG" | grep -q "^$pkg/" 2>/dev/null; then
    pkgUpdate "$pkg"
  else
    echo -e "$running Installing $pkg pkg.."
    pkg install "$pkg" -y > /dev/null 2>&1
  fi
}

pkgInstall "apt"  # apt update
pkgInstall "dpkg"  # dpkg update
pkgInstall "bash"  # bash update
pkgInstall "termux-core"  # it's contains basic essential cli utilities, such as: ls, cp, mv, rm, mkdir, cat, echo, etc.
pkgInstall "termux-tools"  # it's provide essential commands, sush as: termux-change-repo, termux-setup-storage, termux-open, termux-share, etc.
pkgInstall "termux-keyring"  # it's use during pkg install/update to verify digital signature of the pkg and remote repository
pkgInstall "termux-am"  # termux am (activity manager) update
pkgInstall "termux-am-socket"  # termux am socket (when run: am start -n activity ,termux-am take & send to termux-am-stcket and it's send to Termux Core to execute am command) update
pkgInstall "curl"  # curl update
pkgInstall "libcurl"  # curl lib update
pkgInstall "aria2"  # aria2 install/update
pkgInstall "jq"  # jq install/update
pkgInstall "pup"  # pup install/update
if [ -f "$simplifyJson" ]; then
  pkgInstall "openjdk-$jdkVersion"  # java install/update
else
  pkgInstall "openjdk-$isJdkVersion"  # java install/update
fi
pkgInstall "apksigner"  # apksigner install/update
pkgInstall "bsdtar"  # bsdtar install/update
pkgInstall "pv"  # pv install/update
pkgInstall "grep"  # grep update
pkgInstall "gawk"  # gnu awk update
pkgInstall "sed"  # sed update
pkgInstall "findutils"  # find utils update
pkgInstall "glow"  # glow install/update

# --- Shizuku Setup first time ---
if ! su -c "id" >/dev/null 2>&1 && { [ ! -f "$HOME/rish" ] || [ ! -f "$HOME/rish_shizuku.dex" ]; }; then
  #echo -e "$info Please manually install Shizuku from Google Play Store." && sleep 1
  #termux-open-url "https://play.google.com/store/apps/details?id=moe.shizuku.privileged.api"
  echo -e "$info Please manually install Shizuku from GitHub." && sleep 1
  termux-open-url "https://github.com/RikkaApps/Shizuku/releases/latest"
  am start -n com.android.settings/.Settings\$MyDeviceInfoActivity > /dev/null 2>&1  # Open Device Info

  curl -sL -o "$HOME/rish" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Termux/Shizuku/rish" && chmod +x "$HOME/rish"
  sleep 0.5 && curl -sL -o "$HOME/rish_shizuku.dex" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Termux/Shizuku/rish_shizuku.dex"
  
  if [ "$Android" -lt 11 ]; then
    url="https://youtu.be/ZxjelegpTLA"  # YouTube/@MrPalash360: Start Shizuku using Computer
    activityClass="com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity"  # Open Developer options
  else
    activityClass="com.android.settings/.Settings\$WirelessDebuggingActivity"  # Open Wireless Debugging Settings
    url="https://youtu.be/YRd0FBfdntQ"  # YouTube/@MrPalash360: Start Shizuku Android 11+
  fi
  echo -e "$info Please start Shizuku by following guide: $url" && sleep 1
  am start -n "$activityClass" > /dev/null 2>&1
  termux-open-url "$url"
fi
if ! "$HOME/rish" -c "id" >/dev/null 2>&1 && [ -f "$HOME/rish_shizuku.dex" ]; then
  if ~/rish -c "id" 2>&1 | grep -q 'java.lang.UnsatisfiedLinkError'; then
    rm -f "$HOME/rish_shizuku.dex" && curl -sL -o "$HOME/rish_shizuku.dex" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Termux/Shizuku/Play/rish_shizuku.dex"
  fi
fi

if [ "$(getprop ro.product.manufacturer)" == "Genymobile" ] && [ ! -f "$HOME/adb" ]; then
  curl -sL -o "$HOME/adb" "https://raw.githubusercontent.com/rendiix/termux-adb-fastboot/refs/heads/master/binary/${cpuAbi}/bin/adb" && chmod +x ~/adb
fi

if su -c "id" >/dev/null 2>&1 || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $(~/adb devices | grep "emulator-*" | cut -f1) shell "id" >/dev/null 2>&1; then
  if [ -n "$(find $POST_INSTALL -mindepth 1 -type f -o -type d -o -type l 2>/dev/null)" ]; then
    file_path=$(find $POST_INSTALL -maxdepth 1 -type f -print -quit)
    bash $Simplify/apkInstall.sh "$file_path" "" && rm -f "$file_path"
  fi
fi

# --- Download and give execute (--x) permission to AAPT2 Binary ---
if [ ! -f "$HOME/aapt2" ]; then
  echo -e "$running Downloading aapt2 binary from GitHub.."
  curl -sL "https://github.com/arghya339/aapt2/releases/download/all/aapt2_$cpuAbi" --progress-bar -o "$HOME/aapt2" && chmod +x "$HOME/aapt2"
fi

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlGitHub.sh" --progress-bar -o $Simplify/dlGitHub.sh

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/APKMdl.sh" --progress-bar -o $Simplify/APKMdl.sh

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlUptodown.sh" --progress-bar -o $Simplify/dlUptodown.sh

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkInstall.sh" --progress-bar -o $Simplify/apkInstall.sh

if su -c "id" >/dev/null 2>&1; then
  curl -sL -o "$Simplify/apkMount.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkMount.sh"
fi

# --- Create simplify shortcut on Laucher Home ---
if [ ! -f "$HOME/.shortcuts/simplify" ] || [ ! -f "$HOME/.termux/widget/dynamic_shortcuts/simplify" ]; then
  echo -e "$notice Please wait few seconds! Creating simplify shortcut to access simplify from Launcher Widget."
  mkdir -p ~/.shortcuts  # create $HOME/.shortcuts dir if it not exist
  echo -e "#!/usr/bin/bash\nbash \$PREFIX/bin/simplify" > ~/.shortcuts/simplify  # create simplify shortcut script
  mkdir -p ~/.termux/widget/dynamic_shortcuts
  echo -e "#!/usr/bin/bash\nbash \$PREFIX/bin/simplify" > ~/.termux/widget/dynamic_shortcuts/simplify  # create simplify dynamic shortcut script
  chmod +x ~/.termux/widget/dynamic_shortcuts/simplify  # give execute (--x) permissions to simplify script
  if ! am start -n com.termux.widget/com.termux.widget.TermuxLaunchShortcutActivity > /dev/null 2>&1; then
    bash $Simplify/dlGitHub.sh "termux" "termux-widget" "latest" ".apk" "$SimplUsr"  # Download Termux:Widget app from GitHub using dlGitHub.sh
    Widget=$(find "$SimplUsr" -type f -name "termux-widget-app_v*+github.debug.apk" -print -quit)  # find downloaded Termux:Widget app package
    bash $Simplify/apkInstall.sh "$Widget" ""  # Install Termux:Widget app using apkInstall.sh
    [ -f "$Widget" ] && rm -f "$Widget"  # if Termux:Widget app package exist then remove it 
  fi
  if su -c "id" >/dev/null 2>&1; then
    if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
      su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
      su -c "cmd appops set com.termux SYSTEM_ALERT_WINDOW allow"
      su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
    else
      su -c "cmd appops set com.termux SYSTEM_ALERT_WINDOW allow"
    fi
  elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
    $HOME/rish -c "cmd appops set com.termux SYSTEM_ALERT_WINDOW allow"
  else
    echo -e "$info Please manually turn on: ${Green}Display over other apps → Termux → Allow display over other apps${Reset}" && sleep 6
    am start -a android.settings.action.MANAGE_OVERLAY_PERMISSION &> /dev/null  # open manage overlay permission settings
  fi
  echo -e "$info From Termux:Widget app tap on ${Green}simplify → Add to home screen${Reset}. Opening Termux:Widget app in 6 seconds.." && sleep 6
  am start -n com.termux.widget/com.termux.widget.TermuxCreateShortcutActivity > /dev/null 2>&1  # open Termux:Widget app shortcut create activity (screen/view) to add shortcut on Launcher Home
fi

# --- Download branding.zip ---
if [ ! -d "$SimplUsr/.branding" ] && [ ! -f "$SimplUsr/branding.zip" ]; then
  echo -e "$running Downloading ${Red}branding.zip${Reset} from GitHub.."
  curl -sL "https://github.com/arghya339/Simplify/releases/download/all/branding.zip" --progress-bar -o "$SimplUsr/branding.zip"
fi
# --- Extrct branding.zip ---
if [ -f "$SimplUsr/branding.zip" ] && [ ! -d "$SimplUsr/.branding" ]; then
  echo -e "$running Extrcting ${Red}branding.zip${Reset} to $SimplUsr dir.."
  pv "$SimplUsr/branding.zip" | bsdtar -xof - -C "$SimplUsr/" --no-same-owner --no-same-permissions
  mv "$SimplUsr/branding" "$SimplUsr/.branding"  # Rename branding dir to .branding to hide it from file Gallery
fi
# --- Remove branding.zip ---
if [ -d "$SimplUsr/.branding" ] && [ -f "$SimplUsr/branding.zip" ]; then
  rm "$SimplUsr/branding.zip"
fi

# --- Create a ks.keystore for Signing apk ---
if [ ! -f "$Simplify/ks.keystore" ]; then
  echo -e "$running Create a 'ks.keystore' for Signing apk.."
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -genkey -v -storetype pkcs12 -keystore $Simplify/ks.keystore -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -list -v -keystore $Simplify/ks.keystore -storepass 123456 | grep -oP '(?<=Owner:).*' | xargs
fi

Unmount() {
  su -c '/data/data/com.termux/files/usr/bin/bash -c '\''
  pkgArr=("com.google.android.youtube" "com.google.android.apps.youtube.music" "com.google.android.apps.photos" "com.spotify.music")
  nameArr=("YouTube" "YouTube Music" "Google Photos" "Spotify")

  if [ -d "/data/adb/revanced" ]; then
    while true; do
      nameList=()  # Clear nameList array first
      index=0  # This ensures sequential numbering
    
      # Build available apps list
      for i in "${!pkgArr[@]}"; do 
        if [ -e "/data/adb/revanced/${pkgArr[$i]}/" ]; then
          nameList[$index]="${nameArr[$i]}"
          ((index++))
        fi
      done

      # Exit if no apps available
      [ ${#nameList[@]} -eq 0 ] && { echo "No apps available!"; break; }
    
      # Display menu
      echo "Available apps:"
      for i in "${!nameList[@]}"; do
        echo "$i. ${nameList[$i]}"
      done

      # Get user input
      read -p "Enter index [0-$(( ${#nameList[@]} - 1 ))] or 'Q' to quit: " idx
    
      [[ "$idx" =~ [Qq] ]] && break
    
      # Validate and process selection
      if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -lt "${#nameList[@]}" ]; then
        for i in "${!nameArr[@]}"; do
          if [ "${nameArr[$i]}" = "${nameList[$idx]}" ]; then
            su -mm -c "/system/bin/sh /data/adb/post-fs-data.d/${pkgArr[$i]}.sh"
            break
          fi
        done
      else
        echo "Invalid selection!"
      fi
    done
  fi
  '\'''
}

config() {
  local key="$1"
  local value="$2"
  
  if [ ! -f "$simplifyJson" ]; then
    jq -n "{}" > "$simplifyJson"
  fi
  
  jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
}
all_key=("FetchPreRelease" "RipLocale" "RipDpi" "RipLib" "ChangeRVXSource" "ReadPatchesFile" "Branding" "CheckTermuxUpdate" "openjdk")
all_key+=("InstallPackageFor" "KeepsData" "GrantAllRuntimePermissions" "InstalledAsTestOnly" "BypassLowTargetSdkBolck" "DisablePlayProtect" "Installer" "Reinstall" "EnableRoolback")
all_value=("$isPreRelease" "$isRipLocale" "$isRipDpi" "$isRipLib" "$isChangeRVXSource" "$isReadPatchesFile" "$branding" "$isCheckTermuxUpdate" "$isJdkVersion")
all_value+=("$isU" "$isK" "$isG" "$isT" "$isL" "$isV" "$isI" "$isR" "$isB")
# Loop through all keys and set values if they don't exist
for i in "${!all_key[@]}"; do
  if ! jq -e --arg key "${all_key[i]}" 'has($key)' "$simplifyJson" >/dev/null; then
    config "${all_key[i]}" "${all_value[i]}"
  fi
done

tfConfig() {
  local key=$1
  local value=$2
  local m1=${3}
  local m2=${4}

  while true; do
    read -r -p "$key [T/f]: " opt
      case "$opt" in
      [Tt]*)
        value=1  # value  == true
        config "$key" "$value"
        echo -e "$good ${Green}$key is True! $m1.${Reset}"
        break
        ;;
      [Ff]*)
        value=0  # value  == false
        config "$key" "$value"
        echo -e "$good ${Green}$key is False! $m2.${Reset}"
        break
        ;;
      *) echo -e "${info} Invalid input! Please enter T or F." ;;
    esac
  done
}

pat() {
  while true; do
    if { [ -f "$HOME/.config/gh/hosts.yml" ] && ! grep -q "{}" "$HOME/.config/gh/hosts.yml" 2>/dev/null; } || { [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; }; then
      echo -e "${notice} You already have a GitHub token!"
      echo -e "${Yellow}[?] Do you want to delete it? [Y/n]${Reset} \c" && read userInput
      case "$userInput" in
        [Yy]*)
          if { [ -f "$HOME/.config/gh/hosts.yml" ] && ! grep -q "{}" "$HOME/.config/gh/hosts.yml" 2>/dev/null; } || gh auth status 2>/dev/null; then
            gh auth logout  # Logout from gh cli
          elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
            jq 'del(.PAT)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete PAT key from simplify.json
            termux-open-url "https://github.com/settings/tokens"
          fi
          echo -e "$good ${Green}Successfully deleted your GitHub token!${Reset}"
          ;;
        [Nn]*) break ;;
        *) echo -e "${info} Invalid input! Please enter Yes or No." ;;
      esac
    else
      echo -e "${Yellow}[?] Do you want to increase the GitHub API rate limit by adding a github token? [Y/n]${Reset} \c" && read userInput
      case "$userInput" in
        [Yy]*)
          echo -e "${Yellow}Select a method to create a GitHub access token: (gh) GitHub CLI or (pat) Personal Access Token? [gh/pat]${Reset} \c" && read method
          case "$method" in
            [Gg]*)
              pkgInstall "gh"  # gh install/update
              echo -e "${running} Creating GitHub access token using GitHub CLI.."
              gh auth login  # Authenticate gh cli with GitHub account
              gh_api_response=$(owner="ReVanced" && repo="revanced-patches" && gh api "repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
              if [[ $gh_api_response == v* ]] && [ $gh_api_response != "null" ]; then
                echo -e "$good ${Green}Successfully authenticated with GitHub CLI!${Reset}"
                echo -e "$notice ${Yellow}Your GitHub API rate limit has been increased.${Reset}"
                break
              else
                echo -e "${bad} ${Red}Failed to authenticate with GitHub CLI! Please try again.${Reset}"
                gh auth logout  # Logout from gh cli
              fi
              ;;
            [Pp]*)
              echo -e "${running} Creating Personal Access Token.."
              termux-open-url "https://github.com/settings/tokens/new?scopes=public_repo&description=Simplify"  # Create a PAT with the scope `public_repo`
              echo -e "${Yellow}Please copy the generated Simplify PAT & paste it here:${Reset} \c" && read -r pat
              if [[ $pat == ghp_* ]] && [ $pat != "" ]; then
                config "PAT" "$pat"
                PAT=$(jq -r '.PAT' "$simplifyJson" 2>/dev/null)
                gh_api_response=$(auth="-H \"Authorization: Bearer $PAT\"" && owner="ReVanced" && repo="revanced-patches" && curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
                if [[ $gh_api_response == v* ]] && [ $gh_api_response != "null" ]; then
                  echo -e "$good ${Green}Successfully added your GitHub PAT!${Reset}"
                  echo -e "$notice ${Yellow}Your GitHub API rate limit has been increased.${Reset}"
                  break
                fi
              else
                echo -e "${bad} ${Red}Invalid PAT! Please try again.${Reset}"
                jq 'del(.PAT)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete PAT key from simplify.json
                termux-open-url "https://github.com/settings/tokens"
              fi
              ;;
            *) echo -e "${info} Invalid input! Please enter gh or pat." ;;
          esac
          ;;
        [Nn]*) break ;;
        *) echo -e "${info} Invalid input! Please enter Yes or No." ;;
      esac
    fi
  done
}

change_yt_ytm_app_icon_header() {
  while true; do
    echo -e "G. google_family\nP. pink\nV. vanced_light\nR. revancify_blue\n"
    read -r -p "changeYouTubeYTMusicAppIconHeader [G/P/V/R]: " opt
    case "$opt" in
      [Gg]*)
        branding="google_family"
        config "Branding" "$branding"
        echo -e "$good ${Green}appIconHeader successfully set to google_family!${Reset}"
        break
        ;;
      [Pp]*)
        branding=pink
        config "Branding" "$branding"
        echo -e "$good ${Green}appIconHeader successfully set to pink!${Reset}"
        break
        ;;
      [Vv]*)
        branding="vanced_light"
        config "Branding" "$branding"
        echo -e "$good ${Green}appIconHeader successfully set to vanced_light!${Reset}"
        break
        ;;
      [Rr]*)
        branding="revancify_blue"
        config "Branding" "$branding"
        echo -e "$good ${Green}appIconHeader successfully set to revancify_blue!${Reset}"
        break
        ;;
      *) echo -e "$info Invalid input! Please enter G or P or V or R." ;;
    esac
  done
}

if [ $CheckTermuxUpdate -eq 1 ]; then
  if [ $Android -ge 8 ]; then
    latestReleases=$(curl -s https://api.github.com/repos/termux/termux-app/releases/latest | jq -r '.tag_name | sub("^v"; "")')  # 0.118.0
    if [ "$TERMUX_VERSION" != "$latestReleases" ]; then
      echo -e "$bad Termux app is outdated!"
      echo -e "$running Downloading Termux app update.."
      while true; do
        curl -L --progress-bar -C - -o "$SimplUsr/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk" "https://github.com/termux/termux-app/releases/download/v$latestReleases/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk"
        if [ $? -eq 0 ]; then
          break  # break the resuming download loop
        fi
        echo -e "$notice Retrying in 5 seconds.." && sleep 5  # wait 5 seconds
      done
      #bash $Simplify/dlGitHub.sh "termux" "termux-app" "latest" ".apk" "$SimplUsr" "termux-app_v.*+github-debug_$cpuAbi.apk"
      echo -e "$notice Please rerun this script again after Termux app update!"
      echo -e "$running Installing app update and restarting Termux app.." && sleep 3
      if su -c "id" >/dev/null 2>&1; then
        su -c "cp '$SimplUsr/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk' '/data/local/tmp/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk'"
        # Temporary Disable SELinux Enforcing during installation if it not in Permissive
        if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
          su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
          su -c 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
          su -c "cmd deviceidle whitelist +com.termux"
          touch "$Simplify/setenforce0"
          su -c "pm install -i com.android.vending '/data/local/tmp/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk'"
        else
          su -c 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
          su -c "cmd deviceidle whitelist +com.termux"
          su -c "pm install -i com.android.vending '/data/local/tmp/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk'"
        fi
      else
        if "$HOME/rish" -c "id" >/dev/null 2>&1; then
          $HOME/rish -c 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
          $HOME/rish -c "cmd deviceidle whitelist +com.termux"
          $HOME/rish -c "cmd appops set com.termux REQUEST_INSTALL_PACKAGES allow"
        else
          echo -e "$info Please Disabled: ${Green}Battery optimization → Not optimized → All apps → Termux → Don't optiomize → DONE${Reset}" && sleep 6
          am start -n com.android.settings/.Settings\$HighPowerApplicationsActivity &> /dev/null
          echo -e "$info Please Allow: ${Green}Install unknown apps → Termux → Allow from this source${Reset}" && sleep 6
          am start -n com.android.settings/.Settings\$ManageExternalSourcesActivity &> /dev/null
        fi
        bash $Simplify/apkInstall.sh "$SimplUsr/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk" "com.termux/.app.TermuxActivity"
      fi
    else
      if [ -f "$SimplUsr/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk" ]; then
        if su -c "id" >/dev/null 2>&1; then
          if [ "$(su -c 'getenforce 2>/dev/null')" = "Permissive" ] && [ -f "$Simplify/setenforce0" ]; then
            su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
            rm -f "$Simplify/setenforce0"
          fi
          su -c "rm -f '/data/local/tmp/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk'"
        elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
          ~/rish -c "rm -f '/data/local/tmp/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk'"
        fi
        rm -f "$SimplUsr/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk"
      fi
    fi
  else
    if [ $Android -eq 7 ]; then
      variant=7
    else
      variant=5
    fi
    lastReleases=$(curl -s https://api.github.com/repos/termux/termux-app/tags | jq -r '.[0].name | sub("^v"; "")')  # 0.119.0-beta.2
    if [ "$TERMUX_VERSION" != "$lastReleases" ]; then
      echo -e "$bad Termux app is outdated!"
      echo -e "$running Downloading Termux app update.."
      while true; do
        su -c "$PREFIX/bin/curl -L --progress-bar -C - -o '/data/local/tmp/termux-app_v${lastReleases}+apt-android-$variant-github-debug_$cpuAbi.apk' 'https://github.com/termux/termux-app/releases/download/v$lastReleases/termux-app_v${lastReleases}+apt-android-$variant-github-debug_$cpuAbi.apk'"
        if [ $? -eq 0 ]; then
          break  # break the resuming download loop
        fi
        echo -e "$notice Retrying in 5 seconds.." && sleep 5  # wait 5 seconds
      done
      #bash $Simplify/dlGitHub.sh "termux" "termux-app" "pre" ".apk" "$SimplUsr" "termux-app_v.*+apt-android-$variant-github-debug_$cpuAbi.apk"
      echo -e "$notice Please rerun this script again after Termux app update!"
      echo -e "$running Installing app update and restarting Termux app.." && sleep 3
      if su -c "id" >/dev/null 2>&1; then
        su -c "cp '$SimplUsr/termux-app_v${lastReleases}+apt-android-$variant-github-debug_$cpuAbi.apk' '/data/local/tmp/termux-app_v${lastReleases}+apt-android-$variant-github-debug_$cpuAbi.apk'"
        # Temporary Disable SELinux Enforcing during installation if it not in Permissive
        if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
          su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
          su -c 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
          su -c "cmd deviceidle whitelist +com.termux"
          touch "$Simplify/setenforce0"
          su -c "pm install -i com.android.vending '/data/local/tmp/termux-app_v${lastReleases}+apt-android-$variant-github-debug_$cpuAbi.apk'"
        else
          su -c 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
          su -c "cmd deviceidle whitelist +com.termux"
          su -c "pm install -i com.android.vending '/data/local/tmp/termux-app_v${lastReleases}+apt-android-$variant-github-debug_$cpuAbi.apk'"
        fi
      else
        if "$HOME/rish" -c "id" >/dev/null 2>&1; then
          $HOME/rish -c 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
          $HOME/rish -c "cmd deviceidle whitelist +com.termux"
          $HOME/rish -c "cmd appops set com.termux REQUEST_INSTALL_PACKAGES allow"
          $HOME/rish -c "cmd appops set com.termux.widget REQUEST_INSTALL_PACKAGES allow"
        else
          echo -e "$info Please Disabled: ${Green}Battery optimization → Not optimized → All apps → Termux → Don't optiomize → DONE${Reset}" && sleep 6
          am start -n com.android.settings/.Settings\$HighPowerApplicationsActivity &> /dev/null
          echo -e "$info Please Allow: ${Green}Install unknown apps → Termux → Allow from this source${Reset}" && sleep 6
          am start -n com.android.settings/.Settings\$ManageExternalSourcesActivity &> /dev/null
        fi
        bash $Simplify/apkInstall.sh "$SimplUsr/termux-app_v${latestReleases}+apt-android-$variant-github-debug_$cpuAbi.apk" "com.termux/.app.TermuxActivity"
      fi
    else
      if [ -f "$SimplUsr/termux-app_v${lastReleases}+apt-android-$variant-github-debug_$cpuAbi.apk" ]; then
        if su -c "id" >/dev/null 2>&1; then
          if [ "$(su -c 'getenforce 2>/dev/null')" = "Permissive" ] && [ -f "$Simplify/setenforce0" ]; then
            su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
            rm -f "$Simplify/setenforce0"
          fi
          su -c "rm -f '/data/local/tmp/termux-app_v${latestReleases}+apt-android-$variant-github-debug_$cpuAbi.apk'"
        elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
          ~/rish -c "rm -f '/data/local/tmp/termux-app_v${latestReleases}+apt-android-$variant-github-debug_$cpuAbi.apk'"
        fi
        rm -f "$SimplUsr/termux-app_v${latestReleases}+apt-android-$variant-github-debug_$cpuAbi.apk"
      fi
    fi
  fi
fi

change_jdk_version() {
  # Get available JDK versions
  attempt=0
  while true; do
    jdkVersion=($(pkg search openjdk 2>&1 | grep -E "^openjdk-[0-9]+/" | awk -F'[-/ ]' '{print $2}'))
    if [ $attempt -eq 7 ]; then
      echo -e "$notice Not found any java version in search result, after 7 attempts."
      break
    fi
    if [ ${#jdkVersion[@]} -ne 0 ]; then
      break
    fi  
    ((attempt++))
    sleep 0.5  # wait 500 milliseconds
  done
  
  if [ ${#jdkVersion[@]} -ne 0 ]; then
    while true; do
      # Display available versions
      echo -e "$info Available openjdk versions:"
      for i in "${!jdkVersion[@]}"; do
        echo "▶ openjdk-${jdkVersion[$i]}"
      done

      # Prompt for version selection
      echo -e "Enter jdk version number [${jdkVersion[@]}]: \c" && read version
      
      # if press enter key (input is empty) chose default openjdk version
      if [ -z "$version" ]; then
        version="$isJdkVersion"
      fi

      # Check if input is a valid number
      if [[ ! "$version" =~ ^[0-9]+$ ]]; then
        echo -e "$notice $version not a valid number! Please enter a valid openjdk version number."
        continue  # skips current iteration & continue next iteration
      fi

      # Check if entered version exists in the array
      found=false
      for available_version in "${jdkVersion[@]}"; do
        if [ "$available_version" = "$version" ]; then
          found=true
          break
        fi
      done
    
      # Display result
      if [ "$found" = true ]; then
        echo -e "$info Selected: openjdk-$version"
        config "openjdk" "$version"
        pkgInstall "openjdk-$version"  # java install/update
        echo -e "$good ${Green}Java version change successfully!${Reset}"
        break
      else
        echo -e "$notice openjdk-$version is not available! Available: ${jdkVersion[*]}"
      fi
    done
  fi
}

overwriteVersion() {
  if jq -e '.AndroidVersion != null' "$simplifyJson" >/dev/null 2>&1; then
    Android=$(jq -r '.AndroidVersion' "$simplifyJson" 2>/dev/null)  # Get Android version from json
    echo -e "$info Android version spoofed to $Android!"
  else
    echo -e "$info Android version not spoofed yet!"
  fi
  while true; do
    echo -e "${Yellow}Enter the Android version you want to spoof or '0' to disabled spoof: ${Reset}\c" && read spoofVersion
    if [[ $spoofVersion =~ ^[0-9]+$ ]]; then  # Check if the input is a valid version format
      if [ $spoofVersion -eq 0 ]; then
        echo -e "$running Disabling Android version spoofing.."
        jq -e 'del(.AndroidVersion)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete AndroidVersion key from simplify.json
        echo -e "$good ${Green}Android version spoofing disabled successfully!${Reset}"
        break
      elif [ $spoofVersion -lt 4 ]; then
        echo -e "$notice Android version $spoofVersion is not supported by ReVanced patches! Please enter a valid version that is <= 4."
      elif [ $spoofVersion -ge 4 ]; then
        echo -e "$running Spoofing Android version to $spoofVersion.."
        config "AndroidVersion" "$spoofVersion"
        echo -e "$good ${Green}Android version spoofed successfully!${Reset}"
        break
      fi
    else
      echo -e "$info Invalid Android version format! Please enter a valid version."
    fi
  done
}

overwriteArch() {
  if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
    cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
    echo -e "$info Device architecture spoofed to $cpuAbi!"
  else
    echo -e "$info Device architecture not spoofed yet!"
  fi
  while true; do
    echo -e "0. Disabled spoofing\n8. arm64-v8a\n7. armeabi-v7a\n4. x86_64\n6. x86\n"
    read -r -p "Select: " arch
    case "$arch" in
      0)
        echo -e "$running Disabling device architecture spoofing.."
        jq -e 'del(.DeviceArch)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete DeviceArch key from simplify.json
        echo -e "$good ${Green}Device architecture spoofing disabled successfully!${Reset}"
        break
        ;;
      8)
        echo -e "$running Spoofing device architecture to arm64-v8a.."
        config "DeviceArch" "arm64-v8a"
        echo -e "$good ${Green}Device architecture spoofed to arm64-v8a successfully!${Reset}"
        break
        ;;
      7)
        echo -e "$running Spoofing device architecture to armeabi-v7a.."
        config "DeviceArch" "armeabi-v7a"
        echo -e "$good ${Green}Device architecture spoofed to armeabi-v7a successfully!${Reset}"
        break
        ;;
      4)
        echo -e "$running Spoofing device architecture to x86_64.."
        config "DeviceArch" "x86_64"
        echo -e "$good ${Green}Device architecture spoofed to x86_64 successfully!${Reset}"
        break
        ;;
      6)
        echo -e "$running Spoofing device architecture to x86.."
        config "DeviceArch" "x86"
        echo -e "$good ${Green}Device architecture spoofed to x86 successfully!${Reset}"
        break
        ;;
      *) echo -e "$info Invalid input! Please enter 0, 8, 7, 4, 6." ;;
    esac
  done
}

DeletePatchedApk() {
  local nameArr=("YouTube" "YT-Music" "Spotify" "TikTok" "Google Photos" "Instagram" "Facebook" "Facebook Messenger" "Reddit" "X" "Adobe Lightroom Mobile" "Photomath" "Duolingo" "RAR" "Amazon Prime Video" "Twitch" "Tumblr" "Threads" "Strava" "SoundCloud" "Proton Mail" "Calorie Counter MyFitnessPal" "NovaLauncher" "Tasker" "Crunchyroll" "Cricbuzz Cricket Scores and News")
  for app in "${nameArr[@]}"; do
    find "$SimplUsr" -type f -name "${app}-RV*_v[0-9.]*-${cpuAbi}.apk" \
      -exec echo "Deleting: {}" \; \
      -exec rm -f {} \; 2>/dev/null
  done
  echo "Cleanup complete!"
}

DeletePatchLog() {
  local nameArr=("YouTube" "YT-Music" "Spotify" "TikTok" "Google Photos" "Instagram" "Facebook" "Facebook Messenger" "Reddit" "X" "Adobe Lightroom Mobile" "Photomath" "Duolingo" "RAR" "Amazon Prime Video" "Twitch" "Tumblr" "Threads" "Strava" "SoundCloud" "Proton Mail" "Calorie Counter MyFitnessPal" "NovaLauncher" "Tasker" "Crunchyroll" "Cricbuzz Cricket Scores and News")
  for app in "${nameArr[@]}"; do
    find "$SimplUsr" -type f -name "${app}-RV*_patch-log.txt" \
      -exec echo "Deleting: {}" \; \
      -exec rm -f {} \; 2>/dev/null
  done
  echo "Cleanup complete!"
}

DeleteListPatches() {
  local pkgArr=(
    "app.revanced"
    "com.google.android.youtube"
    "com.google.android.apps.youtube.music"
    "com.spotify.music"
    "com.zhiliaoapp.musically"
    "com.google.android.apps.photos"
    "com.google.android.apps.recorder"
    "com.instagram.android"
    "com.facebook.katana"
    "com.facebook.orca"
    "com.reddit.frontpage"
    "com.twitter.android"
    "com.adobe.lrmobile"
    "com.microblink.photomath"
    "com.duolingo"
    "com.rarlab.rar"
    "com.amazon.avod.thirdpartyclient"
    "tv.twitch.android.app"
    "com.tumblr"
    "com.instagram.barcelona"
    "com.strava"
    "com.soundcloud.android"
    "ch.protonmail.android"
    "com.myfitnesspal.android"
    "com.crunchyroll.crunchyroid"
    "com.cricbuzz.android"
  )
  for pkg in "${pkgArr[@]}"; do
    find "$SimplUsr" -type f -name "${pkg}_list-patches.txt" \
      -exec echo "Deleting: {}" \; \
      -exec rm -f {} \; 2>/dev/null
  done
  echo "Cleanup complete!"
}

DeletePatchesOption() {
  local patchesArr=(
    yt_patches_args
    yt_music_patches_args
    spotify_patches_args
    tiktok_patches_args
    photos_patches_args
    instagram_patches_args
    facebook_patches_args
    fb_messenger_patches_args
    reddit_patches_args
    lightroom_patches_args
    photomath_patches_args
    duolingo_patches_args
    rar_patches_args
    prime_video_patches_args
    twitch_patches_args
    tumblr_patches_args
    threads_patches_args
    strava_patches_args
    soundcloud_patches_args
    protonmail_patches_args
    myfitnesspal_patches_args
    crunchyroll_patches_args
    cricbuzz_patches_args
  )
  for patches in "${patchesArr[@]}"; do
    find "$SimplUsr" -type f -name "${patches}.txt" \
      -exec echo "Deleting: {}" \; \
      -exec rm -f {} \; 2>/dev/null
  done
  echo "Cleanup complete!"
}

UninstallPatchedApp() {
  local pkgArr=(
    "app.revanced.android.youtube"
    "app.rvx.android.youtube"
    "app.rvx.android.apps.youtube.music"
    "com.spotify.music"
    "com.zhiliaoapp.musically"
    "app.revanced.android.photos"
    "com.instagram.android"
    "com.facebook.katana"
    "com.facebook.orca"
    "com.reddit.frontpage"
    "com.twitter.android"
    "com.adobe.lrmobile"
    "com.microblink.photomath"
    "com.duolingo"
    "com.rarlab.rar"
    "com.amazon.avod.thirdpartyclient"
    "tv.twitch.android.app"
    "com.tumblr"
    "com.instagram.barcelona"
    "com.strava"
    "com.soundcloud.android"
    "ch.protonmail.android"
    "com.myfitnesspal.android"
    "com.teslacoilsw.launcher"
    "net.dinglisch.android.taskerm"
    "com.crunchyroll.crunchyroid"
    "com.cricbuzz.android"
  )
  local nameArr=(
    "YouTube RV" "YouTube" "YT Music" "Spotify" "TikTok" "Google Photos" "Instagram" "Facebook" "Facebook Messenger" "Reddit" "X" "Adobe Lightroom Mobile" "Photomath" "Duolingo" "RAR" "Amazon Prime Video" 
    "Twitch" "Tumblr" "Threads" "Strava" "SoundCloud" "Proton Mail" "Calorie Counter MyFitnessPal" "NovaLauncher" "Tasker" "Crunchyroll" "Cricbuzz Cricket Scores and News"
  )
  
  while true; do
    
    # Display menu
    echo "Available apps:"
    for i in "${!nameArr[@]}"; do
      echo "$i. ${nameArr[i]}"
    done

    # Get user input
    read -p "Enter index [0-$(( ${#nameArr[@]} - 1 ))] or 'Q' to quit: " idx
    
    [[ "$idx" =~ [Qq] ]] && break
    
    # Validate and process selection
    if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -lt "${#nameArr[@]}" ]; then
      if su -c "id" >/dev/null 2>&1; then
        echo "Uninstalling: ${nameArr[idx]}"
        if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
          su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
          su -c "pm uninstall --user 0 ${pkgArr[idx]}"
          su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
        else
          su -c "pm uninstall --user 0 ${pkgArr[idx]}"
        fi
      elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
        echo "Uninstalling: ${nameArr[idx]}"
        ~/rish -c "pm uninstall --user 0 ${pkgArr[idx]}"
      else
        #am start -a android.intent.action.DELETE -d package:"${pkgArr[idx]}" > /dev/null 2>&1
        am start -a android.intent.action.UNINSTALL_PACKAGE -d package:"${pkgArr[idx]}" > /dev/null 2>&1
        sleep 6  # wait 6 seconds
        #echo "Opening App info Activity for: ${nameArr[idx]}"
        am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:"${pkgArr[idx]}" > /dev/null 2>&1
      fi
    else
      echo "Invalid selection! Please enter a number between 0 and $((${#nameArr[@]} - 1))."
    fi

  done
}

# --- Feature request prompt ---
feature() {
  echo -e "${Yellow}Do you want any new feature in this script? [Y/n]${Reset}: \c" && read userInput
  case "$userInput" in
    [Yy]*)
      echo -e "${running} Creating feature request template using your key words.."
      echo -e "Describe the new feature: \c" && read feature_description
      termux-open-url "https://github.com/arghya339/Simplify/issues/new?title=Feature&body=$feature_description"
      echo -e "${Green}❤️ Thanks for your suggestion!${Reset}"
      ;;
    [Nn]*) echo -e "${running} Proceeding.." ;;
    *) echo -e "${info} ${Blue}Invalid input! Please enter Yes or No.${Reset}" ;;
  esac
}

# --- Bug report prompt ---
bug() {
  echo -e "${Yellow}Did you find any bugs? [Y/n]${Reset}: \c" && read userInput
  case "$userInput" in
    [Yy]*)
      echo -e "${running} Creating bug report template uisng your keywords.."
      echo -e "Describe the bug: \c" && read issue_description
      termux-open-url "https://github.com/arghya339/Simplify/issues/new?title=Bug&body=$issue_description"
      echo -e "${Green}🖤 Thanks for the report!${Reset}"
      ;;
    [Nn]*) echo -e "${Green}💐 Thanks for chosing Simplify!${Reset}" ;;
    *) echo -e "${info} ${Blue}Invalid input! Please enter Yes or No.${Reset}" ;;
  esac
}

# --- Open support URL in the default browser ---
support() {
  echo -e "${Yellow}⭐ Star & 🍻 Fork me.."
  termux-open-url "https://github.com/arghya339/Simplify"
  echo -e "${Yellow}💲 Donation: PayPal/@arghyadeep339"
  termux-open-url "https://www.paypal.com/paypalme/arghyadeep339"
  echo -e "${Yellow}🔔 Subscribe: YouTube/@MrPalash360"
  termux-open-url "https://www.youtube.com/channel/UC_OnjACMLvOR9SXjDdp2Pgg/videos?sub_confirmation=1"
  #echo -e "${Yellow}📣 Follow: Telegram"
  #termux-open-url "https://t.me/MrPalash360"
  #echo -e "${Yellow}💬 Join: Telegram"
  #termux-open-url "https://t.me/MrPalash360Discussion"
}

# --- Show developer info ---
about() {
  echo -e "${Green}✨ Powered by ReVanced (revanced.app)"
  termux-open-url "https://revanced.app/"
  echo -e "${Green}🧑‍💻 Author arghya339 (github.com/arghya339)"
  echo
}

while true; do
  clear  # Clear
  # Apply the eye color to the simplify shape and print it
  echo -e "${BoldGreen}$print_simplify${Reset}" && echo ""  # Space
  echo -e "P. Download Patched App\nR. ReVanced\nX. ReVanced Extended\nT. Piko Twitter\nD. Dropped Patches\nL. LSPatch\nC. Configuration\nM. Miscellaneous\nF. Feature request\nB. Bug report\nS. Support\nA. About\nQ. Quit\n"
  echo -n "Select Patches source: " && read source
  case $source in
    [Pp])
      curl -sL -o "$Simplify/dlPatchedApp.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlPatchedApp.sh"
      bash "$Simplify/dlPatchedApp.sh"
      sleep 3
      ;;
    [Rr])
      if su -c "id" >/dev/null 2>&1; then
        pkgInstall "openssl"  # openssl install/update
        pkgInstall "python"  # python install/update
        if ! pip list 2>/dev/null | grep -q "apksigcopier"; then
          pip install apksigcopier > /dev/null 2>&1  # install apksigcopier using pip
        fi
      fi
      curl -sL -o "$RV/RV.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RV.sh"
      bash "$RV/RV.sh"
      sleep 3
      ;;
    [Xx])
      if su -c "id" >/dev/null 2>&1; then
        pkgInstall "openssl"  # openssl install/update
        pkgInstall "python"  # python install/update
        if ! pip list 2>/dev/null | grep -q "apksigcopier"; then
          pip install apksigcopier > /dev/null 2>&1  # install apksigcopier using pip
        fi
      fi
      curl -sL -o "$RVX/RVX.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RVX.sh"
      bash "$RVX/RVX.sh"
      sleep 3
      ;;
    [Tt])
      curl -sL -o "$pikoTwitter/pikoTwitter.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/pikoTwitter.sh"
      bash "$pikoTwitter/pikoTwitter.sh"
      sleep 3
      ;;
    [Dd])
      curl -sL -o "$Dropped/droppedPatches.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/droppedPatches.sh"
      bash "$Dropped/droppedPatches.sh"
      sleep 3
      ;;
    [Ll])
      curl -sL -o "$LSPatch/LSPatch.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/LSPatch.sh"
      bash "$LSPatch/LSPatch.sh"
      sleep 3
      ;;
    [Cc]*)
      while true; do
        FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null)
        RipLocale="$(jq -r '.RipLocale' "$simplifyJson" 2>/dev/null)"
        RipDpi="$(jq -r '.RipDpi' "$simplifyJson" 2>/dev/null)"
        RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
        ChangeRVXSource="$(jq -r '.ChangeRVXSource' "$simplifyJson" 2>/dev/null)"
        ReadPatchesFile="$(jq -r '.ReadPatchesFile' "$simplifyJson" 2>/dev/null)"
        Branding=$(jq -r '.Branding' "$simplifyJson" 2>/dev/null)
        jdkVersion=$(jq -r '.openjdk' "$simplifyJson" 2>/dev/null)
        echo -e "P. FetchPreRelease\nL. RipLocale\nD. RipDpi\nR. RipLib\nS. Change RVX Source\nT. Add gh PAT (increases gh api rate limit)\nO. Import Custom PatchesOptions from file\nB. Change YouTube & YT Music AppIcon & Header\nU. Check Termux update on startup\nJ. Change Java version\nI. SU/ SUI/ ADB Installation Options"
        if [ "$(getprop ro.product.manufacturer)" == "Genymobile" ] && ! "$HOME/adb" -s $(~/adb devices | grep "emulator-*" | awk '{print $1}') shell "id" >/dev/null 2>&1; then
          echo "A. Pair ADB"
        fi
        echo -e "Q. Quit\n"
        read -r -p "Select: " opt
        case "$opt" in
          [Pp]*) if [ "$FetchPreRelease" == 0 ]; then echo "FetchPreRelease == false"; else echo "FetchPreRelease == true"; fi
            key="FetchPreRelease" && value="$isPreRelease"
            m1="Last Pre Release Patches will be fetched"
            m2="Latest Release Patches will be fetched"
            tfConfig "$key" "$value" "$m1" "$m2"
            ;;
          [Ll]*) if [ "$RipLocale" == 1 ]; then echo "RipLocale == true"; else echo "RipLocale == false"; fi
            key="RipLocale" && value="$isRipLocale"
            m1="Device specific locale will be kept in patched apk file"
            m2="All locale will be kept in patched apk file"
            tfConfig "$key" "$value" "$m1" "$m2"
            ;;
          [Dd]*) if [ "$RipDpi" == 1 ]; then echo "RipDpi == true"; else echo "RipDpi == false"; fi
            key="RipDpi" && value="$isRipDpi"
            m1="Device specific dpi will be kept in patched apk file"
            m2="All dpi will be kept in patched apk file"
            tfConfig "$key" "$value" "$m1" "$m2"
            ;;
          [Rr]*) if [ "$RipLib" == 1 ]; then echo "RipLib == true"; else echo "RipLib == false"; fi
            key="RipLib" && value="$isRipLib"
            m1="Device specific arch lib will be kept in patched apk file"
            m2="All lib dir will be kept in patched apk file"
            tfConfig "$key" "$value" "$m1" "$m2"
            ;;
          [Ss]*) if [ "$ChangeRVXSource" == 0 ]; then echo "ChangeRVXSource == false"; else echo "ChangeRVXSource == true"; fi
            key="ChangeRVXSource" && value="$isChangeRVXSource"
            m1="RVX Patches source will be changed to forked (@anddea)"
            m2="RVX Patches source will remain official (@inotia00)"
            tfConfig "$key" "$value" "$m1" "$m2"
            ;;
          [Tt]*) 
            if { [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; } || { gh auth status > /dev/null 2>&1 && [ -f "$HOME/.config/gh/hosts.yml" ]; }; then
              if jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
                echo -e "$info ${Green}PAT: ghp_************************************${Reset}"
              else
                echo -e "$info ${Green}oauth_token: gho_************************************${Reset}"
              fi
            else
              echo -e "$notice ${Yellow}No GitHub token found!${Reset}"
            fi
            pat  # Call the pat function to create & add GitHub token
            ;;
          [Oo]*) if [ "$ReadPatchesFile" == 0 ]; then echo "ReadPatchesFile == false"; else echo "ReadPatchesFile == true"; fi
            key="ReadPatchesFile" && value="$isReadPatchesFile"
            m1="Custom PatchesOptions Loading from File"
            m2="Recommended PatchesOptions Loading from Script"
            tfConfig "$key" "$value" "$m1" "$m2"
            ;;
          [Bb]*) echo "changeYouTubeYTMusicAppIconHeader == $Branding" && change_yt_ytm_app_icon_header ;;
          [Uu]*) if [ $CheckTermuxUpdate -eq 1 ]; then echo "CheckTermuxUpdate == true"; else echo "CheckTermuxUpdate == false"; fi
            key="CheckTermuxUpdate" && value="$isCheckTermuxUpdate"
            m1="Check for Termux app updates on startup"
            m2="Never check for Termux app updates on startup"
            tfConfig "$key" "$value" "$m1" "$m2"
            ;;
          [Jj]*) echo "openjdkVersion == $jdkVersion" && change_jdk_version ;;
          [Ii]*)
            while true; do
              InstallPackageFor=$(jq -r '.InstallPackageFor' "$simplifyJson" 2>/dev/null)
              KeepsData=$(jq -r '.KeepsData' "$simplifyJson" 2>/dev/null)
              GrantAllRuntimePermissions=$(jq -r '.GrantAllRuntimePermissions' "$simplifyJson" 2>/dev/null)
              InstalledAsTestOnly=$(jq -r '.InstalledAsTestOnly' "$simplifyJson" 2>/dev/null)
              BypassLowTargetSdkBolck=$(jq -r '.BypassLowTargetSdkBolck' "$simplifyJson" 2>/dev/null)
              DisablePlayProtect=$(jq -r '.DisablePlayProtect' "$simplifyJson" 2>/dev/null)
              Installer=$(jq -r '.Installer' "$simplifyJson" 2>/dev/null)
              Reinstall=$(jq -r '.Reinstall' "$simplifyJson" 2>/dev/null)
              EnableRoolback=$(jq -r '.EnableRoolback' "$simplifyJson" 2>/dev/null)
              echo -e "U. Install Package for *user\nK. Allow Downgrade with keeps App data (reboot required)\nG. Grant All Runtime/ Requested Permissions\nT. Installed as test-only app\nL. Bypass Low Target SDK Bolck\nV. Disable Play Protect Package Verification\nI. Installer\nR. Reinstall (Replace/ Upgrade) Existing Installed Package\nB. Enable Version Roolback\nQ. Quit\n"
              read -r -p "Select: " opt
              case "$opt" in
                [Uu]*)
                  if [ "$InstallPackageFor" -eq 0 ]; then echo "InstallPackageFor == 0 (default-user)"; else echo "InstallPackageFor == 1 (all-users)"; fi
                  key="InstallPackageFor"
                  echo -e "D. default-user\nA. all-users\n"
                  read -r -p "Install Package for " u
                  case "$u" in
                    [Dd]*) value="0"; config "$key" "$value" && echo -e "${Green}Install Package for default-user set successfully!${Reset}" ;;
                    [Aa]*) value="1"; config "$key" "$value" && echo -e "${Green}Install Package for all-user set successfully!${Reset}" ;;
                    *) value="$isU"; config "$key" "$value" && echo -e "${Green}Install Package for default-user set successfully!${Reset}" ;;
                  esac
                  ;;
                [Kk]*)
                  if [ "$KeepsData" -eq 0 ]; then echo "KeepsData == false"; else echo "KeepsData == true"; fi
                  key="KeepsData"; value="$isK"
                  m1="Allow Downgrade with keeps App data Enabled"
                  m2="Allow Downgrade with keeps App data Disabled"
                  tfConfig "$key" "$value" "$m1" "$m2"
                  ;;
                [Gg]*)
                  if [ "$GrantAllRuntimePermissions" -eq 0 ]; then echo "GrantAllRuntimePermissions == false"; else echo "GrantAllRuntimePermissions == true"; fi
                  key="GrantAllRuntimePermissions"; value="$isG"
                  m1="Grant All Runtime Permissions Enabled"
                  m2="Grant All Runtime Permissions Disabled"
                  tfConfig "$key" "$value" "$m1" "$m2"
                  ;;
                [Tt]*)
                  if [ "$InstalledAsTestOnly" -eq 0 ]; then echo "InstalledAsTestOnly == false"; else echo "InstalledAsTestOnly == true"; fi
                  key="InstalledAsTestOnly"; value="$isT"
                  m1="Installed as test-only Enabled"
                  m2="Installed as test-only Disabled"
                  tfConfig "$key" "$value" "$m1" "$m2"
                  ;;
                [Ll]*)
                  if [ "$BypassLowTargetSdkBolck" -eq 1 ]; then echo "BypassLowTargetSdkBolck == true"; else echo "BypassLowTargetSdkBolck == false"; fi
                  key="BypassLowTargetSdkBolck"; value="$isL"
                  m1="Bypass Low Target SDK Bolck Enabled"
                  m2="Bypass Low Target SDK Bolck Disabled"
                  tfConfig "$key" "$value" "$m1" "$m2"
                  ;;
                [Vv]*)
                  if [ "$DisablePlayProtect" -eq 1 ]; then echo "DisablePlayProtect == true"; else echo "DisablePlayProtect == false"; fi
                  key="DisablePlayProtect"; value="$isV"
                  m1="Play Protect Package Verification Disabled"
                  m2="Play Protect Package Verification Enabled"
                  tfConfig "$key" "$value" "$m1" "$m2"
                  ;;
                [Ii]*)
                  case "$Installer" in
                    "com.android.vending") echo "Installer == com.android.vending (PlayStore)" ;;
                    "com.android.packageinstaller") echo "Installer == com.android.packageinstaller (PackageInstaller)" ;;
                    "com.android.shell") echo "Installer == com.android.shell (Shell)" ;;
                    "adb") echo "Installer == adb" ;;
                  esac
                  key="Installer"
                  echo -e "P. Play Store\nI. Package Installer\nS. Shell\nA. ADB\n"
                  read -r -p "Installer: " i
                  case "$i" in
                    [Pp]*) value="com.android.vending"; config "$key" "$value" && echo -e "${Green}Successfully set Installer as 'com.android.vending' (PlayStore)${Reset}" ;;
                    [Ii]*) value="com.android.packageinstaller"; config "$key" "$value" && echo -e "${Green}Successfully set Installer as 'com.android.packageinstaller' (PackageInstaller)${Reset}" ;;
                    [Ss]*) value="com.android.shell"; config "$key" "$value" && echo -e "${Green}Successfully set Installer as 'com.android.shell' (Shell)${Reset}" ;;
                    [Aa]*) value="adb"; config "$key" "$value" && echo -e "${Green}Successfully set Installer as 'adb'${Reset}" ;;
                    *) value="$isI"; config "$key" "$value" && echo -e "${Green}Successfully set Installer as 'com.android.vending' (PlayStore)${Reset}" ;;
                  esac
                  ;; 
                [Rr]*)
                  if [ "$Reinstall" -eq 1 ]; then echo "Reinstall == true"; else echo "Reinstall == false"; fi
                  key="Reinstall"; value="$isR"
                  m1="Reinstall Existing Installed Package Enabled"
                  m2="Reinstall Existing Installed Package Disabled"
                  tfConfig "$key" "$value" "$m1" "$m2"
                  ;;
                [Bb]*)
                  if [ "$EnableRoolback" -eq 0 ]; then echo "EnableRoolback == false"; else echo "EnableRoolback == true"; fi
                  key="EnableRoolback"; value="$isB"
                  m1="Version Roolback Enabled"
                  m2="Version Roolback Disabled"
                  tfConfig "$key" "$value" "$m1" "$m2"
                  ;;
                [Qq]*) break ;;
                *) echo -e "$info Invalid input! Please enter U / K / G / T / L / V / I / R / B / Q." ;;
              esac
            done
            ;;
          [Aa]*)
            echo -e "Enable Developer Options:\n  1. Open Settings app on your device\n  2. tap About Phone\n  3. Find & tap 7 times on Build Number\n  4. You may need to enter your lock screen password\n  >>You will see a toast message saying 'You are now a developer!'"
            echo -e "Enable Wireless Debugging:\n  1. Go back to main Settings screen\n  2. Scroll down & tap System\n  3. Tap Developer Options\n  4. Scroll down & find Wireless Debugging\n  5. Toggle it ON\n  6. A new dialog box will appear with a warning. Read it and tap Allow"
            echo -e "Pair Device with Pairing Code:\n  1. In Wireless Debugging menu, tap Pair device with pairing code. It will show you a IP address & port (e.g., 192.168.1.50:40435) and a 6-digit pairing code (e.g., 123456).\n  2. open Termux & enter [IP address:port] [Wi-Fi pairing code] (e.g., 192.168.1.50:40435 123456)\n"
            am start -n "com.android.settings/.Settings\$WirelessDebuggingActivity" >/dev/null 2>&1
            [ $? -ne 0 ] && am start -n "com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity" >/dev/null 2>&1 || am start -n com.android.settings/.Settings\$MyDeviceInfoActivity >/dev/null 2>&1
            read -r -p "HOST[:PORT] [PAIRING CODE] " input
            host_port=$(echo "$input" | awk '{print $1}'); pairing_code=$(echo "$input" | awk '{print $2}')
            ~/adb pair "$host_port" "$pairing_code"
            ;;
          [Qq]*) break ;;
          *) echo -e "$info Invalid input! Please enter P / L / D / R / S / T / O / B / U / J / I / A / Q." ;;
        esac
      done
      sleep 3
      ;;
    [Mm]*)
      while true; do
        echo -e "\nV. Spoof Android Version\nA. Spoof Device Architecture\nD. Delete patched apk file\nL. Delete Patch Log\nP. Delete list-patches file\nO. Delete PatchesOption file\nU. Uninstall Patched Apps\nM. Unmount Patched Apps\nS. Uninstall Simplify\nQ. Quit\n"
        read -r -p "Select: " misc
        case "$misc" in
          [Vv]*) overwriteVersion ;;
          [Aa]*) overwriteArch ;;
          [Dd]*) DeletePatchedApk ;;
          [Ll]*) DeletePatchLog ;;
          [Pp]*) DeleteListPatches ;;
          [Oo]*) DeletePatchesOption ;;
          [Uu]*) UninstallPatchedApp ;;
          [Mm]*) Unmount && sleep 3 ;;
          [Ss]*)
            echo -ne "${Yellow}Are you sure you want to uninstall Simplify? [Y/n]${Reset}: " && read -r userInput
            case "$userInput" in
              [Yy]*)
                echo -ne "${Red}Type '://' to confirm uninstallation: ${Reset}" && read -r finalInput
                case "$finalInput" in
                  "://")
                    [ -d "$Simplify" ] && rm -rf "$Simplify"
                    [ -d "$SimplUsr" ] && rm -rf "$SimplUsr"
                    [ -f "$HOME/.Simplify.sh" ] && rm -f "$HOME/.Simplify.sh"
                    [ -f "$PREFIX/bin/simplify" ] && rm -f "$PREFIX/bin/simplify"
                    [ -f "$HOME/.shortcuts/simplify" ] && rm -f ~/.shortcuts/simplify
                    [ -f "$HOME/.termux/widget/dynamic_shortcuts/simplify" ] && rm -f ~/.termux/widget/dynamic_shortcuts/simplify
                    pkgUninstall "aria2"  # aria2 uninstall
                    pkgUninstall "jq"  # jq uninstall
                    pkgUninstall "pup"  # pup uninstall
                    pkgUninstall "openjdk-$jdkVersion"  # java uninstall
                    pkgUninstall "apksigner"  # apksigner uninstall
                    pkgUninstall "bsdtar"  # bsdtar uninstall
                    pkgUninstall "pv"  # pv uninstall
                    pkgUninstall "glow"  # glow uninstall
                    if su -c "id" >/dev/null 2>&1; then
                      if ! pip list 2>/dev/null | grep -q "apksigcopier"; then
                        pip uninstall apksigcopier > /dev/null 2>&1  # uninstall apksigcopier using pip
                      fi
                      pkgUninstall "python"  # python uninstall
                    fi
                    clear
                    echo -e "$good ${Green}Simplify has been uninstalled successfully :(${Reset}"
                    echo -e "💔 ${Blue}We're sorry to see you go. Feel free to reinstall anytime!${Reset}"
                    termux-open-url "https://github.com/arghya339/Simplify/"
                    exit 0
                    ;;
                esac
                ;;
              [Nn]*) echo -e "$notice ${Yellow}Uninstallation cancelled! Simplify will remain installed.${Reset}" ;;
              *) echo -e "$info ${Blue}Invalid input! Uninstallation skipped.${Reset}" ;;
            esac
            ;;
          [Qq]*) break ;;
          *) echo -e "$info Invalid input! Please enter V or A or D or L or P or O or U or M or S." ;;
        esac
      done
      sleep 3
      ;;
    [Ff]*) feature && sleep 3 ;;
    [Bb]*) bug && sleep 3 ;;
    [Ss]*) support && sleep 3 ;;
    [Aa]*) about && sleep 3 ;;
    [Qq]*) if [ $isOverwriteTermuxProp -eq 1 ]; then sed -i '/allow-external-apps/s/^/# /' "$HOME/.termux/termux.properties";fi && clear && break ;;
    *) echo -e "$info Invalid input! Please enter: P / R / X / T / D / L / C / M / F / B / S / A / Q" && sleep 3 ;;
  esac
done
####################################################################################################################################################
