#!/usr/bin/bash

# Colored log indicators
good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

# ANSI Color
Green="\033[92m"
Red="\033[91m"
Blue="\033[94m"
White="\033[37m"
Yellow="\033[93m"
Reset="\033[0m"

# --- Global Veriable ---
Android=$(getprop ro.build.version.release)  # Get Android version
arch=$(getprop ro.product.cpu.abi)  # Get Android arch
serial=$(su -c 'getprop ro.serialno')  # Get Serial Number required root
model=$(getprop ro.product.model)  # Get Device Model
Simplify="$HOME/Simplify"
RVX="$Simplify/RVX"
SimplUsr="/sdcard/Simplify"
mkdir -p "$Simplify" "$RVX" "$SimplUsr"
Download="/sdcard/Download"

# --- Termux SuperUser Permission Check ---
if su -c "id" >/dev/null 2>&1; then
  echo -e "$good SU permission is granted."
else
  echo -e "$bad SU permission is not granted!"
  echo -e "$notice Please open the Magisk/KernelSU/APatch app and manually grant root permissions to Termux."
  return 1
fi

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

echo -e "$info ${Blue}Target device:${Reset} $model ($serial)"

# --- Generate ripLib ---
all_arch="arm64-v8a armeabi-v7a x86_64 x86"
# --- Generate ripLib arguments for all ABIs EXCEPT the detected one ---
ripLib=""
for current_arch in $all_arch; do
  if [ "$current_arch" != "$arch" ]; then
    if [ -z "$ripLib" ]; then
      ripLib="--rip-lib=$current_arch"  # No leading space for first item
    else
      ripLib="$ripLib --rip-lib=$current_arch"  # Add space for subsequent items
    fi
  fi
done

# --- Checking Android Version ---
if [ $Android -le 8 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by RVXCoreLSPosed Patches.${Reset}"
  return 1
fi

bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"
#bash $Simplify/dlGitHub.sh "inotia00" "revanced-patches" "latest" ".rvp" "$RVX"
bash $Simplify/dlGitHub.sh "anddea" "revanced-patches" "pre" ".rvp" "$RVX"
PatchesRvp=$(find "$RVX" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

# Get compatiblePackages version from json
getVersion() {
  local pkgName="$1"
  local json="$RVX/patches.json"
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$(jq -r --arg pkg "$pkgName" '[.[] | .compatiblePackages // empty | .[] | select(.name == $pkg and .versions != null) | .versions[]] | sort | last' $json 2>/dev/null)
}

#  --- Patch YouTube ---
patch_yt() {
  local outputAPK=$1
  local log="$SimplUsr/yt-rvx-patch_log.txt"
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" $youtube_apk_path \
    -e "Change version code" -d "GmsCore support" \
    -e "Custom Shorts action buttons" -OiconType="round" \
    -e "Custom branding icon for YouTube" -OappIcon="$SimplUsr/branding/youtube/launcher/google_family" -OchangeSplashIcon=true -OrestoreOldSplashAnimation=false \
    -e "Custom header for YouTube" -OcustomHeader="$SimplUsr/branding/youtube/header/google_family" \
    -e "Custom branding name for YouTube" -OappName="YouTube RVX" \
    -e "Hide shortcuts" -Oshorts=false \
    -e "Visual preferences icons for YouTube" -OsettingsMenuIcon="extension" \
    -e "Overlay buttons" -OiconType=thin \
    -e "Spoof streaming data" -OuseIOSClient \
    -e "Settings for YouTube" -OinsertPosition="@string/about_key" -OrvxSettingsLabel=RVX \
    -e "Force hide player buttons background" -e=MaterialYou \
    -e="Return YouTube Username" --custom-aapt2-binary="$HOME/aapt2" \
    --purge $ripLib --unsigned -f | tee "$log"

  if [ ! -f "$outputAPK" ] && [ -f $youtube_apk_path ]; then
    echo "$bad Oops, YouTube Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/inotia00/ReVanced_Extended/issues/new?template=bug-report.yml"
    termux-open --send "$log"
  fi
}

# ---- Patch YouTube Music ---
patch_yt_music() {
  local outputAPK=$1
  local log="$SimplUsr/yt-music-rvx-patch_log.txt"
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "$yt_music_apk_path" \
    -e "Change version code" -d "GmsCore support" \
    -e "Custom branding icon for YouTube Music" -OappIcon="$SimplUsr/branding/music/launcher/google_family" \
    -e "Custom header for YouTube Music" -OcustomHeader="$SimplUsr/branding/music/header/google_family" \
    -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" \
    -e "Dark theme" -OmaterialYou=true \
    -e "Visual preferences icons for YouTube Music" -OsettingsMenuIcon="extension" \
    -e "Settings for YouTube Music" -OrvxSettingsLabel="RVX" \
    -e "Custom header for YouTube Music" -e="Return YouTube Username" --custom-aapt2-binary="$HOME/aapt2" \
    --purge --rip-lib=$arch --unsigned -f | tee "$log"

  if [ ! -f "$outputAPK" ] && [ -f $yt_music_apk_path ]; then
    echo "$bad Oops, YouTube Music Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/inotia00/ReVanced_Extended/issues/new?template=bug-report.yml"
    termux-open --send "$log"
  fi
}

# --- copy signature from another apk ---
cs() {
  local stockAPK=$1
  local targetAPK=$2
  local outputAPK=$3
  
  apksigcopier copy "$stockAPK" "$targetAPK" "$outputAPK"
  rm "$targetAPK"
}

# --- Generate patches.json file --- 
if [ -f "$RVX/patches.json" ]; then
  rm $RVX/patches.json
fi
$PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patches -p "$RVX/patches.json" $PatchesRvp
if [ $? == 0 ] && [ -f "$RVX/patches.json" ]; then
  echo -e "$info patches.json generated successfully."
  jq -r '.[] | .compatiblePackages // empty | .[] | {name: .name, version: .versions[-1]} | "\(.name) \(.version)"' $RVX/patches.json | sort -u | awk '{a[$1]=$2} END{for (i in a) printf "\"%s\" \"%s\"\n", i, a[i]}'
else
  echo -e "$bad patches.json was not generated!"
fi

# --- YouTube ---
getVersion "com.google.android.youtube"
#pkgVersion="$pkgVersion"
pkgVersion="20.21.37"
bash $Simplify/APKMdl.sh "com.google.android.youtube" "$pkgVersion" "BUNDLE" "universal"  # Download stock YouTube apk from APKMirror
youtube_apk_path="$Download/YouTube_v${pkgVersion}-universal.apk"
if [ -f "$youtube_apk_path" ]; then
  echo -e "$good ${Green}Downloaded YouTube APK found:${Reset} $youtube_apk_path"
  echo -e "$running Patching YouTube RVX.."
  patch_yt "$RVX/youtube-rvx_v${pkgVersion}-$arch.apk"
fi
if [ -f "$RVX/youtube-rvx_v${pkgVersion}-$arch.apk" ]; then
  echo -e "[?] ${Yellow}Please select installation type - 'M' for Mount or 'I' for SU-Install or 'N' for Installation cancel. [M/i/N] ${Reset}\c" && read opt
  case $opt in
    I*|i*|"")
      echo -e "$running Copy signature from YouTube.."
      cs "$youtube_apk_path" "$RVX/youtube-rvx_v${pkgVersion}-$arch.apk" "$SimplUsr/youtube-rvx-cs_v${pkgVersion}-$arch.apk"
      echo -e "$running Please Wait !! Installing Patched YouTube RVX CS apk.."
      bash $Simplify/apkInstall.sh "$SimplUsr/youtube-rvx-cs_v${pkgVersion}-$arch.apk" "youtube-rvx-cs_v${pkgVersion}-$arch.apk" "com.google.android.youtube" "com.google.android.apps.youtube.app.watchwhile.MainActivity"
      ;;
    M*|m*)
      echo -e "$running Please Wait !! Mounting Patched YouTube RVX apk.."
      su -mm -c "/system/bin/sh $Simplify/apkMount.sh $youtube_apk_path $RVX/youtube-rvx_v${pkgVersion}-$arch.apk YouTube com.google.android.youtube $pkgVersion"
      ;;
    N*|n*) echo -e "$notice YouTube RVX Installaion skipped!" ;;
    *) echo -e "$info Invalid choice! YouTube RVX Installaion skipped." ;;
  esac 
fi

# --- YouTube Music ---
getVersion "com.google.android.apps.youtube.music"
#pkgVersion="$pkgVersion"
pkgVersion="8.24.53"
bash $Simplify/APKMdl.sh "com.google.android.apps.youtube.music" "$pkgVersion" "APK" "$arch"  # Download stock YouTube apk from APKMirror
yt_music_apk_path="$Download/YouTube Music_v${pkgVersion}-$arch.apk"
if [ -f "$yt_music_apk_path" ]; then
  echo -e "${good} ${Green}Downloaded YouTube Music APK found:${Reset} $yt_music_apk_path"
  echo -e "$running Patching YouTube Music RVX.."
  patch_yt_music "$RVX/yt-music-rvx_v${pkgVersion}-$arch.apk"
fi
if [ -f "$RVX/yt-music-rvx_v${pkgVersion}-$arch.apk" ]; then
  echo -e "[?] ${Yellow}Do you want to Mount YT Music RVX apk? [Y/n] ${Reset}\c" && read opt
  case $opt in
    y*|Y*)
      echo -e "$running Please Wait !! Mounting Patched YT Music RVX apk.."
      su -mm -c "/system/bin/sh $Simplify/apkMount.sh $yt_music_apk_path $RVX/yt-music-rvx_v${pkgVersion}-$arch.apk YouTube\ Music com.google.android.apps.youtube.music $pkgVersion"
      ;;
    n*|N*) echo -e "$notice YT Music RVX Installaion skipped!" ;;
    *) echo -e "$info Invalid choice! YT Music RVX Installaion skipped." ;;
  esac
  <<comment
  echo -e "$running Copy signature from YouTube Music.."
  cs "$youtube_apk_path" "$RVX/yt-music-rvx_v${pkgVersion}-$arch.apk" "$SimplUsr/yt-music-rvx-cs_v${pkgVersion}-$arch.apk"
  echo -e "$running Please Wait !! Installing Patched YouTube Music RVX CS apk.."
  bash $Simplify/apkInstall.sh "$SimplUsr/yt-music-rvx-cs_v${pkgVersion}-$arch.apk" "yt-music-rvx-cs_v${pkgVersion}-$arch.apk" "com.google.android.apps.youtube.music" "com.google.android.apps.youtube.music.activities.MusicActivity"
comment
fi
##############################################################################################################################