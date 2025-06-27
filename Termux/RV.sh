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
RV="$Simplify/RV"
RVX="$Simplify/RVX"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$RV" "$RVX" "$SimplUsr"  # Create $Simplify, $RV, $RVX and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir

# --- Checking Android Version ---
if [ $Android -le 4 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by ReVanced Patches.${Reset}"
  return 1
fi

echo -e "$info ${Blue}Target device:${Reset} $Model"

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
  echo -e "$info ${Blue}VancedMicroG:${Reset} $VancedMicroG"
fi

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
  local -n stock_apk_ref=$1
  local -n patches=$2  # nameref (-n) accept an array name as parameter
  local outputAPK=$3
  local log=$4
  local appName=$5
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "${stock_apk_ref[0]}" \
    "${patches[@]}" \
    -e "Change version code" -OversionCode="2147483647" -e "Disable Pairip license check" -e "Predictive back gesture" -e "Remove share targets" \
    --custom-aapt2-binary="$HOME/aapt2" \
    --purge $ripLib -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
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

spotify_patches_args=(
  -e "Change lyrics provider"
  -e "Custom theme"
  -e "Change package name" -OpackageName="com.spotify.music"
  
  -d "Hide Create button"
)

tiktok_patches_args=(
  -e "SIM spoof"
  -e "Change package name" -OackageName="com.zhiliaoapp.musically"
)

# --- Build App ---
build_app() {
  # local variables
  local pkgName=$1
  local appName=$2
  local pkgVersion=$3
  local Type=$4
  local -n archRef=$5
  local web=$6
  local -n stock_apk_path=$7
  local appPatchesArgs=$8
  local outputAPK=$9
  local fileName=$(basename $outputAPK)
  local log=$10
  local pkgPatches=$11
  local activityPatches=$12
  

  if [ "$web" == "APKMirror" ]; then
    bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
  else
    echo -e "$notice dlUptodown.sh not implement yeat!"
    #bash $Simplify/dlUptodown.sh "$appName" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from Uptodown
  fi
  
  if [ -f "${stock_apk_path[0]}" ]; then
    echo -e "$good ${Green}Downloaded $appName APK found:${Reset} ${stock_apk_path[0]}"
    echo -e "$running Patching $appName RVX.."
    patch_app "stock_apk_path" "$appPatchesArgs" "$outputAPK" "$log" "$appName" "$bugReportUrl"
  fi
  
  if [ -f "$outputAPK" ]; then
    
    if [ $pkgName == "com.google.android.youtube" ] || [ $pkgName == "com.google.android.apps.youtube.music" ]; then
      echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
      echo -e "[?] ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset} \c" && read opt
      case $opt in
        y*|Y*|"")
          echo -e "$running Please Wait !! Installing VancedMicroG apk.."
          bash $Simplify/apkInstall.sh "$VancedMicroG" "com.mgoogle.android.gms" "org.microg.gms.ui.SettingsActivity"
          ;;
        n*|N*) echo -e "$notice VancedMicroG Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! VancedMicroG Installaion skipped." ;;
      esac
    fi

    echo -e "[?] ${Yellow}Do you want to install $appName RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched $appName RVX apk.."
        bash $Simplify/apkInstall.sh "$outputAPK" "$pkgPatches" "$activityPatches"
        ;;
      n*|N*) echo -e "$notice $appName RVX Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! $appName RVX Installaion skipped." ;;
    esac
    
    echo -e "[?] ${Yellow}Do you want to Share $appName RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo - e"$running Please Wait !! Sharing Patched $appName RVX apk.."
        termux-open --send "$outputAPK"
        ;;
      n*|N*) echo -e "$notice $appName RVX Sharing skipped!"
        echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
        ;;
        *) echo -e "$info Invalid choice! $appName RVX Sharing skipped." ;;
    esac
  
  fi
}

# Define the array
if [ $Android -ge 5 ]; then
  apps=(
    Quit
    YouTube
    Spotify
    TikTok
  )
elif [ $Android -eq 7 ]; then
  apps=(
    Quit
    Spotify
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    TikTok
  )
fi

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
    YouTube)
      pkgName="com.google.android.youtube"
      appName="YouTube"
      #pkgVersion="20.13.41"
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch=("universal")
      youtube_apk_path=("$Download/YouTube_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/youtube-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-rv-patch_log.txt"
      pkgPatches="app.revanced.android.youtube"
      activityPatches="com.google.android.apps.youtube.app.watchwhile.MainActivity"
      build_app "$pkgName" "$appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "youtube_apk_path" "yt_patches_args" "$outputAPK" "$log" "$pkgPatches" "$activityPatches"
      ;;
    Spotify)
      pkgName="com.spotify.music"
      appName="Spotify"
      if [ $Android -eq 7 ]; then
        pkgVersion="8.6.98.900"
        Type="xapk"
        Arch=("armeabi-v7a, x86, arm64-v8a, x86_64")
        if [ ! -f "$Download/Spotify_v${pkgVersion}-$Arch.apk" ]; then
          curl -L --progress-bar -C - -o "$Download/Spotify_v${pkgVersion}-$Arch.apk" "https://github.com/arghya339/apk-me/releases/download/SpotifyRV_v9.0.28.630-5.16.0/spotify-revanced_v8.6.98.900-5.21.0-5-all.apk"  # https://spotify.en.uptodown.com/android/download/4283531
        fi
        spotify_apk_path=("$Download/Spotify_v${pkgVersion}-${Arch[0]}.apk")
      elif [ $Android -ge 8 ]; then
        pkgVersion="9.0.28.630"
        if [ -z "$pkgVersion" ]; then
          getVersion "$pkgName"
          pkgVersion="$pkgVersion"
        fi
        Type="apk"
        Arch=("armeabi-v7a, arm64-v8a, x86_64")
        if [ ! -f "$Download/Spotify_v${pkgVersion}-$cpuAbi.apk" ];then
          curl -L --progress-bar -C - -o "$Download/Spotify_v${pkgVersion}-$cpuAbi.apk" "https://github.com/arghya339/apk-me/releases/download/SpotifyRV_v9.0.28.630-5.16.0/Spotify_v9.0.28.630-125833530-${cpuAbi}.apk"
        fi
        spotify_apk_path=("$Download/Spotify_v${pkgVersion}-$cpuAbi.apk")
      fi
      outputAPK="$SimplUsr/spotify-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/spotify-rv-patch_log.txt"
      activityPatches="com.spotify.music.MainActivity"
      build_app "$pkgName" "$appName" "$pkgVersion" "$Type" "Arch" "Uptodown" "spotify_apk_path" "spotify_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
      ;;
    TikTok)
      pkgName="com.zhiliaoapp.musically"
      appName="TikTok"
      #pkgVersion="36.5.4"
      pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("arm64-v8a + armeabi-v7a")
      tiktok_apk_path=("$Download/TikTok_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/tiktok-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/tiktok-rv-patch_log.txt"
      activityPatches="com.ss.android.ugc.aweme.main.MainActivity"
      build_app "$pkgName" "$appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "tiktok_apk_path" "tiktok_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
      ;;
  esac  
done
##############################################################################################################################################################################