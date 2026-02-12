#!/usr/bin/bash

# Constants Colored log indicators
readonly good="\033[92;1m[✔]\033[0m"
readonly bad="\033[91;1m[✘]\033[0m"
readonly info="\033[94;1m[i]\033[0m"
readonly running="\033[37;1m[~]\033[0m"
readonly notice="\033[93;1m[!]\033[0m"
readonly question="\033[93;1m[?]\033[0m"

# ANSI color code
Green="\033[92m"
BoldGreen="\033[92;1m"
Red="\033[91m"
Blue="\033[94m"
Cyan="\033[96m"
White="\033[37m"
whiteBG="\e[47m\e[30m"
Yellow="\033[93m"
Reset="\033[0m"

# --- Checking Internet Connection ---
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 ; then
  echo -e "${bad} ${Red}Oops! No Internet Connection available.\nConnect to the Internet and try again later."
  exit 1
fi

# --- Downloading latest Simplify.sh file from GitHub ---
curl -fsSL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/Simplify.sh"

# Check if symlink doesn't already exist
if [ ! -f "$PREFIX/bin/simplify" ]; then
  ln -s "$HOME/.Simplify.sh" "$PREFIX/bin/simplify"  # symlink (shortcut of Simplify.sh)
fi
chmod +x "$HOME/.Simplify.sh"  # give execute permission to the Simplify.sh

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

# --- Global Variables ---
read rows cols < <(stty size)
Simplify="$HOME/Simplify"  # /data/data/com.termux/files/home/Simplify dir
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
Download="/sdcard/Download"  # Download dir
RV="$Simplify/RV"
RVX="$Simplify/RVX"
RV4="$RVX/RV4"
RVX6_7="$Simplify/RVX6-7"  # RVX for Android 6 and 7
Morphe="$Simplify/Morphe"
pikoTwitter="$Simplify/pikoTwitter"
Dropped="$Simplify/Dropped"
LSPatch="$Simplify/LSPatch"
POST_INSTALL="$Simplify/POST_INSTALL"
mkdir -p "$Simplify" "$SimplUsr" "$RV" "$RVX" "$RV4" "$Morphe" "$pikoTwitter" "$Dropped" "$LSPatch" "$POST_INSTALL"  # Create $Simplify, $SimplUsr, $RV, $RVX, $RV4, $Morphe, $pikoTwitter, $Dropped, $LSPatch and $POST_INSTALL dir if it does't exist
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings

cloudflareDOH="https://cloudflare-dns.com/dns-query"
cloudflareIP="1.1.1.1,1.0.0.1"
APKM_REST_API_URL="https://www.apkmirror.com/wp-json/apkm/v1/app_exists/"
AUTH_TOKEN="YXBpLXRvb2xib3gtZm9yLWdvb2dsZS1wbGF5OkNiVVcgQVVMZyBNRVJXIHU4M3IgS0s0SCBEbmJL"
AndroidF=$(getprop ro.build.version.release)
Model=$(getprop ro.product.model)
Build=$(getprop ro.build.id)
K="$Model Build/$Build"
crVersion=$(curl -sL "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Android&num=1" | jq -r '.[0].version') || crVersion="143.0.0.0"
USER_AGENT="Mozilla/5.0 (Linux; Android $AndroidF; $K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${crVersion} Mobile Safari/537.36"

isPreRelease=0  # Default value (false/off/0) for isPreRelease, it's enabled latest release for Patches source
isRipLocale=1  # Default value (true/on/1) for RipLocale, it's delete locale from patched apk file except device specific locale by default
isRipDpi=1  # Default value (true/on/1) for RipDpi, it's delete dpi from patched apk file except device specific dpi by default
isRipLib=1  # Default value (true/on/1) for RipLib, it's delete lib dir from patched apk file except device specific arch lib by default
isChangeRVXSource=0  # Default value (false/off/0) for ChangeRVXSource, means patches source remain unchange ie. official source (inotia00) for RVX Patches
isReadPatchesFile=0  # Default value (false/off/0) for ReadPatchesFile, means recommended PatchesOptions loading from script.
branding="google_family"
isCheckTermuxUpdate=1
isJdkVersion="21"
isU=0  # Install Package for 0 (default-user), possible 1 (all-users)
isK=0  # Allow Downgrade with keeps App data 0 (false) because it's required reboot after pkg install, possible 1 (true)
isG=0  # Grant All Runtime Permissions 0 (false) due to Security Risk, possible 1
isT=0  # Installed as test-only app 0, possible 1
isL=1  # Bypass Low Target SDK Bolck 1 (true) it's allow Android 14+ to install apps that target below API level 23 (Android 6 and below), possible value 0
isV=1  # Disable Play Protect Package Verification 1 (true), possible 0
isA=0  # 'Disable Play Protect' is Enabled; this makes Enabling 'Disable Verify ADB installs' unnecessary
isI="com.android.vending"  # default: PlayStore | possible Installer: com.android.packageinstaller (PackageInstaller), com.android.shell (Shell), adb
isR=1  # Reinstall Existing Installed Package 1 (true) because without this app can't be installed if installed and to-be-installed version are same, possible 0
isB=0  # Enable Version Roolback 0, possible 1

# Config creation function
config() {
  local key="$1"
  local value="$2"
  
  [ ! -f "$simplifyJson" ] && jq -n "{}" > "$simplifyJson"
  jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
}

# Create Simplify config
all_key=("FetchPreRelease" "RipLocale" "RipDpi" "RipLib" "ChangeRVXSource" "ReadPatchesFile" "Branding" "CheckTermuxUpdate" "openjdk")
all_key+=("InstallPackageFor" "KeepsData" "GrantAllRuntimePermissions" "InstalledAsTestOnly" "BypassLowTargetSdkBolck" "DisablePlayProtect" "DisableVerifyAdbInstalls" "Installer" "Reinstall" "EnableRoolback")
all_value=("$isPreRelease" "$isRipLocale" "$isRipDpi" "$isRipLib" "$isChangeRVXSource" "$isReadPatchesFile" "$branding" "$isCheckTermuxUpdate" "$isJdkVersion")
all_value+=("$isU" "$isK" "$isG" "$isT" "$isL" "$isV" "$isA" "$isI" "$isR" "$isB")
# Loop through all keys and set values if they don't exist
for i in "${!all_key[@]}"; do
  ! jq -e --arg key "${all_key[i]}" 'has($key)' "$simplifyJson" >/dev/null && config "${all_key[i]}" "${all_value[i]}"
done

# Get Android version from json
jq -e '.AndroidVersion != null' "$simplifyJson" >/dev/null 2>&1 && Android=$(jq -r '.AndroidVersion' "$simplifyJson" 2>/dev/null) || Android=$(getprop ro.build.version.release | cut -d. -f1)
# Get Device Architecture from json
jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1 && cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null) || cpuAbi=$(getprop ro.product.cpu.abi)
# Get openjdk verison from json
jq -e '.openjdk != null' "$simplifyJson" >/dev/null 2>&1 && jdkVersion=$(jq -r '.openjdk' "$simplifyJson" 2>/dev/null) || jdkVersion="$isJdkVersion"
# Get RipLocale value from json
jq -e '.RipLocale != null' "$simplifyJson" >/dev/null 2>&1 && RipLocale="$(jq -r '.RipLocale' "$simplifyJson" 2>/dev/null)" || RipLocale=1
# Get RipDpi value from json
jq -e '.RipDpi != null' "$simplifyJson" >/dev/null 2>&1 && RipDpi="$(jq -r '.RipDpi' "$simplifyJson" 2>/dev/null)" || RipDpi=1
# Get RipLib value from json
jq -e '.RipLib != null' "$simplifyJson" >/dev/null 2>&1 && RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)" || RipLib=1
# Get FetchPreRelease value from json
jq -e '.FetchPreRelease != null' "$simplifyJson" >/dev/null 2>&1 && FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null) || FetchPreRelease=0
# Get CheckTermuxUpdate value from json
jq -e '.CheckTermuxUpdate != null' "$simplifyJson" >/dev/null 2>&1 && CheckTermuxUpdate=$(jq -r '.CheckTermuxUpdate' "$simplifyJson" 2>/dev/null) || CheckTermuxUpdate=1
# Get ReadPatchesFile value from json
jq -e '.ReadPatchesFile != null' "$simplifyJson" >/dev/null 2>&1 && ReadPatchesFile="$(jq -r '.ReadPatchesFile' "$simplifyJson" 2>/dev/null)" || ReadPatchesFile=0
# Get Branding value from json
jq -e '.Branding != null' "$simplifyJson" >/dev/null 2>&1 && Branding=$(jq -r '.Branding' "$simplifyJson" 2>/dev/null) || Branding="google_family"
# Get ChangeRVXSource value from json
jq -e '.ChangeRVXSource != null' "$simplifyJson" >/dev/null 2>&1 && ChangeRVXSource="$(jq -r '.ChangeRVXSource' "$simplifyJson" 2>/dev/null)" || ChangeRVXSource=0

[[ $Android -eq 7 || $Android -eq 6 ]] && mkdir -p "$RVX6_7"  # Create $RVX6_7 dir if Android version is 6 or 7

# Build locale
ripLocaleGen() {
  if [ $RipLocale -eq 1 ]; then
    locale=$(getprop persist.sys.locale | cut -d'-' -f1)  # Get System Languages
    [ -z $locale ] && locale=$(getprop ro.product.locale | cut -d'-' -f1)  # Get Languages
  elif [ $RipLocale -eq 0 ]; then
    locale="[a-z][a-z]"
  fi
}; ripLocaleGen

# Build lcd_dpi
ripDpiGen() {
  if [ $RipDpi -eq 1 ]; then
    density=$(getprop ro.sf.lcd_density)  # Get the device screen density
    # Check and categorize the density
    if [ "$density" -le "120" ]; then
      lcd_dpi="ldpi"  # Low Density
    elif [ "$density" -le "160" ]; then
      lcd_dpi="mdpi"  # Medium Density
    elif [ "$density" -le "213" ]; then
      lcd_dpi="tvdpi"  # TV Density
    elif [ "$density" -le "240" ]; then
      lcd_dpi="hdpi"  # High Density
    elif [ "$density" -le "320" ]; then
      lcd_dpi="xhdpi"  # Extra High Density
    elif [ "$density" -le "480" ]; then
      lcd_dpi="xxhdpi"  # Extra Extra High Density
    elif [ "$density" -gt "480" ] || [ "$density" -ge "640" ]; then
      lcd_dpi="xxxhdpi"  # Extra Extra Extra High Density
    else
      lcd_dpi="*dpi"
    fi
  elif [ $RipDpi -eq 0 ]; then
    lcd_dpi="*dpi"
  fi
}; ripDpiGen

# --- Method to Generate ripLib arg ---
ripLibGen() {
  if [ $RipLib -eq 1 ]; then
    all_arch="arm64-v8a armeabi-v7a x86_64 x86"  # all ABIs
    # Generate ripLib arguments for all ABIs EXCEPT the device ABI
    ripLib=""
    stripLibs="--striplibs=$cpuAbi"
    for current_arch in $all_arch; do
      if [ "$current_arch" != "$cpuAbi" ]; then
        if [ -z "$ripLib" ]; then
          ripLib="--rip-lib=$current_arch"  # No leading space for first item
        else
          ripLib="$ripLib --rip-lib=$current_arch"  # Add space for subsequent items
        fi
      fi
    done
  else
    ripLib=""  # If RipLib is not enabled, set ripLib to an empty string
    stripLibs=""
  fi
}; ripLibGen  # Call ripLibGen function to generate ripLib args

genPMCmd() {
  InstallPackageFor=$(jq -r '.InstallPackageFor' "$simplifyJson" 2>/dev/null)
  KeepsData=$(jq -r '.KeepsData' "$simplifyJson" 2>/dev/null)
  GrantAllRuntimePermissions=$(jq -r '.GrantAllRuntimePermissions' "$simplifyJson" 2>/dev/null)
  InstalledAsTestOnly=$(jq -r '.InstalledAsTestOnly' "$simplifyJson" 2>/dev/null)
  BypassLowTargetSdkBolck=$(jq -r '.BypassLowTargetSdkBolck' "$simplifyJson" 2>/dev/null)
  DisablePlayProtect=$(jq -r '.DisablePlayProtect' "$simplifyJson" 2>/dev/null)
  DisableVerifyAdbInstalls=$(jq -r '.DisableVerifyAdbInstalls' "$simplifyJson" 2>/dev/null)
  Installer=$(jq -r '.Installer' "$simplifyJson" 2>/dev/null)
  Reinstall=$(jq -r '.Reinstall' "$simplifyJson" 2>/dev/null)
  EnableRoolback=$(jq -r '.EnableRoolback' "$simplifyJson" 2>/dev/null)
  
  [ $InstallPackageFor -eq 0 ] && pmCmd="--user $(am get-current-user)" || pmCmd="--user all"
  [ $GrantAllRuntimePermissions -eq 1 ] && pmCmd+=" -g"
  [ $InstalledAsTestOnly -eq 1 ] && pmCmd+=" -t"
  [ $BypassLowTargetSdkBolck -eq 1 ] && pmCmd+=" --bypass-low-target-sdk-block"
  case "$Installer" in
    "com.android.vending") pmCmd+=" -i com.android.vending" ;;
    "com.android.packageinstaller") pmCmd+=" -i com.android.packageinstaller" ;;
    "com.android.shell") pmCmd+=" -i com.android.shell" ;;
    "adb") pmCmd+=" -i adb" ;;
  esac
  [ $Reinstall -eq 1 ] && pmCmd+=" -r"
  [ $EnableRoolback -eq 1 ] && pmCmd+=" --enable-rollback"
}; genPMCmd

if [ -f "$HOME/.config/gh/hosts.yml" ] && gh auth status > /dev/null 2>&1; then
  token="$(gh auth token)"  # oauth_token: gho_************************************
elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
  token="$(jq -r '.PAT' "$simplifyJson" 2>/dev/null)"  # PAT: ghp_************************************
fi
[ -n "$token" ] && auth="-H \"Authorization: Bearer $token\"" || auth=""

su -c "id" >/dev/null 2>&1 && su=1 || su=0
[ $su -eq 1 ] && Serial=$(su -c 'getprop ro.serialno')  # Get Serial Number required root

clear && echo -e "🚀 ${Yellow}Please wait! starting simplify...${Reset}"

pkg update > /dev/null 2>&1 || apt update >/dev/null 2>&1  # It downloads latest package list with versions from Termux remote repository, then compares them to local (installed) pkg versions, and shows a list of what can be upgraded if they are different.
outdatedPKG=$(apt list --upgradable 2>/dev/null)  # list of outdated pkg
echo "$outdatedPKG" | grep -q "dpkg was interrupted" 2>/dev/null && { yes "N" | dpkg --configure -a; outdatedPKG=$(apt list --upgradable 2>/dev/null); }
installedPKG=$(pkg list-installed 2>/dev/null)  # list of installed pkg

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
if [ $Android -eq 6 ] && [ ! -f "$HOME/.termux/termux.properties" ]; then
  mkdir -p "$HOME/.termux" && echo "allow-external-apps = true" > "$HOME/.termux/termux.properties"
  isOverwriteTermuxProp=1
  echo -e "$notice 'termux.properties' file has been created successfully & 'allow-external-apps = true' line has been add (enabled) in Termux \$HOME/.termux/termux.properties."
  termux-reload-settings
elif [ $Android -eq 6 ] && [ -f "$HOME/.termux/termux.properties" ]; then
  if grep -q "^# allow-external-apps" "$HOME/.termux/termux.properties"; then
    sed -i '/allow-external-apps/s/# //' "$HOME/.termux/termux.properties"  # uncomment 'allow-external-apps = true' line
    isOverwriteTermuxProp=1
    echo -e "$notice 'allow-external-apps = true' line has been uncommented (enabled) in Termux \$HOME/.termux/termux.properties."
    termux-reload-settings
  fi
fi
if [ "$Android" -ge 6 ]; then
  if grep -q "^# allow-external-apps" "$HOME/.termux/termux.properties"; then
    # other Android applications can send commands into Termux.
    # termux-open utility can send an Android Intent from Termux to Android system to open apk package file in pm.
    # other Android applications also can be Access Termux app data (files).
    sed -i '/allow-external-apps/s/# //' "$HOME/.termux/termux.properties"  # uncomment 'allow-external-apps = true' line
    isOverwriteTermuxProp=1
    echo -e "$notice 'allow-external-apps = true' line has been uncommented (enabled) in Termux \$HOME/.termux/termux.properties."
    #if [ "$Android" -eq 7 ] || [ "$Android" -eq 6 ]; then
      termux-reload-settings  # reload (restart) Termux settings required for Android 6 after enabled allow-external-apps, also required for Android 7 due to 'Package installer has stopped' err
    #fi
  fi
fi

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
    output=$(yes "N" | apt install --only-upgrade "$pkg" -y 2>/dev/null)
    echo "$output" | grep -q "dpkg was interrupted" 2>/dev/null && { yes "N" | dpkg --configure -a; yes "N" | apt install --only-upgrade "$pkg" -y > /dev/null 2>&1; }
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
pkgInstall "libgnutls"  # pm apt & dpkg use it to securely download packages from repositories over HTTPS
pkgInstall "coreutils"  # It provides basic file, shell, & text manipulation utilities. such as: ls, cp, mv, rm, mkdir, cat, echo, etc.
pkgInstall "termux-core"  # it's contains basic essential cli utilities, such as: ls, cp, mv, rm, mkdir, cat, echo, etc.
pkgInstall "termux-tools"  # it's provide essential commands, sush as: termux-change-repo, termux-setup-storage, termux-open, termux-share, etc.
pkgInstall "termux-keyring"  # it's use during pkg install/update to verify digital signature of the pkg and remote repository
pkgInstall "termux-am"  # termux am (activity manager) update
pkgInstall "termux-am-socket"  # termux am socket (when run: am start -n activity ,termux-am take & send to termux-am-stcket and it's send to Termux Core to execute am command) update
pkgInstall "inetutils"  # ping utils is provided by inetutils
pkgInstall "util-linux"  # it provides: kill, killall, uptime, uname, chsh, lscpu
pkgInstall "libsmartcols"  # a library from the util-linux pkg
pkgInstall "curl"  # curl update
pkgInstall "libcurl"  # curl lib update
pkgInstall "openssl"  # openssl install/update
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
if [ $su -eq 0 ] && { [ ! -f "$HOME/rish" ] || [ ! -f "$HOME/rish_shizuku.dex" ]; }; then
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

# --- Download and give execute (--x) permission to AAPT2 Binary ---
if [ ! -f "$HOME/aapt2" ]; then
  echo -e "$running Downloading aapt2 binary from GitHub.."
  curl -sL "https://github.com/arghya339/aapt2/releases/download/all/aapt2_$cpuAbi" --progress-bar -o "$HOME/aapt2" && chmod +x "$HOME/aapt2"
fi

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlGitHub.sh" --progress-bar -o $Simplify/dlGitHub.sh

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/APKMdl.sh" --progress-bar -o $Simplify/APKMdl.sh
source $Simplify/APKMdl.sh

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlUptodown.sh" --progress-bar -o $Simplify/dlUptodown.sh

curl -sL -o $Simplify/dlAPKPure.sh "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlAPKPure.sh"

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkInstall.sh" --progress-bar -o $Simplify/apkInstall.sh
source $Simplify/apkInstall.sh

[ $su -eq 1 ] && curl -sL -o "$Simplify/apkMount.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkMount.sh"

if [ $su -eq 1 ] || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | cut -f1) shell "id" >/dev/null 2>&1; then
  if [ -n "$(find $POST_INSTALL -mindepth 1 -type f -o -type d -o -type l 2>/dev/null)" ]; then
    file_path=$(find $POST_INSTALL -maxdepth 1 -type f -print -quit)
    apkInstall "$file_path" "" && rm -f "$file_path"
  fi
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
    apkInstall "$Widget" ""  # Install Termux:Widget app using apkInstall.sh
    [ -f "$Widget" ] && rm -f "$Widget"  # if Termux:Widget app package exist then remove it 
  fi
  if [ $su -eq 1 ]; then
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
branding() {
  base=${1:-branding}
  ([ ! -d "$SimplUsr/.$base" ] && [ ! -f "$SimplUsr/$base.zip" ]) && curl -L -C - --progress-bar -o "$SimplUsr/$base.zip" "https://github.com/arghya339/Simplify/releases/download/all/$base.zip"
  if [ -f "$SimplUsr/$base.zip" ] && [ ! -d "$SimplUsr/.$base" ]; then
    echo -e "$running Extrcting ${Red}$base.zip${Reset} to $SimplUsr dir.."
    pv "$SimplUsr/$base.zip" | bsdtar -xof - -C "$SimplUsr/" --no-same-owner --no-same-permissions
    mv "$SimplUsr/$base" "$SimplUsr/.$base"  # Rename branding dir to .branding to hide it from file Gallery
  fi
  ([ -d "$SimplUsr/.$base" ] && [ -f "$SimplUsr/$base.zip" ]) && rm -f "$SimplUsr/$base.zip"
}

# --- Create a ks.keystore for Signing apk ---
if [ ! -f "$Simplify/ks.keystore" ]; then
  echo -e "$running Create a 'ks.keystore' for Signing apk.."
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -genkey -v -storetype pkcs12 -keystore $Simplify/ks.keystore -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -list -v -keystore $Simplify/ks.keystore -storepass 123456 | grep -oP '(?<=Owner:).*' | xargs
fi

confirmPrompt() {
  Prompt=${1}
  local -n prompt_buttons=$2
  Selected=${3:-0}  # :- set value as 0 if unset
  [[ "$Selected" =~ ^(0|true|on|enable)$ ]] && Selected=0 || Selected=1
  
  # breaks long prompts into multiple lines
  mapfile -t lines < <(fmt -w "$cols" <<< "$Prompt")
  
  # print all-lines except last-line
  last_line_index=$(( ${#lines[@]} - 1 ))  # ${#lines[@]} = number of elements in lines array
  for (( i=0; i<last_line_index; i++ )); do
    echo -e "${lines[i]}"
  done
  
  last_line="${lines[$last_line_index]}"
  llcc=${#last_line}
  bcc=$((${#prompt_buttons[0]} + ${#prompt_buttons[1]}))
  pbcc=$((bcc + 8))
  
  [ $((cols - llcc)) -ge $pbcc ] && fits_on_last=true || { fits_on_last=false; echo -e "$last_line"; }
  
  echo -ne '\033[?25l'  # Hide cursor
  while true; do
    show_prompt() {
      echo -ne "\r\033[K"  # n=noNewLine r=returnCursorToStartOfLine \033[K=clearLine
      [ $fits_on_last == true ] && echo -ne "$last_line "
      if [ ${#prompt_buttons[@]} -eq 2 ]; then
        [ $Selected -eq 0 ] && echo -ne "${whiteBG}➤ ${prompt_buttons[0]} $Reset   ${prompt_buttons[1]}" || echo -ne "  ${prompt_buttons[0]}  ${whiteBG}➤ ${prompt_buttons[1]} $Reset"  # highlight selected bt with white bg
      elif [ ${#prompt_buttons[@]} -eq 3 ]; then
        if [ $Selected -eq 0 ]; then
          echo -ne "${whiteBG}➤ ${prompt_buttons[0]} $Reset   ${prompt_buttons[1]}    ${prompt_buttons[2]}"
        elif [ $Selected -eq 1 ]; then
          echo -ne "  ${prompt_buttons[0]}  ${whiteBG}➤ ${prompt_buttons[1]} $Reset   ${prompt_buttons[2]}"
        elif [ $Selected -eq 2 ]; then
          echo -ne "  ${prompt_buttons[0]}    ${prompt_buttons[1]}  ${whiteBG}➤ ${prompt_buttons[2]} $Reset"
        fi
      fi
    }; show_prompt

    read -rsn1 key
    case $key in
      $'\E')
      # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
        read -rsn2 -t 0.1 key2  # -r=readRawInput -s=silent(noOutput) -t=timeout -n2=readTwoChar | waits upto 0.1s=100ms to read key 
        case $key2 in 
          '[C')  # right arrow key
            Selected=$((Selected + 1))
            [ $Selected -gt ${#prompt_buttons[@]} ] && Selected=$((${#prompt_buttons[@]} - 1))
            ;;
          '[D')  # left arrow key
            Selected=$((Selected - 1))
            [ $Selected -lt 0 ] && Selected=0
            ;;
        esac
        ;;
      [Yy]*|[Ii]*) Selected=0; show_prompt; break ;;
      [Nn]*|[Mm]*) Selected=1; show_prompt; break ;;
      [Cc]*) Selected=2; show_prompt; break ;;
      "") break ;;  # Enter key
    esac
  done
  echo -e '\033[?25h' # Show cursor
  return $Selected  # return Selected int index from this fun
}

tfConfig() {
  local tfKey=${1}
  local defaultValue=$2
  local m1=${3}
  local m2=${4}
  [ $defaultValue -eq 0 ] && defaultValue=1 || defaultValue=0  # if defaultValue=0 then Select button1 (False) else Select button0 (True) 

    buttons=("<True>" "<False>"); confirmPrompt "$tfKey" "buttons" "$defaultValue" && opt=True || opt=False
    case "$opt" in
      [Tt]*)
        config "$tfKey" "1"
        echo -e "$good ${Green}$tfKey is True! $m1.${Reset}"
        ;;
      [Ff]*)
        config "$tfKey" "0"
        echo -e "$good ${Green}$tfKey is False! $m2.${Reset}"
        ;;
    esac
}

token() {
  echo -e "${running} Creating Personal Access Token.."
  termux-open-url "https://github.com/settings/tokens/new?scopes=public_repo&description=Simplify"  # Create a PAT with scope `public_repo`
  echo -n "PAT: "  # Display prompt
  # Read characters one by one
  while IFS= read -rsn 1 char; do
    # Handle Enter key (newline)
    if [[ "$char" == $'\0' || "$char" == $'\n' || "$char" == $'\r' ]]; then
      # Only break if input is not empty, input not start with space, input doesn't contain space & pat is valid
      if [[ -n "$input" && ! "$input" =~ ^[[:space:]] && ! "$input" =~ [[:space:]] ]]; then
        curl -sL -f -H "Authorization: Bearer ${input}" "https://api.github.com/repos/ReVanced/revanced-patches/releases/latest" | jq -r '.tag_name'
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
          echo -e "\n$good ${Green}Successfully added your GitHub PAT!${Reset}"
          echo -e "$notice ${Yellow}Your GitHub API rate limit has been increased.${Reset}"
          break
        else
          echo -ne "\r\033[K"  # Clear previous prompt line
          echo -e "$notice ${Yellow}Invalid PAT!${Reset}"  # Display messages if pat is not valid
          input=""  # Clear input variable's value
          echo -n "PAT: "  # Display prompt
        fi
      else
        continue
      fi
    fi
    # Handle backspace ($'\177')
    if [[ "$char" == $'\177' ]]; then
      if [ -n "$input" ]; then
        input="${input%?}"  # Remove last char from input & store in input
        echo -ne "\b \b"  # Move cursor back, print space, move cursor back again
      fi
      continue
    fi
    # Handle delete ($'\E[3~')
    # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
    if [[ "$char" == $'\E' ]]; then
      read -rsn1 -t 0.1 seq1
      if [[ "$seq1" == '[' ]]; then
        read -rsn2 -t 0.1 seq2
        case "$seq2" in
          '3~')  # Delete key
            if [ -n "$input" ]; then
              input="${input%?}"
              echo -ne "\b \b"
            fi
            ;;
        esac
      fi
      continue
    fi
    # Only add printable characters (excluding control characters)
    if [[ "$char" =~ [[:print:]] ]]; then
      input+="$char"  # Add character to input
      echo -n "*"  # Display asterisk
    fi
  done
  config "PAT" "$input"
}

pat() {
  while true; do
    if { [ -f "$HOME/.config/gh/hosts.yml" ] && ! grep -q "{}" "$HOME/.config/gh/hosts.yml" 2>/dev/null; } || { [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; }; then
      buttons=("<Yes>" "<No>"); confirmPrompt "You already have a GitHub token! Do you want to delete it?" "buttons" "1" && userInput=Yes || userInput=No
      case "$userInput" in
        [Yy]*)
          if { [ -f "$HOME/.config/gh/hosts.yml" ] && ! grep -q "{}" "$HOME/.config/gh/hosts.yml" 2>/dev/null; } || gh auth status 2>/dev/null; then
            gh auth logout  # Logout from gh cli
            termux-open-url "https://github.com/settings/applications"
          elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
            jq 'del(.PAT)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete PAT key from simplify.json
            termux-open-url "https://github.com/settings/tokens"
          fi
          echo -e "$good ${Green}Successfully deleted your GitHub token!${Reset}"
          ;;
        [Nn]*) break ;;
      esac
    else
      buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to increase the GitHub API rate limit by adding a github token?" "buttons" && userInput=Yes || userInput=No
      case "$userInput" in
        [Yy]*)
          buttons=("<GH>" "<PAT>"); confirmPrompt "Select a method to create a GitHub access token: (GH) GitHub CLI or (PAT) Personal Access Token?" "buttons" "1" && method=GH || method=PAT
          case "$method" in
            [Gg]*)
              pkgInstall "gh"  # gh install/update
              echo -e "${running} Creating GitHub access token using GitHub CLI.."
              gh auth login  # Authenticate gh cli with GitHub account
              gh api "repos/ReVanced/revanced-patches/releases/latest" | cat | jq -r '.tag_name'
              if [ ${PIPESTATUS[0]} -eq 0 ]; then
                echo -e "$good ${Green}Successfully authenticated with GitHub CLI!${Reset}"
                echo -e "$notice ${Yellow}Your GitHub API rate limit has been increased.${Reset}"
                break
              else
                echo -e "${bad} ${Red}Failed to authenticate with GitHub CLI! Please try again.${Reset}"
                gh auth logout  # Logout from gh cli
              fi
              ;;
            [Pp]*)
              token  # Call token functions to add pat
              break
              ;;
          esac
          ;;
        [Nn]*) break ;;
      esac
    fi
  done
}

if [ $CheckTermuxUpdate -eq 1 ]; then
  if [ $Android -ge 8 ]; then
    latestReleases=$(curl -s https://api.github.com/repos/termux/termux-app/releases/latest | jq -r '.tag_name | sub("^v"; "")')  # 0.118.0
    dlUrl="https://github.com/termux/termux-app/releases/download/v$latestReleases/termux-app_v${latestReleases}+github-debug_$cpuAbi.apk"
    fileName="termux-app_v${latestReleases}+github-debug_$cpuAbi.apk"
    filePath="$SimplUsr/$fileName"
  else
    if [ $Android -eq 7 ]; then
      latestReleases=$(curl -s https://api.github.com/repos/termux/termux-app/tags | jq -r '.[0].name | sub("^v"; "")')  # 0.119.0-beta.2
      variant=7
    else
      #oniguruma library (that provides sub related functions) unavailable in precompiled jq binary
      latestReleases=$(curl -s https://api.github.com/repos/termux/termux-app/tags | jq -r '.[0].name' | sed 's/^v//')  # 0.119.0-beta.2
      variant=5
    fi
    dlUrl="https://github.com/termux/termux-app/releases/download/v$latestReleases/termux-app_v${latestReleases}+apt-android-$variant-github-debug_$cpuAbi.apk"
    fileName="termux-app_v${latestReleases}+apt-android-$variant-github-debug_$cpuAbi.apk"
    filePath="$SimplUsr/$fileName"
  fi
  if [ "$TERMUX_VERSION" != "$latestReleases" ]; then
    echo -e "$bad Termux app is outdated!"
    echo -e "$running Downloading Termux app update.."
    while true; do
      curl -L --progress-bar -C - -o "$filePath" "$dlUrl"
      [ $? -eq 0 ] && break || { echo -e "$notice Retrying in 5 seconds.."; sleep 5; }
    done
    echo -e "$notice Please rerun this script again after Termux app update!"
    echo -e "$running Installing app update and restarting Termux app.." && sleep 3
    if [ $su -eq 1 ]; then
      su -c "cp '$filePath' '/data/local/tmp/$fileName'"
      if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
        su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
        su -c 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
        su -c "cmd deviceidle whitelist +com.termux" >/dev/null 2>&1
        touch "$Simplify/setenforce0"
        su -c "pm install -i com.android.vending '/data/local/tmp/$fileName'"
      else
        su -c 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
        su -c "cmd deviceidle whitelist +com.termux" >/dev/null 2>&1
        su -c "pm install -i com.android.vending '/data/local/tmp/$fileName'"
      fi
    else
      if "$HOME/rish" -c "id" >/dev/null 2>&1; then
        $HOME/rish -c 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
        $HOME/rish -c "cmd deviceidle whitelist +com.termux" >/dev/null 2>&1
        $HOME/rish -c "cmd appops set com.termux REQUEST_INSTALL_PACKAGES allow"
      elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
        ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "pm grant com.termux android.permission.POST_NOTIFICATIONS"
        ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "cmd deviceidle whitelist +com.termux" >/dev/null 2>&1
        ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "cmd appops set com.termux REQUEST_INSTALL_PACKAGES allow"
      else
        echo -e "$info Please Disabled: ${Green}Battery optimization → Not optimized → All apps → Termux → Don't optiomize → DONE${Reset}" && sleep 6
        am start -n com.android.settings/.Settings\$HighPowerApplicationsActivity &> /dev/null
        echo -e "$info Please Allow: ${Green}Install unknown apps → Termux → Allow from this source${Reset}" && sleep 6
        am start -n com.android.settings/.Settings\$ManageExternalSourcesActivity &> /dev/null
      fi
      apkInstall "$filePath" "com.termux/.app.TermuxActivity"
    fi
  else
    if [ -f "$filePath" ]; then
      if [ $su -eq 1 ]; then
        if [ "$(su -c 'getenforce 2>/dev/null')" = "Permissive" ] && [ -f "$Simplify/setenforce0" ]; then
          su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
          rm -f "$Simplify/setenforce0"
        fi
        su -c "rm -f '/data/local/tmp/$fileName'"
      elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
        ~/rish -c "rm -f '/data/local/tmp/$fileName'"
      elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
        ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "rm -f '/data/local/tmp/$fileName'"
      fi
      rm -f "$filePath"
    fi
  fi
fi

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
        jq -e 'del(.AndroidVersion)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete AndroidVersion key from simplify.json
        echo -e "$good ${Green}Android version spoofing disabled successfully!${Reset}"
        Android=$(getprop ro.build.version.release | cut -d. -f1)
        break
      elif [ $spoofVersion -lt 4 ]; then
        echo -e "$notice Android version $spoofVersion is not supported by ReVanced patches! Please enter a valid version that is <= 4."
      elif [ $spoofVersion -ge 4 ]; then
        config "AndroidVersion" "$spoofVersion"
        echo -e "$good ${Green}Android version spoofed to $spoofVersion successfully!${Reset}"
        Android=$(jq -r '.AndroidVersion' "$simplifyJson" 2>/dev/null)
        break
      fi
    else
      echo -e "$info Invalid Android version format! Please enter a valid version."
    fi
  done
}

menu() {
  local -n menu_options=$1
  local -n menu_buttons=$2
  items_per_page=$((rows - (7 + 7)))
  
  selected_option=0
  selected_button=0
  
  current_page=0
  total_pages=$(( (${#menu_options[@]} + items_per_page - 1) / items_per_page ))  # Convert to integer from floating point page number

  show_menu() {
    printf '\033[2J\033[3J\033[H'
    echo -e "${BoldGreen}$print_simplify${Reset}" && echo
    # Display guide
    echo -n "Navigate with [↑] [↓] [←] [→]"
    [ $total_pages -gt 1 ] && echo -n " [PGUP] [PGDN]"
    echo -e "\nSelect with [↵]\n"
    
    # Calculate start and end indices for current page
    start_index=$(( current_page * items_per_page ))
    end_index=$(( start_index + (items_per_page - 1) ))
    [ $end_index -ge ${#menu_options[@]} ] && end_index=$((${#menu_options[@]} - 1))
    
    # Display menu options for current page
    for ((i=start_index; i<=end_index; i++)); do
      if [ $i -eq $selected_option ]; then
        echo -e "${whiteBG}➤ ${menu_options[$i]} $Reset"
      else
        [ $(($i + 1)) -le 9 ] && echo " $(($i + 1)). ${menu_options[$i]}" || echo "$(($i + 1)). ${menu_options[$i]}"
      fi
    done
    
    for ((i=end_index+1; i < start_index + items_per_page; i++)); do echo; done  # Fill remaining lines if current page has fewer than items/page options
    
    [ $total_pages -gt 1 ] && echo -e "\nPage: $((current_page + 1))/$total_pages\n" || echo  # Display page info if multiple pages exist
    
    # Display buttons
    for ((i=0; i<=$((${#menu_buttons[@]} - 1)); i++)); do
      if [ $i -eq $selected_button ]; then
        [ $i -eq 0 ] && echo -ne "${whiteBG}➤ ${menu_buttons[$i]} $Reset" || echo -ne "  ${whiteBG}➤ ${menu_buttons[$i]} $Reset"
      else
        [ $i -eq 0 ] && echo -n "  ${menu_buttons[$i]}" || echo -n "   ${menu_buttons[$i]}"
      fi
    done
  }

  printf '\033[?25l'
  while true; do
    show_menu
    read -rsn1 key
    case $key in
      $'\E')  # ESC
        # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
        read -rsn2 -t 0.1 key2
        case "$key2" in
          '[A')  # Up arrow
            selected_option=$((selected_option - 1))
            [ $selected_option -lt 0 ] && selected_option=$((${#menu_options[@]} - 1))
            current_page=$((selected_option / items_per_page))  # Auto switch page
            ;;
          '[B')  # Down arrow
            selected_option=$((selected_option + 1))
            [ $selected_option -ge ${#menu_options[@]} ] && selected_option=0
            current_page=$((selected_option / items_per_page))  # Auto switch page
            ;;
          '[C')  # Right arrow
            [ $selected_button -lt $((${#menu_buttons[@]} - 1)) ] && selected_button=$((selected_button + 1))
            ;;
          '[D')  # Left arrow
            [ $selected_button -gt 0 ] && selected_button=$((selected_button - 1))
            ;;
          '[5') # Page Up
            read -rsn1 -t 0.1 key3
            if [ "$key3" == "~" ]; then
              current_page=$((current_page - 1))
              [ $current_page -lt 0 ] && current_page=$((total_pages - 1))
              selected_option=$((current_page * items_per_page))  # Update selected option to start indices on new page
            fi
            ;;
          '[6') # Page Down
            read -rsn1 -t 0.1 key3
            if [ "$key3" == "~" ]; then
              current_page=$((current_page + 1))
              [ $current_page -ge $total_pages ] && current_page=0
              selected_option=$((current_page * items_per_page))  # Update selected option to start indices on new page
            fi
            ;;
        esac
        ;;
      '')  # Enter key
        break
        ;;
      [0-9])
        read -rsn2 -t0.5 key2
        [[ "$key2" == [0-9] ]] && { key="${key}${key2}"; key=$((10#$key)); }  # Convert to integer (decimal) from strings
        if [ $key -eq 0 ]; then
          selected_option=$((${#menu_options[@]} - 1))
        elif [ $key -gt ${#menu_options[@]} ]; then
          selected_option=0
        else
          selected_option=$(($key - 1))
        fi
        current_page=$((selected_option / items_per_page))  # Auto switch page
        show_menu; sleep 0.5; break
       ;;
    esac
  done
  printf '\033[?25h'

  [ $selected_button -eq 0 ] && { printf '\033[2J\033[3J\033[H'; selected=$selected_option; }
  if [ $selected_button -eq $((${#menu_buttons[@]} - 1)) ]; then
    [ "${menu_buttons[$((${#menu_buttons[@]} - 1))]}" == "<Back>" ] && { printf '\033[2J\033[3J\033[H'; return 1; } || { [ $isOverwriteTermuxProp -eq 1 ] && sed -i '/allow-external-apps/s/^/# /' "$HOME/.termux/termux.properties"; printf '\033[2J\033[3J\033[H'; echo "Script exited !!"; exit 0; }
  fi
}

overwriteArch() {
  if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
    cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
    echo -e "$info Device architecture spoofed to $cpuAbi!"
  else
    echo -e "$info Device architecture not spoofed yet!"
  fi
  sleep 1
  opt=(Disabled\ Arch\ spoofing arm64-v8a armeabi-v7a x86_64 x86); buttons=("<Select>" "<Back>"); if menu opt buttons; then arch="${opt[$selected]}"; fi
  if [ -n "$arch" ]; then
    case "$arch" in
      Disabled\ Arch\ spoofing)
        jq -e 'del(.DeviceArch)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete DeviceArch key from simplify.json
        echo -e "$good ${Green}Device architecture spoofing disabled successfully!${Reset}"
        ;;
      arm64-v8a)
        config "DeviceArch" "arm64-v8a"
        echo -e "$good ${Green}Device architecture spoofed to arm64-v8a successfully!${Reset}"
        ;;
      armeabi-v7a)
        config "DeviceArch" "armeabi-v7a"
        echo -e "$good ${Green}Device architecture spoofed to armeabi-v7a successfully!${Reset}"
        ;;
      x86_64)
        config "DeviceArch" "x86_64"
        echo -e "$good ${Green}Device architecture spoofed to x86_64 successfully!${Reset}"
        ;;
      x86)
        config "DeviceArch" "x86"
        echo -e "$good ${Green}Device architecture spoofed to x86 successfully!${Reset}"
        ;;
    esac
    cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)
  else
    cpuAbi=$(getprop ro.product.cpu.abi)
  fi
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
    buttons=("<Select>" "<Back>"); if menu nameArr buttons; then selected=$selected; else break; fi
    
    # Process selection
    if [ -n "$selected" ] && [[ "$selected" == [0-9] ]]; then
      if [ $su -eq 1 ]; then
        echo "$running Uninstalling ${nameArr[$selected]}.."
        if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
          su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
          su -c "pm uninstall --user 0 ${pkgArr[$selected]}"
          su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
        else
          su -c "pm uninstall --user 0 ${pkgArr[$selected]}"
        fi
      elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
        echo "$running Uninstalling ${nameArr[$selected]}.."
        ~/rish -c "pm uninstall --user 0 ${pkgArr[$selected]}"
      else
        #am start -a android.intent.action.DELETE -d package:"${pkgArr[$selected]}" > /dev/null 2>&1
        am start -a android.intent.action.UNINSTALL_PACKAGE -d package:"${pkgArr[$selected]}" > /dev/null 2>&1
        sleep 6  # wait 6 seconds
        #echo "Opening App info Activity for: ${nameArr[selected]}"
        am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:"${pkgArr[$selected]}" > /dev/null 2>&1
      fi
    fi

  done
}

Unmount() {
  pkgArr=("com.google.android.youtube" "com.google.android.apps.youtube.music" "com.google.android.apps.photos" "com.spotify.music")
  nameArr=("YouTube" "YouTube Music" "Google Photos" "Spotify")
    
  while true; do
    # Build available apps list
    nameList=()
    index=0
    
    # Check which apps are available for unmounting
    for i in "${!pkgArr[@]}"; do 
      if su -c "[ -e '/data/adb/revanced/${pkgArr[$i]}/' ]" 2>/dev/null; then
        nameList[$index]="${nameArr[$i]}"
        ((index++))
      fi
    done
    
    [ ${#nameList[@]} -eq 0 ] && { echo -e "$info No mounted apps available to unmount!"; break; }  # Exit if no apps available

    # Get Selection
    buttons=("<Select>" "<Back>")
    if menu nameList buttons; then 
      selected="${nameList[$selected]}"
            
      # Process selection
      for i in "${!nameArr[@]}"; do
        if [ "${nameArr[$i]}" = "$selected" ]; then
          echo -e "$running Unmounting ${nameArr[$i]}..."
          su -c "/system/bin/sh /data/adb/revanced/${pkgArr[$i]}/${pkgArr[$i]}.sh" 2>/dev/null
          echo -e "$good ${Green}Successfully unmounted ${nameArr[$i]}!${Reset}"
          break
        fi
      done
    else 
      break
    fi
  done
}

# --- Check if CorePatch Installed ---
checkCoreLSPosed() {
  if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
    su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
    LSPosedPkg=$(su -c "pm list packages | grep org.lsposed.manager" 2>/dev/null)  # LSPosed packages list
    CorePatchPkg=$(su -c "pm list packages | grep com.coderstory.toolkit" 2>/dev/null)  # CorePatch packages list
    su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
  else
    LSPosedPkg=$(su -c "pm list packages | grep 'org.lsposed.manager'" 2>/dev/null)  # LSPosed packages list
    CorePatchPkg=$(su -c "pm list packages | grep 'com.coderstory.toolkit'" 2>/dev/null)  # CorePatch packages list
  fi

  if [ -z $LSPosedPkg ]; then
    echo -e "$info Please install LSPosed Manager by flashing LSPosed Zyzisk Module from Magisk. Then try again!"
    termux-open-url "https://github.com/JingMatrix/LSPosed/releases"
    return 1
  fi
  if [ -z $CorePatchPkg ]; then
    echo -e "$info Please install and Enable CorePatch LSPosed Module in System Framework. Then try again!"
    termux-open-url "https://github.com/LSPosed/CorePatch/releases"
    return 1
  fi
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
  options=(Download\ Patched\ App ReVanced ReVanced\ Extended)
  [ $Android -ge 8 ] && options+=(Morphe Piko\ Twitter)

  options+=(Dropped\ Patches LSPatch Configuration Miscellaneous Feature\ request Bug\ report Support About)
  buttons=("<Select>" "<Exit>")
  menu options buttons; selected="${options[$selected]}"
  case "$selected" in
    Download\ Patched\ App)
      curl -sL -o "$Simplify/dlPatchedApp.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlPatchedApp.sh"
      source "$Simplify/dlPatchedApp.sh"  # source = run in same shell environment (both scripts can share variables/functions both ways)
      ;;
    ReVanced)
      curl -sL -o "$RV/RV.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RV.sh"
      source "$RV/RV.sh"  # source = run in same shell environment (both scripts can share variables/functions both ways)
      ;;
    ReVanced\ Extended)
      curl -sL -o "$RVX/RVX.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RVX.sh"
      source "$RVX/RVX.sh"  # source = run in same shell environment (both scripts can share variables/functions both ways)
      ;;
    Morphe)
      curl -sL -o "$Morphe/Morphe.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/Morphe.sh"
      source "$Morphe/Morphe.sh"  # source = run in same shell environment (both scripts can share variables/functions both ways)
      ;;
    Piko\ Twitter)
      curl -sL -o "$pikoTwitter/pikoTwitter.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/pikoTwitter.sh"
      source "$pikoTwitter/pikoTwitter.sh"  # source = run in same shell environment (both scripts can share variables/functions both ways)
      ;;
    Dropped\ Patches)
      curl -sL -o "$Dropped/droppedPatches.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/droppedPatches.sh"
      source "$Dropped/droppedPatches.sh"  # source = run in same shell environment (both scripts can share variables/functions both ways)
      ;;
    LSPatch)
      curl -sL -o "$LSPatch/LSPatch.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/LSPatch.sh"
      source "$LSPatch/LSPatch.sh"  # source = run in same shell environment (both scripts can share variables/functions both ways)
      ;;
    Configuration)
      while true; do
        FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null)
        RipLocale="$(jq -r '.RipLocale' "$simplifyJson" 2>/dev/null)"
        RipDpi="$(jq -r '.RipDpi' "$simplifyJson" 2>/dev/null)"
        RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
        ChangeRVXSource="$(jq -r '.ChangeRVXSource' "$simplifyJson" 2>/dev/null)"
        ReadPatchesFile="$(jq -r '.ReadPatchesFile' "$simplifyJson" 2>/dev/null)"
        Branding=$(jq -r '.Branding' "$simplifyJson" 2>/dev/null)
        CheckTermuxUpdate=$(jq -r '.CheckTermuxUpdate' "$simplifyJson" 2>/dev/null)
        jdkVersion=$(jq -r '.openjdk' "$simplifyJson" 2>/dev/null)
        options=(FetchPreRelease RipLocale RipDpi RipLib Change\ RVX\ Source "Add gh PAT (increases gh api rate limit)" Import\ Custom\ PatchesOptions\ from\ file "Change YouTube & YT Music AppIcon & Header" Check\ Termux\ update\ on\ startup Change\ Java\ version)
        if [ $su -eq 1 ]; then
          options+=("SU Installation Options")
        elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
          options+=("SUI Installation Options")
        elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
          options+=("ADB Installation Options")
        fi
        if [ "$(getprop ro.product.manufacturer)" == "Genymobile" ] && ! "$HOME/adb" -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | awk '{print $1}') shell "id" >/dev/null 2>&1; then
          options+=(Pair\ ADB)
        fi
        buttons=("<Select>" "<Back>"); if menu options buttons; then selected="${options[$selected]}"; else break; fi
        case "$selected" in
          FetchPreRelease) if [ "$FetchPreRelease" == 0 ]; then echo "FetchPreRelease == false"; else echo "FetchPreRelease == true"; fi
            m1="Last Pre Release Patches will be fetched"
            m2="Latest Release Patches will be fetched"
            tfConfig "FetchPreRelease" "$isPreRelease" "$m1" "$m2"
            ;;
          RipLocale) if [ "$RipLocale" == 1 ]; then echo "RipLocale == true"; else echo "RipLocale == false"; fi
            m1="Device specific locale will be kept in patched apk file"
            m2="All locale will be kept in patched apk file"
            tfConfig "RipLocale" "$isRipLocale" "$m1" "$m2"
            ripLocaleGen
            ;;
          RipDpi) if [ "$RipDpi" == 1 ]; then echo "RipDpi == true"; else echo "RipDpi == false"; fi
            m1="Device specific dpi will be kept in patched apk file"
            m2="All dpi will be kept in patched apk file"
            tfConfig "RipDpi" "$isRipDpi" "$m1" "$m2"
            ripDpiGen
            ;;
          RipLib) if [ "$RipLib" == 1 ]; then echo "RipLib == true"; else echo "RipLib == false"; fi
            m1="Device specific arch lib will be kept in patched apk file"
            m2="All lib dir will be kept in patched apk file"
            tfConfig "RipLib" "$isRipLib" "$m1" "$m2"
            ripLibGen  # Call ripLibGen function
            ;;
          Change\ RVX\ Source) if [ "$ChangeRVXSource" == 0 ]; then echo "ChangeRVXSource == false"; else echo "ChangeRVXSource == true"; fi
            m1="RVX Patches source will be changed to forked (@anddea)"
            m2="RVX Patches source will remain official (@inotia00)"
            tfConfig "ChangeRVXSource" "$isChangeRVXSource" "$m1" "$m2"
            ;;
          "Add gh PAT (increases gh api rate limit)") 
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
          Import\ Custom\ PatchesOptions\ from\ file) if [ "$ReadPatchesFile" == 0 ]; then echo "ReadPatchesFile == false"; else echo "ReadPatchesFile == true"; fi
            m1="Custom PatchesOptions Loading from File"
            m2="Recommended PatchesOptions Loading from Script"
            tfConfig "ReadPatchesFile" "$isReadPatchesFile" "$m1" "$m2"
            ;;
          "Change YouTube & YT Music AppIcon & Header")
            echo "changeYouTubeYTMusicAppIconHeader == $Branding"
            options=(google_family pink vanced_light revancify_blue); buttons=("<Select>" "<Back>"); if menu options buttons; then selected="${options[$selected]}"; fi
            if [ -n "$selected" ]; then
              case "$selected" in
                [Gg]*)
                  branding="google_family"
                  config "Branding" "$branding"
                  echo -e "$good ${Green}appIconHeader successfully set to google_family!${Reset}"
                  ;;
                [Pp]*)
                  branding=pink
                  config "Branding" "$branding"
                  echo -e "$good ${Green}appIconHeader successfully set to pink!${Reset}"
                  ;;
                [Vv]*)
                  branding="vanced_light"
                  config "Branding" "$branding"
                  echo -e "$good ${Green}appIconHeader successfully set to vanced_light!${Reset}"
                  ;;
                [Rr]*)
                  branding="revancify_blue"
                  config "Branding" "$branding"
                  echo -e "$good ${Green}appIconHeader successfully set to revancify_blue!${Reset}"
                  ;;
              esac
            fi
            ;;
          Check\ Termux\ update\ on\ startup) if [ $CheckTermuxUpdate -eq 1 ]; then echo "CheckTermuxUpdate == true"; else echo "CheckTermuxUpdate == false"; fi
            m1="Check for Termux app updates on startup"
            m2="Never check for Termux app updates on startup"
            tfConfig "CheckTermuxUpdate" "$isCheckTermuxUpdate" "$m1" "$m2"
            ;;
          Change\ Java\ version)
            echo "openjdkVersion == $jdkVersion"
            # Get available JDK versions
            attempt=0
            while true; do
              jdkVersion=($(pkg search openjdk 2>&1 | grep -E "^openjdk-[0-9]+/" | awk -F'[-/ ]' '{print $2}'))
              [ $attempt -eq 7 ] && { echo -e "$notice Not found any java version in search result, after 7 attempts."; break; }
              [ ${#jdkVersion[@]} -ne 0 ] && break
              ((attempt++))
              sleep 0.5  # wait 500 milliseconds
            done
            # Select JDK versions
            buttons=("<Select>" "<Back>"); if menu jdkVersion buttons; then version="${jdkVersion[$selected]}"; fi
            # Set JDK versions
            if [ -n "$version" ]; then
              echo -e "$info Selected: openjdk-$version"
              config "openjdk" "$version"
              pkgInstall "openjdk-$version"  # java install/update
              echo -e "$good ${Green}Java version change successfully!${Reset}"
            fi
            ;;
          "SU Installation Options"|"SUI Installation Options"|"ADB Installation Options")
            while true; do
              genPMCmd
              options=("Install Package for *user" "Allow Downgrade with keeps App data (reboot required)" "Grant All Runtime/ Requested Permissions" Installed\ as\ test-only\ app Bypass\ Low\ Target\ SDK\ Bolck Disable\ Play\ Protect\ Package\ Verification Disable\ Verify\ Adb\ Installs Installer "Reinstall (Replace/ Upgrade) Existing Installed Package" Enable\ Version\ Roolback)
              buttons=("<Select>" "<Back>"); if menu options buttons; then selected="${options[$selected]}"; else break; fi
              case "$selected" in
                "Install Package for *user")
                  if [ "$InstallPackageFor" -eq 0 ]; then echo "InstallPackageFor == 0 (default-user)"; else echo "InstallPackageFor == 1 (all-users)"; fi
                  buttons=("<default-user>" "<all-users>"); confirmPrompt "InstallPackageFor" "buttons" "$isU" && u=default-user || u=all-users
                  if [ -n "$u" ]; then
                    case "$u" in
                      [Dd]*) config "InstallPackageFor" "0" && echo -e "$good ${Green}Install Package for default-user set successfully!${Reset}" ;;
                      [Aa]*) config "InstallPackageFor" "1" && echo -e "$good ${Green}Install Package for all-user set successfully!${Reset}" ;;
                    esac
                  fi
                  ;;
                "Allow Downgrade with keeps App data (reboot required)")
                  if [ "$KeepsData" -eq 0 ]; then echo "KeepsData == false"; else echo "KeepsData == true"; fi
                  m1="Allow Downgrade with keeps App data Enabled"
                  m2="Allow Downgrade with keeps App data Disabled"
                  tfConfig "KeepsData" "$isK" "$m1" "$m2"
                  ;;
                "Grant All Runtime/ Requested Permissions")
                  if [ "$GrantAllRuntimePermissions" -eq 0 ]; then echo "GrantAllRuntimePermissions == false"; else echo "GrantAllRuntimePermissions == true"; fi
                  m1="Grant All Runtime Permissions Enabled"
                  m2="Grant All Runtime Permissions Disabled"
                  tfConfig "GrantAllRuntimePermissions" "$isG" "$m1" "$m2"
                  ;;
                Installed\ as\ test-only\ app)
                  if [ "$InstalledAsTestOnly" -eq 0 ]; then echo "InstalledAsTestOnly == false"; else echo "InstalledAsTestOnly == true"; fi
                  m1="Installed as test-only Enabled"
                  m2="Installed as test-only Disabled"
                  tfConfig "InstalledAsTestOnly" "$isT" "$m1" "$m2"
                  ;;
                Bypass\ Low\ Target\ SDK\ Bolck)
                  if [ "$BypassLowTargetSdkBolck" -eq 1 ]; then echo "BypassLowTargetSdkBolck == true"; else echo "BypassLowTargetSdkBolck == false"; fi
                  m1="Bypass Low Target SDK Bolck Enabled"
                  m2="Bypass Low Target SDK Bolck Disabled"
                  tfConfig "BypassLowTargetSdkBolck" "$isL" "$m1" "$m2"
                  ;;
                Disable\ Play\ Protect\ Package\ Verification)
                  if [ "$DisablePlayProtect" -eq 1 ]; then echo "DisablePlayProtect == true"; else echo "DisablePlayProtect == false"; fi
                  m1="Play Protect Package Verification Disabled"
                  m2="Play Protect Package Verification Enabled"
                  tfConfig "DisablePlayProtect" "$isV" "$m1" "$m2"
                  ;;
                Disable\ Verify\ Adb\ Installs)
                  [ $DisableVerifyAdbInstalls -eq 1 ] && echo "DisableVerifyAdbInstalls == true" || echo "DisableVerifyAdbInstalls == false"
                  m1="Verify Adb Installs Disabled"; m2="Verify Adb Installs Enabled"; tfConfig "DisableVerifyAdbInstalls" "$isA" "$m1" "$m2"
                  ;;
                Installer)
                  case "$Installer" in
                    "com.android.vending") echo "Installer == com.android.vending (PlayStore)" ;;
                    "com.android.packageinstaller") echo "Installer == com.android.packageinstaller (PackageInstaller)" ;;
                    "com.android.shell") echo "Installer == com.android.shell (Shell)" ;;
                    "adb") echo "Installer == adb" ;;
                  esac
                  options=(Play\ Store Package\ Installer Shell ADB)
                  buttons=("<Select>" "<Back>"); if menu options buttons; then selected="${options[$selected]}"; fi
                  if [ -n "$selected" ]; then
                    case "$selected" in
                      Play\ Store) config "Installer" "com.android.vending" && echo -e "$good ${Green}Successfully set Installer as 'com.android.vending' (PlayStore)${Reset}" ;;
                      Package\ Installer) config "Installer" "com.android.packageinstaller" && echo -e "$good ${Green}Successfully set Installer as 'com.android.packageinstaller' (PackageInstaller)${Reset}" ;;
                      Shell) config "Installer" "com.android.shell" && echo -e "$good ${Green}Successfully set Installer as 'com.android.shell' (Shell)${Reset}" ;;
                      ADB) config "Installer" "adb" && echo -e "$good ${Green}Successfully set Installer as 'adb'${Reset}" ;;
                    esac
                  fi
                  ;;
                "Reinstall (Replace/ Upgrade) Existing Installed Package")
                  if [ "$Reinstall" -eq 1 ]; then echo "Reinstall == true"; else echo "Reinstall == false"; fi
                  m1="Reinstall Existing Installed Package Enabled"
                  m2="Reinstall Existing Installed Package Disabled"
                  tfConfig "Reinstall" "$isR" "$m1" "$m2"
                  ;;
                Enable\ Version\ Roolback)
                  if [ "$EnableRoolback" -eq 0 ]; then echo "EnableRoolback == false"; else echo "EnableRoolback == true"; fi
                  m1="Version Roolback Enabled"
                  m2="Version Roolback Disabled"
                  tfConfig "EnableRoolback" "$isB" "$m1" "$m2"
                  ;;
              esac
              echo; read -p "Press Enter to continue..."
            done
            ;;
          Pair\ ADB)
            echo -e "Enable Developer Options:\n  1. Open Settings app on your device\n  2. tap About Phone\n  3. Find & tap 7 times on Build Number\n  4. You may need to enter your lock screen password\n  >>You will see a toast message saying 'You are now a developer!'"
            echo -e "Enable Wireless Debugging:\n  1. Go back to main Settings screen\n  2. Scroll down & tap System\n  3. Tap Developer Options\n  4. Scroll down & find Wireless Debugging\n  5. Toggle it ON\n  6. A new dialog box will appear with a warning. Read it and tap Allow"
            echo -e "Pair Device with Pairing Code:\n  1. In Wireless Debugging menu, tap Pair device with pairing code. It will show you a IP address & port (e.g., 192.168.1.50:40435) and a 6-digit pairing code (e.g., 123456).\n  2. open Termux & enter [IP address:port] [Wi-Fi pairing code] (e.g., 192.168.1.50:40435 123456)\n"
            am start -n "com.android.settings/.Settings\$WirelessDebuggingActivity" >/dev/null 2>&1
            [ $? -ne 0 ] && am start -n "com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity" >/dev/null 2>&1 || am start -n com.android.settings/.Settings\$MyDeviceInfoActivity >/dev/null 2>&1
            read -r -p "HOST[:PORT] [PAIRING CODE] " input
            host_port=$(echo "$input" | awk '{print $1}'); pairing_code=$(echo "$input" | awk '{print $2}')
            ~/adb pair "$host_port" "$pairing_code"
            ;;
        esac
        echo; read -p "Press Enter to continue..."
      done
      ;;
    Miscellaneous)
      while true; do
        options=(Spoof\ Android\ Version Spoof\ Device\ Architecture Delete\ patched\ apk\ file Delete\ Patch\ Log Delete\ list-patches\ file Delete\ PatchesOption\ file Uninstall\ Patched\ Apps Uninstall\ Simplify)
        [ $su -eq 1 ] && options+=(Unmount\ Patched\ Apps)
        buttons=("<Select>" "<Back>"); if menu options buttons; then selected="${options[$selected]}"; else break; fi
        case "$selected" in
          Spoof\ Android\ Version) overwriteVersion ;;
          Spoof\ Device\ Architecture) overwriteArch ;;
          Delete\ patched\ apk\ file) DeletePatchedApk ;;
          Delete\ Patch\ Log) DeletePatchLog ;;
          Delete\ list-patches\ file) DeleteListPatches ;;
          Delete\ PatchesOption\ file) DeletePatchesOption ;;
          Uninstall\ Patched\ Apps) UninstallPatchedApp ;;
          Unmount\ Patched\ Apps) Unmount ;;
          Uninstall\ Simplify)
            buttons=("<Yes>" "<No>"); confirmPrompt "Are you sure you want to uninstall Simplify?" "buttons" "1" && userInput=Yes || userInput=No
            case "$userInput" in
              [Yy]*)
                echo -ne "${Red}Type 'yes' in capital to continue: ${Reset}" && read -r finalInput
                case "$finalInput" in
                  YES)
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
                    pip list | grep "apksigcopier" >/dev/null 2>&1 && pip uninstall apksigcopier -y > /dev/null 2>&1  # Uninstall apksigcopier using pip
                    pkgUninstall "python"  # python uninstall
                    pkgUninstall "bsdtar"  # bsdtar uninstall
                    pkgUninstall "pv"  # pv uninstall
                    pkgUninstall "glow"  # glow uninstall
                    if [ $su -eq 1 ]; then
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
        esac
        echo; read -p "Press Enter to continue..."
      done
      ;;
    Feature\ request) feature ;;
    Bug\ report) bug ;;
    Support) support ;;
    About) about ;;
  esac
  echo; read -p "Press Enter to continue..."
done
####################################################################################################################################################
