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
Android=$(getprop ro.build.version.release)  # Get Android version
cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
Model=$(getprop ro.product.model)  # Get Device Model
Simplify="$HOME/Simplify"  # /data/data/com.termux/files/home/Simplify dir
pikoTwitter="$Simplify/pikoTwitter"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$pikoTwitter" "$SimplUsr"  # Create $Simplify, $RV, $RVX and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null)
RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
if { [ -f "$HOME/.config/gh/hosts.yml" ] && ! grep -q "{}" "$HOME/.config/gh/hosts.yml" 2>/dev/null; } || ! gh auth status 2>/dev/null; then
  # oauth_token: gho_************************************
  token=$(grep -A2 "users:" ~/.config/gh/hosts.yml | grep -v "users:" | grep -A1 "oauth_token:" | awk '/oauth_token:/ {getline; print $2}')
elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
  # PAT: ghp_************************************
  token=$(jq -r '.PAT' "$simplifyJson" 2>/dev/null)
else
  token=""
fi
if [ -z "$token" ]; then
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
  curl -L --progress-bar -C - -o "$ReVancedCLIJar" "https://github.com/inotia00/revanced-cli/releases/download/v4.6.2/revanced-cli-4.6.2-all.jar"
fi
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

if [ "$FetchPreRelease" -eq 0 ]; then
  release="latest"  # Use latest release
else
  release="pre"  # Use pre-release
fi

bash $Simplify/dlGitHub.sh "crimera" "piko" "$release" ".jar" "$pikoTwitter"
PatchesJar=$(find "$pikoTwitter" -type f -name "piko-twitter-patches-*.jar" -print -quit)
echo -e "$info ${Blue}PatchesJar:${Reset} $PatchesJar"
patchesJarFile=$(basename "$PatchesJar")
if echo "$patchesJarFile" | grep -q "dev" 2>/dev/null; then
  isPreReleases="true"
else
  isPreReleases=false
fi

PatchesJson="$pikoTwitter/patches.json"
if [ -f "$PatchesJson" ]; then
  rm $PatchesJson
fi
#bash $Simplify/dlGitHub.sh "crimera" "piko" "latest" ".json" "$pikoTwitter"
bash $Simplify/dlGitHub.sh "crimera" "piko" "pre" ".json" "$pikoTwitter"
echo -e "$info ${Blue}PatchesJson:${Reset} $PatchesJson"
if [ -f "$pikoTwitter/patches.json" ]; then
  jq -r '.[] | .compatiblePackages // empty | .[] | {name: .name, version: .versions[-1]} | "\(.name) \(.version)"' $pikoTwitter/patches.json | sort -u | awk '{a[$1]=$2} END{for (i in a) printf "\"%s\" \"%s\"\n", i, a[i]}'
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
  local json="$pikoTwitter/patches.json"
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$(jq -r --arg pkg "$pkgName" '[.[] | .compatiblePackages // empty | .[] | select(.name == $pkg and .versions != null) | .versions[]] | sort | last' $json 2>/dev/null)
  if [ "$pkgVersion" == "null" ]; then
    if [ "$isPreReleases" == "true" ]; then
      pkgVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases" | jq -r '.[].tag_name' | head -1)  # Last Releases
    else
      pkgVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases/latest" | jq -r '.tag_name')  # Latest Releases
    fi
    if [ -z "$pkgVersion" ]; then
      pkgVersion=$($PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar list-patches --with-packages $PatchesJar | grep -oP 'Requires X \K[\d.]+-release\.\d+' | sort -u | tail -1)
    fi
  fi
}

#  --- Patch Apps ---
patch_twitter() {
  local -n stock_apk_ref=$1
  local outputAPK=$2
  local log="$SimplUsr/piko-twitter_patch-log.txt"
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -b $PatchesJar -m $IntegrationsApk \
    -o "$outputAPK" "${stock_apk_ref[0]}" \
    -i "Bring back twitter" -i "Enable app downgrading" -e "Export all activities" \
    --custom-aapt2-binary="$HOME/aapt2" --purge $ripLib -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, Piko Twitter Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/crimera/piko/issues/new"
    termux-open --send "$log"
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
xFileName=$(basename "$(find "$Download" -type f -name "${appName[0]}_v*-$cpuAbi.apk" -print -quit)")
stock_apk_path=("$Download/$xFileName")
outputAPK="$SimplUsr/piko-twitter_v${pkgVersion}-$cpuAbi.apk"
fileName=$(basename $outputAPK)
activityPatches="com.twitter.android/.StartActivity"

bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${Arch[0]}"  # Download stock apk from APKMirror
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
      bash $Simplify/apkInstall.sh "$outputAPK" "$pkgName" "$activityPatches"
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
      echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
      ;;
    *) echo -e "$info Invalid choice! Piko Twitter Sharing skipped." ;;
  esac
fi
#######################################################################