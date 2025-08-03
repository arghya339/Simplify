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
RVX="$Simplify/RVX"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$RVX" "$SimplUsr"  # Create $Simplify, $RVX and $SimplUsr dir if it does't exist
RVX6_7="$Simplify/RVX6-7"  # RVX for Android 6 and 7
[[ $Android -eq 7 || $Android -eq 6 ]] && mkdir -p "$RVX6_7"  # Create $RVX6_7 dir if Android version is 6 or 7
Download="/sdcard/Download"  # Download dir
BugReportUrl="https://github.com/inotia00/ReVanced_Extended/issues/new?template=bug-report.yml"
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null)
RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
ChangeRVXSource="$(jq -r '.ChangeRVXSource' "$simplifyJson" 2>/dev/null)"
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
if [ $Android -le 4 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by RVX Patches.${Reset}"
  return 1
fi

echo -e "$info ${Blue}Target device:${Reset} $Model"

bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

if [ "$FetchPreRelease" -eq 0 ]; then
  release="latest"  # Use latest release
else
  release="pre"  # Use pre-release
fi
if [ "$ChangeRVXSource" -eq 0 ]; then
  owner="inotia00"  # Use inotia00 as owner
else
  owner="anddea"  # Use anddea as owner
fi
bash $Simplify/dlGitHub.sh "$owner" "revanced-patches" "$release" ".rvp" "$RVX"
PatchesRvp=$(find "$RVX" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

if [ $Android -eq 5 ]; then
  VancedMicroG="$SimplUsr/microg-0.2.22.212658.apk"
  if [ ! -f "$VancedMicroG" ]; then
    curl -sL "https://github.com/TeamVanced/VancedMicroG/releases/download/v0.2.22.212658-212658001/microg.apk" --progress-bar -C - -o "$VancedMicroG"
  fi
elif [ "$Android" -ge "6" ]; then
  bash $Simplify/dlGitHub.sh "inotia00" "VancedMicroG" "latest" ".apk" "$SimplUsr"
  VancedMicroG=$(find "$SimplUsr" -type f -name "microg-*.apk" -print -quit)
fi
echo -e "$info ${Blue}VancedMicroG:${Reset} $VancedMicroG"

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
  pkgVersion=$($PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
}

<<comment
# --- Download revanced-extended-options.json ---
if [ ! -f "$RVX/rvx-options.json" ]; then
  echo -e "$running Downloading revanced-extended-options.json from GitHub.."
  curl -sL "https://github.com/arghya339/Simplify/releases/download/all/rvx-options.json" --progress-bar -o "$RVX/rvx-options.json"
  # Supported app icon: google_family, pink, revancify_blue, vanced_light
fi
comment

#  --- Patch Apps ---
patch_app() {
  local stock_apk_path=$1
  local -n patches=$2  # nameref (-n) accept an array name as parameter
  local outputAPK=$3
  without_ext="${outputAPK%.*}"  # remove file extension (.apk)
  local log=$4
  local appName="$5"
  local Url=$6
  
  if [[ ( $Android -eq 7 || $Android -eq 6 ) && "$appName" == "YouTube" ]]; then
    bash $Simplify/dlGitHub.sh "kitadai31" "revanced-patches" "$release" ".rvp" "$RVX6_7"
    PatchesRvp=$(find "$RVX6_7" -type f -name "patches-*.rvp" -print -quit)
    echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"
  fi
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "$stock_apk_path" \
    "${patches[@]}" \
    -e "Change version code" -OversionCode="2147483647" \
    --custom-aapt2-binary="$HOME/aapt2" \
    --purge $ripLib -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "$stock_apk_path" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "$Url"
    termux-open --send "$log"
    rm -rf "$without_ext-temporary-files"  # Remove temporary files directory
  else
    rm "$without_ext.keystore"
  fi
}

# --- Collect the enable/disable patches name with options in arrays ---
yt_patches_args=(
  # enable patches with their options
  -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true -OpackageNameYouTube="app.rvx.android.youtube"
  -e "Custom Shorts action buttons" -OiconType="round"
  -e "Custom branding icon for YouTube" -OappIcon="$SimplUsr/.branding/youtube/launcher/google_family" -OchangeSplashIcon=true -OrestoreOldSplashAnimation=false
  -e "Custom header for YouTube" -OcustomHeader="$SimplUsr/.branding/youtube/header/google_family"
  -e "Custom branding name for YouTube" -OappName="YouTube RVX"
  -e "Hide shortcuts" -Oshorts=false
  -e "Visual preferences icons for YouTube" -OsettingsMenuIcon="extension"
  -e "Overlay buttons" -OiconType=thin
  -e "Spoof streaming data" -OuseIOSClient
  -e "Settings for YouTube" -OinsertPosition="@string/about_key" -OrvxSettingsLabel=RVX
  -e "Force hide player buttons background"
  -e=MaterialYou
  -e="Return YouTube Username"
)

yt_music_patches_args=(
  -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true -OpackageNameYouTubeMusic="app.rvx.android.apps.youtube.music"
  -e "Custom branding icon for YouTube Music" -OappIcon="$SimplUsr/.branding/music/launcher/google_family"
  -e "Custom header for YouTube Music" -OcustomHeader="$SimplUsr/.branding/music/header/google_family"
  -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX"
  -e "Dark theme" -OmaterialYou=true
  -e "Visual preferences icons for YouTube Music" -OsettingsMenuIcon="extension"
  -e "Settings for YouTube Music" -OrvxSettingsLabel="RVX"
  -e "Custom header for YouTube Music"
  -e="Return YouTube Username"
)

reddit_patches_args=()

# --- Build App ---
build_app() {
  # local variables
  local pkgName=$1
  local pkgVersion=$2
  local Type=$3
  local Arch=$4
  local -n stock_apk_ref=$5
  local appPatchesArgs=$6
  local outputAPK=$7
  local fileName=$(basename $outputAPK)
  local log=$8
  local -n appNameRef=$9
  local bugReportUrl=$10
  local pkgPatches=$11
  local activityPatches=$12
  
  
  bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "$Arch"  # Download stock apk from APKMirror
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
  if [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_ref[0]}"
    echo -e "$running Patching ${appNameRef[0]} RVX.."
    patch_app "${stock_apk_ref[0]}" "$appPatchesArgs" "$outputAPK" "$log" "${appNameRef[0]}" "$bugReportUrl"
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

    echo -e "[?] ${Yellow}Do you want to install ${appNameRef[0]} RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RVX apk.."
        bash $Simplify/apkInstall.sh "$outputAPK" "$pkgPatches" "$activityPatches"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} RVX Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! ${appNameRef[0]} RVX Installaion skipped." ;;
    esac
    
    echo -e "[?] ${Yellow}Do you want to Share ${appNameRef[0]} RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Sharing Patched ${appNameRef[0]} RVX apk.."
        termux-open --send "$outputAPK"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} RVX Sharing skipped!"
        echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
        ;;
      *) echo -e "$info Invalid choice! ${appNameRef[0]} RVX Sharing skipped." ;;
    esac
  
  fi
}

# Define the array
if [ $Android -ge 9 ]; then
  apps=(
    Quit
    YouTube
    YT\ Music
    Reddit
  )
elif [ $Android -eq 8 ] || [ $Android -eq 7 ] || [ $Android -eq 6 ]; then
  apps=(
    Quit
    YouTube
    YT\ Music
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    "YT Music"
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
  read -rp "Enter the index [0-${max}] of apps you want to patch or '0' to Quit: " idx

  # Validate and respond
  if [ "$idx" == 0 ]; then
    break  # break the while loop
  elif [ "$idx" == "" ] || [ -z "$idx" ]; then
    if [ $release == "latest" ]; then
      tag=$(curl -sL ${auth} "https://api.github.com/repos/$owner/revanced-patches/releases/latest" | jq -r '.tag_name')
    else
      tag=$(curl -sL ${auth} "https://api.github.com/repos/$owner/revanced-patches/releases" | jq -r '.[].tag_name | select(contains("dev"))' | head -n 1)
    fi
    curl -sL ${auth} "https://api.github.com/repos/$owner/revanced-patches/releases/tags/$tag" | jq -r .body | glow  # Display the release notes
  elif [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice You chose: ${apps[$idx]}"
  else
    echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
  fi

  case "${apps[$idx]}" in
    YouTube)
      pkgName="com.google.android.youtube"
      if [ $Android -ge 8 ]; then
        if [ "$ChangeRVXSource" == 0 ]; then
          pkgVersion="20.12.46"
        else
          pkgVersion="20.21.37"
        fi
        if [ -z "$pkgVersion" ]; then
          getVersion "$pkgName"
          pkgVersion="$pkgVersion"
        fi
      elif [ $Android -eq 7 ] || [ $Android -eq 6 ]; then
        pkgVersion="17.34.36"
        BugReportUrl="https://github.com/kitadai31/revanced-patches-android6-7/issues/new?template=bug_report.yml"
      fi
      Type="BUNDLE"
      Arch="universal"
      stock_apk_path=("$Download/YouTube_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/youtube-rvx_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-rvx-patch_log.txt"
      appName=("YouTube")
      pkgPatches="app.rvx.android.youtube"
      activityPatches="com.google.android.youtube/.app.honeycomb.Shell\$HomeActivity"
      build_app "$pkgName" "$pkgVersion" "$Type" "$Arch" "stock_apk_path" "yt_patches_args" "$outputAPK" "$log" "appName" "$BugReportUrl" "$pkgPatches" "$activityPatches"
      ;;
    YT\ Music)
      pkgName="com.google.android.apps.youtube.music"
      if [ $Android -ge 8 ]; then
        if [ "$ChangeRVXSource" == 0 ]; then
          pkgVersion="8.12.53"
        else
          pkgVersion="8.24.53"
        fi
        if [ -z "$pkgVersion" ]; then
          getVersion "$pkgName"
          pkgVersion="$pkgVersion"
        fi
      elif [ $Android -eq 7 ]; then
        pkgVersion="6.42.55"
      elif [ $Android -eq 6 ] || [ $Android -eq 5 ]; then
        pkgVersion="6.20.51"
      fi
      Type="APK"
      stock_apk_path=("${Download}/YouTube Music_v${pkgVersion}-${cpuAbi}.apk")
      outputAPK="$SimplUsr/yt-music-rvx_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-music-rvx-patch_log.txt"
      appName=("YouTube Music")
      pkgPatches="app.rvx.android.apps.youtube.music"
      activityPatches="com.google.android.apps.youtube.music/.activities.MusicActivity"
      build_app "$pkgName" "$pkgVersion" "$Type" "$cpuAbi" "stock_apk_path" "yt_music_patches_args" "$outputAPK" "$log" "appName" "$BugReportUrl" "$pkgPatches" "$activityPatches"
      ;;
    Reddit)
      pkgName="com.reddit.frontpage"
      #pkgVersion="2025.12.1"
      pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch="universal"
      stock_apk_path=("$Download/Reddit_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/reddit-rvx_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/reddit-rvx-patch_log.txt"
      appName=("Reddit")
      activityPatches="com.reddit.frontpage/launcher.default"
      build_app "$pkgName" "$pkgVersion" "$Type" "$Arch" "stock_apk_path" "reddit_patches_args" "$outputAPK" "$log" "appName" "$BugReportUrl" "$pkgName" "$activityPatches"
      ;;
  esac  
done
##############################################################################################################################################################################