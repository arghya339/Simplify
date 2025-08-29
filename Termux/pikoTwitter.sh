#!/usr/bin/bash

# Colored log indicators
good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

# ANSI color code
Green="\033[92m"
BoldGreen="\033[92;1m"
Red="\033[91m"
Blue="\033[94m"
Cyan="\033[96m"
White="\033[37m"
Yellow="\033[93m"
Reset="\033[0m"

# --- Global Variables ---
Simplify="$HOME/Simplify"  # /data/data/com.termux/files/home/Simplify dir
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
if jq -e '.AndroidVersion != null' "$simplifyJson" >/dev/null 2>&1; then
  Android=$(jq -r '.AndroidVersion' "$simplifyJson" 2>/dev/null)  # Get Android version from json
else
  Android=$(getprop ro.build.version.release)  # Get Android version
fi
if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
  cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
else
  cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
fi
Model=$(getprop ro.product.model)  # Get Device Model
jdkVersion="21"
pikoTwitter="$Simplify/pikoTwitter"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$pikoTwitter" "$SimplUsr"  # Create $Simplify, $RV, $RVX and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir
FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null)
RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
if [ -f "$HOME/.config/gh/hosts.yml" ] && gh auth status > /dev/null 2>&1; then
  # oauth_token: gho_************************************
  token=$(grep -A2 "users:" ~/.config/gh/hosts.yml | grep -v "users:" | grep -A1 "oauth_token:" | awk '/oauth_token:/ {getline; print $2}')
  auth="-H \"Authorization: Bearer $token\""
elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
  # PAT: ghp_************************************
  token=$(jq -r '.PAT' "$simplifyJson" 2>/dev/null)
  auth="-H \"Authorization: Bearer $token\""
else
  auth=""
fi

# --- Checking Android Version ---
if [ $Android -le 7 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by pikoTwitter Patches.${Reset}"
  return 1
fi

echo -e "$info ${Blue}Target device:${Reset} $Model"

ReVancedCLIJar="$pikoTwitter/revanced-cli-4.6.2-all.jar"
if [ ! -f "$ReVancedCLIJar" ]; then
  echo -e "$running Downloading revanced-cli-4.6.2-all.jar.."
  url="https://github.com/inotia00/revanced-cli/releases/download/v4.6.2/revanced-cli-4.6.2-all.jar"
  while true; do
    #curl -L --progress-bar -C - -o "$ReVancedCLIJar" "$url"
    aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$(basename "$ReVancedCLIJar")" -d "$(dirname "$ReVancedCLIJar")" "$url"
    if [ $? -eq 0 ]; then
      echo  # White Space
      break
    fi
    echo -e "${bad} ${Red}Download failed! retrying in 5 seconds..${Reset}"
    sleep 5  # Wait 5 seconds
  done
fi
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

if [ "$FetchPreRelease" -eq 0 ]; then
  release="latest"  # Use latest release
  tag=$(curl -sL ${auth} "https://api.github.com/repos/crimera/piko/releases/latest" | jq -r '.tag_name')
else
  release="pre"  # Use pre-release
  tag=$(curl -sL ${auth} "https://api.github.com/repos/crimera/piko/releases" | jq -r '.[].tag_name | select(contains("dev"))' | head -n 1)
fi

bash $Simplify/dlGitHub.sh "crimera" "piko" "$release" ".jar" "$pikoTwitter"
PatchesJar=$(find "$pikoTwitter" -type f -name "piko-twitter-patches-*.jar" -print -quit)
echo -e "$info ${Blue}PatchesJar:${Reset} $PatchesJar"
  curl -sL ${auth} "https://api.github.com/repos/crimera/piko/releases/tags/$tag" | jq -r .body | glow  # Display the release notes
patchesJarFile=$(basename "$PatchesJar")
if echo "$patchesJarFile" | grep -q "dev" 2>/dev/null; then
  isPreReleases="true"
else
  isPreReleases=false
fi

#bash $Simplify/dlGitHub.sh "crimera" "revanced-integrations" "latest" ".apk" "$pikoTwitter"
bash $Simplify/dlGitHub.sh "crimera" "revanced-integrations" "$release" ".apk" "$pikoTwitter"
IntegrationsApk=$(find "$pikoTwitter" -type f -name "revanced-integrations-*.apk" -print -quit)
echo -e "$info ${Blue}IntegrationsApk:${Reset} $IntegrationsApk"

if [ "$RipLib" -eq 1 ]; then
  # --- Architecture Detection ---
  all_arch="arm64-v8a armeabi-v7a x86_64 x86"  # Space-separated list instead of array
  # Generate ripLib arguments for all ABIs EXCEPT the detected one
  ripLib=""
  for current_arch in $all_arch; do
    if [ "$current_arch" != "$cpuAbi" ]; then
      if [ -z "$ripLib" ]; then
        ripLib="--rip-lib=$current_arch"  # No leading space for first item
      else
        ripLib="$ripLib --rip-lib=$current_arch"  # Add space for subsequent items
      fi
    fi
  done
  # Display the final ripLib arguments
  echo -e "$info ${Blue}cpuAbi:${Reset} $cpuAbi"
  echo -e "$info ${Blue}ripLib:${Reset} $ripLib"
else
  ripLib=""  # If RipLib is not enabled, set ripLib to an empty string
  echo -e "$notice RipLib Disabled!"
fi

# Get compatiblePackages version from json
getVersion() {
  local pkgName="$1"
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesJar -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
  preVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesJar -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | tail -n 1)
  if [ -z "$pkgVersion" ] || [ "$pkgVersion" == "Any" ] || [ "$pkgVersion" == "null" ]; then
    if [ "$isPreReleases" == "true" ]; then
      pkgVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases" | jq -r '.[].tag_name' | head -1)  # Last Releases
    else
      pkgVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases/latest" | jq -r '.tag_name')  # Latest Releases
    fi
    preVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases" | jq -r '.[].tag_name' | head -n 2 | tail -n 1)  # Previous Releases
    if [ -z "$pkgVersion" ]; then
      pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-patches -d=true -f=$pkgName -i=false -o=false -p=false -u -v=true $PatchesJar | grep -oP 'Requires X \K[\d.]+-release\.\d+' | sort -rV | head -n 1)
      preVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-patches -d=true -f=$pkgName -i=false -o=false -p=false -u -v=true $PatchesJar | grep -oP 'Requires X \K[\d.]+-release\.\d+' | sort -rV | head -n 2 | tail -n 1)
    fi
  fi

  pre_stock_apk_path=$(find "$Download" -type f -name "${appName[0]}_v${preVersion}-*.apk" -print -quit)
  [[ -f "$pre_stock_apk_path" ]] && rm "$pre_stock_apk_path"  # Remove previous stock apk if exists
}

#  --- Patch Apps ---
patch_twitter() {
  local -n stock_apk_ref=$1
  local outputAPK=$2
  without_ext="${outputAPK%.*}"  # remove file extension (.apk)
  local log="$SimplUsr/piko-twitter_patch-log.txt"
  
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar patch -b $PatchesJar -m $IntegrationsApk \
    -o "$outputAPK" "${stock_apk_ref[0]}" \
    -i "Bring back twitter" -i "Enable app downgrading" -e "Export all activities" \
    --custom-aapt2-binary="$HOME/aapt2" --purge $ripLib -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, Piko Twitter Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/crimera/piko/issues/new"
    termux-open --send "$log"
    rm -rf "$without_ext-temporary-files"  # Remove temporary files directory
  else
    rm -f "$without_ext-options.json" && rm -f "$without_ext.keystore"
  fi
}

appName=("X")
pkgName="com.twitter.android"
#pkgVersion="11.4.0-release.0"
if [ -z "$pkgVersion" ]; then
  getVersion "$pkgName"
  pkgVersion="$pkgVersion"
fi
Type="BUNDLE"
Arch=("universal")
outputAPK="$SimplUsr/piko-twitter_v${pkgVersion}-$cpuAbi.apk"
fileName=$(basename $outputAPK)
activityPatched="com.twitter.android/.StartActivity"

bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${Arch[0]}"  # Download stock apk from APKMirror
xFileName=$(basename "$(find "$Download" -type f -name "${appName[0]}_v*-$cpuAbi.apk" -print -quit)")
stock_apk_path=("$Download/$xFileName")
sleep 0.5  # Wait 500 milliseconds
second=1
while true; do
  if [ -f "${stock_apk_path[0]}" ]; then
    break
  fi
  if [ $second -ge 30 ]; then
    echo -e "$notice Oops, ${appName[0]} APK not found in $Download dir after waiting 30 seconds!"
    break
  fi
  second=$((second + 1))
  sleep 1  # Wait 1 seconds
done
if [ -f "${stock_apk_path[0]}" ]; then
  echo -e "$good ${Green}Downloaded ${appName[0]} APK found:${Reset} ${stock_apk_path[0]}"
  echo -e "$running Patching Piko Twitter.."
  patch_twitter "stock_apk_path" "$outputAPK"
fi

if [ -f "$outputAPK" ]; then
  echo -e "[?] ${Yellow}Do you want to install Piko Twitter app? [Y/n] ${Reset}\c" && read opt
  case $opt in
    y*|Y*|"")
      echo -e "$running Please Wait !! Installing Patched Piko Twitter apk.."
      bash $Simplify/apkInstall.sh "$outputAPK" "$pkgName" "$activityPatched"
      ;;
    n*|N*) echo -e "$notice Piko Twitter Installaion skipped!" ;;
    *) echo -e "$info Invalid choice! Piko Twitter Installaion skipped." ;;
  esac
    
  echo -e "[?] ${Yellow}Do you want to Share Piko Twitter app? [Y/n] ${Reset}\c" && read opt
  case $opt in
    y*|Y*|"")
      echo -e "$running Please Wait !! Sharing Patched Piko Twitter apk.."
      termux-open --send "$outputAPK"
      ;;
    n*|N*) echo -e "$notice Piko Twitter Sharing skipped!"
      echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)" && sleep 3
      am start -n "com.google.android.documentsui/com.android.documentsui.files.FilesActivity" > /dev/null 2>&1  # Open Android Files by Google
      if [ $? -ne 0 ] || [ $? -eq 2 ]; then
        am start -n "com.android.documentsui/com.android.documentsui.files.FilesActivity" > /dev/null 2>&1  # Open Android Files
      fi
      ;;
    *) echo -e "$info Invalid choice! Piko Twitter Sharing skipped." ;;
  esac
fi
#######################################################################