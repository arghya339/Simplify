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
cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
Serial=$(su -c 'getprop ro.serialno')  # Get Serial Number required root
Model=$(getprop ro.product.model)  # Get Device Model
Simplify="$HOME/Simplify"
RVX="$Simplify/RVX"
SimplUsr="/sdcard/Simplify"
mkdir -p "$Simplify" "$RVX" "$SimplUsr"
Download="/sdcard/Download"
rvxBugReportUrl="https://github.com/kitadai31/revanced-patches-android6-7/issues/new?template=bug_report.yml"
rvxa6_7BugReportUrl="https://github.com/inotia00/ReVanced_Extended/issues/new?template=bug-report.yml"

# --- Checking Android Version ---
if [ $Android -le 4 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by RVX Patches.${Reset}"
  return 1
fi

# --- Termux SuperUser Permission Check ---
if su -c "id" >/dev/null 2>&1; then
  echo -e "$good SU permission is granted."
else
  echo -e "$bad SU permission is not granted!"
  echo -e "$notice Please open the Magisk/KernelSU/APatch app and manually grant root permissions to Termux."
  return 1
fi

echo -e "$info ${Blue}Target device:${Reset} $Model ($Serial)"

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

# --- Generate ripLib ---
all_arch="arm64-v8a armeabi-v7a x86_64 x86"
# --- Generate ripLib arguments for all ABIs EXCEPT the detected one ---
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

#  --- Patch Apps ---
patch_app() {
  local stock_apk_path=$1
  local -n patches=$2  # nameref (-n) accept an array name as parameter
  local outputAPK=$3
  local log=$4
  local appName=$5
  local Url=$6
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "$stock_apk_path" \
    "${patches[@]}" \
    -e "Change version code" -OversionCode="2147483647" \
    --custom-aapt2-binary="$HOME/aapt2" \
    --purge $ripLib --unsigned -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "$stock_apk_path" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "$Url"
    termux-open --send "$log"
  fi
}

# --- Collect the enable/disable patches name with options in arrays ---
yt_patches_args=(
  # enable patches with their options
  -e "Custom Shorts action buttons" -OiconType="round"
  -e "Custom branding icon for YouTube" -OappIcon="$SimplUsr/branding/youtube/launcher/google_family" -OchangeSplashIcon=true -OrestoreOldSplashAnimation=false
  -e "Custom header for YouTube" -OcustomHeader="$SimplUsr/branding/youtube/header/google_family"
  -e "Custom branding name for YouTube" -OappName="YouTube RVX"
  -e "Hide shortcuts" -Oshorts=false
  -e "Visual preferences icons for YouTube" -OsettingsMenuIcon="extension"
  -e "Overlay buttons" -OiconType=thin
  -e "Spoof streaming data" -OuseIOSClient
  -e "Settings for YouTube" -OinsertPosition="@string/about_key" -OrvxSettingsLabel=RVX
  -e "Force hide player buttons background"
  -e=MaterialYou
  -e="Return YouTube Username"
  
  # disable patches
  -d "GmsCore support"
)

yt_music_patches_args=(
  -e "Custom branding icon for YouTube Music" -OappIcon="$SimplUsr/branding/music/launcher/google_family"
  -e "Custom header for YouTube Music" -OcustomHeader="$SimplUsr/branding/music/header/google_family"
  -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX"
  -e "Dark theme" -OmaterialYou=true
  -e "Visual preferences icons for YouTube Music" -OsettingsMenuIcon="extension"
  -e "Settings for YouTube Music" -OrvxSettingsLabel="RVX"
  -e "Custom header for YouTube Music"
  -e="Return YouTube Username"
  
  -d "GmsCore support"
)

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

# --- Build App ---
build_app() {
  # local variables
  local pkgName=$1
  local pkgVersion=$2
  local Type=$3
  local Arch=$4
  local stock_apk_path=$5
  local stockFileName=$(basename "$stock_apk_path")
  local appPatchesArgs=$6
  local outputAPK=$7
  local fileName=$(basename $outputAPK)
  local log=$8
  local appName=$9
  local bugReportUrl=$10
  
  
  bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "$Arch"  # Download stock apk from APKMirror
  
  if [ -f "$stock_apk_path" ]; then
    echo -e "$good ${Green}Downloaded $appName APK found:${Reset} $stock_apk_path"
    echo -e "$running Patching $appName RVX.."
    patch_app "$stock_apk_path" "$appPatchesArgs" "$outputAPK" "$log" "$appName" "$bugReportUrl"
  fi
  if [ -f "$Download/\"$stockFileName\"" ]; then
    echo -e "$good ${Green}Downloaded $appName APK found:${Reset} $Download/\"$stockFileName\""
    echo -e "$running Patching $appName RVX.."
    patch_app "$Download/\"$stockFileName\"" "$appPatchesArgs" "$outputAPK" "$log" "$appName" "$bugReportUrl"
  fi
  if [ -f "$outputAPK" ]; then
    
    if [ "$pkgName" == "com.google.android.youtube" ]; then
      
      echo -e "[?] ${Yellow}Please select installation type - 'M' for Mount or 'I' for SU-Install or 'N' for Installation cancel. [M/i/N]: ${Reset}\c" && read opt
      case $opt in
        I*|i*|"")
          checkCoreLSPosed  # Call the check core patch functions
          Type="APK"
          Arch="universal"
          bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "$Arch"
          stock_apk_path="$Download/${appName}_v${pkgVersion}-$Arch.apk"
          echo -e "$running Copy signature from $appName.."
          cs "$stock_apk_path" "$outputAPK" "$SimplUsr/$appName-RVX-CS_v${pkgVersion}-$Arch.apk"
          echo -e "$running Please Wait !! Installing Patched $appName RVX CS apk.."
          bash $Simplify/apkInstall.sh "$SimplUsr/$appName-RVX-CS_v${pkgVersion}-$Arch.apk" "$pkgName" ""
          ;;
        M*|m*)
          echo -e "$running Please Wait !! Mounting Patched $appName RVX apk.."
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh $stock_apk_path $outputAPK $appName $pkgName $pkgVersion" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh $stock_apk_path $outputAPK $appName $pkgName $pkgVersion" | tee "$SimplUsr/${appName}-RVX_mount_log.txt"
          rm $outputAPK
          ;;
        N*|n*) echo -e "$notice $appName RVX Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! $appName RVX Installaion skipped." ;;
      esac

    else
      
      echo -e "[?] ${Yellow}Do you want to Mount $appName RVX app? [Y/n] ${Reset}\c" && read opt
      case $opt in
        y*|Y*|"")
          echo -e "$running Please Wait !! Mounting Patched $appName RVX apk.."
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh $stock_apk_path $outputAPK $appName $pkgName $pkgVersion" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh $stock_apk_path $outputAPK $appName $pkgName $pkgVersion" | tee "$SimplUsr/${appName}-RVX_mount_log.txt"
          rm $outputAPK
          ;;
        n*|N*) echo -e "$notice $appName RVX Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! $appName RVX Installaion skipped." ;;
      esac

    fi

  fi
}

# Define the array
if [ $Android -ge 8 ]; then
  apps=(
    Quit
    YouTube
    YT\ Music
  )
elif [ $Android -eq 7 ]; then
  apps=(
    Quit
    "YouTube RVX v17.34.36"
    "YT Music RVX v6.42.55"
  )
elif [ $Android -eq 6 ]; then
  apps=(
    Quit
    "YouTube RVX v17.34.36"
    "YT Music RVX v6.20.51"
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    "YT Music RVX v6.20.51"
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
  elif [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice You chose: ${apps[$idx]}"
  else
    echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
  fi
  
  case "${apps[$idx]}" in
    YouTube)
      pkgName="com.google.android.youtube"
      pkgVersion="20.21.37"
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch="universal"
      youtube_apk_path="$Download/YouTube_v${pkgVersion}-$cpuAbi.apk"
      outputAPK="$SimplUsr/youtube-rvx_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-rvx-patch_log.txt"
      appName="YouTube"
      build_app "$pkgName" "$pkgVersion" "$Type" "$Arch" "$youtube_apk_path" "yt_patches_args" "$outputAPK" "$log" "$appName" "$rvxBugReportUrl"
      ;;
    YT\ Music)
      pkgName="com.google.android.apps.youtube.music"
      pkgVersion="8.24.53"
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      yt_music_apk_path="$Download/YouTube\ Music_v${pkgVersion}-$cpuAbi.apk"
      outputAPK="$SimplUsr/yt-music-rvx_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-music-rvx-patch_log.txt"
      appName="YouTube Music"
      build_app "$pkgName" "$pkgVersion" "$Type" "$cpuAbi" \"$yt_music_apk_path\" "yt_music_patches_args" "$outputAPK" "$log" \"$appName\" "$rvxBugReportUrl"
      ;;
    "YouTube RVX v17.34.36")
      pkgName="com.google.android.youtube"
      pkgVersion="17.34.36"
      Type="BUNDLE"
      Arch="universal"
      youtube_apk_path="$Download/YouTube_v${pkgVersion}-$cpuAbi.apk"
      outputAPK="$SimplUsr/youtube-rvx_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-rvx-patch_log.txt"
      appName="YouTube"
      build_app "$pkgName" "$pkgVersion" "$Type" "$Arch" "$youtube_apk_path" "yt_patches_args" "$outputAPK" "$log" "$appName" "$rvxa6_7BugReportUrl"
      ;;
    "YT Music RVX v6.42.55")
      pkgName="com.google.android.apps.youtube.music"
      pkgVersion="6.42.55"
      Type="APK"
      yt_music_apk_path="$Download/YouTube\ Music_v${pkgVersion}-$cpuAbi.apk"
      outputAPK="$SimplUsr/yt-music-rvx_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-music-rvx-patch_log.txt"
      appName="YouTube Music"
      build_app "$pkgName" "$pkgVersion" "$Type" "$cpuAbi" \"$yt_music_apk_path\" "yt_music_patches_args" "$outputAPK" "$log" \"$appName\" "$rvxBugReportUrl"
      ;;
    "YT Music RVX v6.20.51")
      pkgName="com.google.android.apps.youtube.music"
      pkgVersion="6.20.51"
      Type="APK"
      yt_music_apk_path="$Download/YouTube\ Music_v${pkgVersion}-$cpuAbi.apk"
      outputAPK="$SimplUsr/yt-music-rvx_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-music-rvx-patch_log.txt"
      appName="YouTube Music"
      build_app "$pkgName" "$pkgVersion" "$Type" "$cpuAbi" \"$yt_music_apk_path\" "yt_music_patches_args" "$outputAPK" "$log" \"$appName\" "$rvxBugReportUrl"
      ;;
  esac  
done
#############################################################################################################################################################