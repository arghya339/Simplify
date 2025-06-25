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
arch=$(getprop ro.product.cpu.abi)  # Get Android arch
model=$(getprop ro.product.model)  # Get Device Model
Simplify="$HOME/Simplify"  # /data/data/com.termux/files/home/Simplify dir
RV="$Simplify/RV"
RVX="$Simplify/RVX"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$RV" "$RVX" "$SimplUsr"  # Create $Simplify, $RV, $RVX and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir

echo -e "$info ${Blue}Target device:${Reset} $model"

bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

#bash $Simplify/dlGitHub.sh "ReVanced" "revanced-patches" "latest" ".rvp" "$RV"
bash $Simplify/dlGitHub.sh "ReVanced" "revanced-patches" "pre" ".rvp" "$RV"
PatchesRvp=$(find "$RV" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

if [ "$Android" -ge "6" ]; then
  bash $Simplify/dlGitHub.sh "inotia00" "VancedMicroG" "latest" ".apk" "$SimplUsr"
  VancedMicroG=$(find "$SimplUsr" -type f -name "microg-*.apk" -print -quit)
  VancedMicroGBaseName=$(basename "$VancedMicroG")
  echo -e "$info ${Blue}VancedMicroG:${Reset} $VancedMicroG"
fi

# --- Architecture Detection ---
all_arch="arm64-v8a armeabi-v7a x86_64 x86"  # Space-separated list instead of array
# Generate ripLib arguments for all ABIs EXCEPT the detected one
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
# Display the final ripLib arguments
echo -e "$info ${Blue}arch:${Reset} $arch"
echo -e "$info ${Blue}ripLib:${Reset} $ripLib"

# --- Generate patches.json file --- 
if [ $Android -ge 8 ]; then
  if [ -f "$RV/patches.json" ]; then
    rm $RV/patches.json
  fi
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patches -p "$RV/patches.json" $PatchesRvp
  if [ $? == 0 ] && [ -f "$RV/patches.json" ]; then
    echo -e "$info patches.json generated successfully."
    jq -r '.[] | .compatiblePackages // empty | .[] | {name: .name, version: .versions[-1]} | "\(.name) \(.version)"' $RV/patches.json | sort -u | awk '{a[$1]=$2} END{for (i in a) printf "\"%s\" \"%s\"\n", i, a[i]}'
  else
    echo -e "$bad patches.json was not generated!"
  fi
fi

# Get compatiblePackages version from json
getVersion() {
  local pkgName="$1"
  local json="$RV/patches.json"
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$(jq -r --arg pkg "$pkgName" '[.[] | .compatiblePackages // empty | .[] | select(.name == $pkg and .versions != null) | .versions[]] | sort | last' $json 2>/dev/null)
}

#  --- Patch Apps ---
patch_app() {
  local stock_apk_path=$1
  local -n patches=$2  # nameref (-n) accept an array name as parameter
  local outputAPK=$3
  local log=$4
  local appName=$5
  echo "$info DEBUG - patches: '$patches'"

  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" $stock_apk_path \
    "${patches[@]}" \
    -e "Change version code" -OversionCode="2147483647" -e "Disable Pairip license check" -e "Predictive back gesture" -e "Remove share targets" \
    --custom-aapt2-binary="$HOME/aapt2" \
    --purge $ripLib -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f $stock_apk_path ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/ReVanced/revanced-patches/issues/new?template=bug_report.yml"
    termux-open --send "$log"
  fi
}

# --- Collect the enable/disable patches name with options in arrays ---
yt_patches_args=(
# enable patches with their options
  -e "GmsCore support" -O gmsCoreVendorGroupId="com.mgoogle"
  -e "Custom branding" -O appName="YouTube RV" -O iconPath="$SimplUsr/branding/youtube/launcher/google_family"
  -e "Change header" -O header="$SimplUsr/branding/youtube/header/google_family"
  -e "Change package name" -O packageName="app.revanced.android.youtube"
  
  # disable patches
  -d "Announcements"
)

# --- Build YouTube ---
build_yt() {
  getVersion "com.google.android.youtube"
  pkgVersion="$pkgVersion"
  #pkgVersion="20.12.46"
  bash $Simplify/APKMdl.sh "com.google.android.youtube" "$pkgVersion" "BUNDLE" "universal"  # Download stock YouTube apk from APKMirror
  youtube_apk_path="$Download/YouTube_v${pkgVersion}-universal.apk"
  if [ -f "$youtube_apk_path" ]; then
    echo -e "$good ${Green}Downloaded YouTube APK found:${Reset} $youtube_apk_path"
    echo -e "$running Patching YouTube RVX.."
    patch_app "$youtube_apk_path" "yt_patches_args" "$SimplUsr/youtube-rv_v${pkgVersion}-$arch.apk" "$SimplUsr/yt-rv-patch_log.txt" "YouTube"  # pass the name of the array (yt_patches_args), not its contents ($yt_patches_args)
  fi
  if [ -f "$SimplUsr/youtube-rv_v${pkgVersion}-$arch.apk" ]; then
    echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
    echo -e "[?] ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset} \c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing VancedMicroG apk.."
        bash $Simplify/apkInstall.sh "$VancedMicroG" "$VancedMicroGBaseName" "com.mgoogle.android.gms" "org.microg.gms.ui.SettingsActivity"
        ;;
      n*|N*) echo -e "$notice VancedMicroG Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! VancedMicroG Installaion skipped." ;;
    esac
    echo -e "[?] ${Yellow}Do you want to install YouTube RV app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched YouTube RV apk.."
        bash $Simplify/apkInstall.sh "$SimplUsr/youtube-rv_v${pkgVersion}-$arch.apk" "youtube-rv_v${pkgVersion}-$arch.apk" "app.rvx.android.youtube" "com.google.android.apps.youtube.app.watchwhile.MainActivity"
        ;;
      n*|N*) echo -e "$notice YouTube RV Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! YouTube RV Installaion skipped." ;;
    esac
    echo -e "[?] ${Yellow}Do you want to Share YouTube RV app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo - e"$running Please Wait !! Sharing Patched YouTube RV apk.."
        termux-open --send "$SimplUsr/youtube-rv_v${pkgVersion}-$arch.apk"
        ;;
      n*|N*) echo -e "$notice YouTube RV Sharing skipped!"
        echo -e "$info Locate 'youtube-rv_v${pkgVersion}-$arch.apk' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
        ;;
        *) echo -e "$info Invalid choice! YouTube RV Sharing skipped." ;;
    esac
  fi
}

spotify_patches_args=(
  -e "Change lyrics provider"
  -e "Custom theme"
  -e "Change package name" -OpackageName="com.spotify.music"
  
  -d "Hide Create button"
)

# --- Build Spotify ---
build_spotify() {
  if [ $Android -ne 7 ]; then
    getVersion "com.spotify.music"
    #pkgVersion="$pkgVersion"
    pkgVersion="9.0.28.630"
    if [ ! -f "$Download/Spotify_v${pkgVersion}-universal.apk" ];then
      #bash $Simplify/APKMdl.sh "com.spotify.music" "" "BUNDLE" "universal"  # Download stock Spotify apk from APKMirror
      curl -L --progress-bar -C - -o "$Download/Spotify_v${pkgVersion}-universal.apk" "https://github.com/arghya339/apk-me/releases/download/SpotifyRV_v9.0.28.630-5.16.0/Spotify_v9.0.28.630-125833530-arm64-v8a.apk"
    fi
  else
    pkgVersion="8.6.98.900"
    if [ ! -f "$Download/Spotify_v${pkgVersion}-universal.apk" ]; then
      #https://spotify.uptodown.com/android/descargar/4283531
      curl -L --progress-bar -C - -o "$Download/Spotify_v${pkgVersion}-universal.apk" "https://github.com/arghya339/apk-me/releases/download/SpotifyRV_v9.0.28.630-5.16.0/spotify-revanced_v8.6.98.900-5.21.0-5-all.apk"
    fi
  fi
  spotify_apk_path="$Download/Spotify_v${pkgVersion}-universal.apk"
  if [ -f "$spotify_apk_path" ]; then
    echo -e "$good ${Green}Downloaded Spotify APK found:${Reset} $spotify_apk_path"
    echo -e "$running Patching Spotify RVX.."
    patch_app "$spotify_apk_path" "spotify_patches_args" "$SimplUsr/spotify-rv_v${pkgVersion}-$arch.apk" "$SimplUsr/spotify-rv-patch_log.txt" "Spotify"
  fi
  if [ -f "$SimplUsr/spotify-rv_v${pkgVersion}-$arch.apk" ]; then
    echo -e "[?] ${Yellow}Do you want to install Spotify RV app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched Spotify RV apk.."
        bash $Simplify/apkInstall.sh "$SimplUsr/spotify-rv_v${pkgVersion}-$arch.apk" "spotify-rv_v${pkgVersion}-$arch.apk" "com.spotify.music" "com.spotify.music.MainActivity"
        ;;
      n*|N*) echo -e "$notice Spotify RV Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! Spotify RV Installaion skipped." ;;
    esac
    echo -e "[?] ${Yellow}Do you want to Share Spotify RV app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo - e"$running Please Wait !! Sharing Patched Spotify RV apk.."
        termux-open --send "$SimplUsr/spotify-rv_v${pkgVersion}-$arch.apk"
        ;;
      n*|N*) echo -e "$notice Spotify RV Sharing skipped!"
        echo -e "$info Locate 'spotify-rv_v${pkgVersion}-$arch.apk' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
        ;;
        *) echo -e "$info Invalid choice! Spotify RV Sharing skipped." ;;
    esac
  fi
}

# Define the array
apps=(
  Quit
  YouTube
  Spotify
)

while true; do
  # Display the list
  echo -e "$info Available apps:"
  for i in "${!apps[@]}"; do
    printf "%d. %s\n" "$i" "${apps[$i]}"
  done

  # Ask for an index, showing the valid range
  max=$(( ${#apps[@]} - 1 ))  # highest legal index
  read -rp "Enter the index [0-${max}] of the apps you want to patch: " idx

  # Validate and respond
  if [ $idx == 0 ]; then
    break  # break the while loop
  elif [[ $idx =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice You chose: ${apps[$idx]}"
  else
    echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
  fi

  case ${apps[$idx]} in
    YouTube) build_yt ;;
    Spotify) build_spotify ;;
  esac  
done
#############################