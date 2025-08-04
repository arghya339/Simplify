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
Serial=$(su -c 'getprop ro.serialno')  # Get Serial Number required root
Model=$(getprop ro.product.model)  # Get Device Model
RVX="$Simplify/RVX"
SimplUsr="/sdcard/Simplify"
mkdir -p "$Simplify" "$RVX" "$SimplUsr"
RVX6_7="$Simplify/RVX6-7"  # RVX for Android 6 and 7
[[ $Android -eq 7 || $Android -eq 6 ]] && mkdir -p "$RVX6_7"  # Create $RVX6_7 dir if Android version is 6 or 7
Download="/sdcard/Download"
BugReportUrl="https://github.com/inotia00/ReVanced_Extended/issues/new?template=bug-report.yml"
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

# Get compatiblePackages version from json
getVersion() {
  local pkgName="$1"
  
  preVersion=$($PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | tail -n 1)
  pre_stock_apk_path=$(find "$Download" -type f -name "${appName[0]}_v${preVersion}-*.apk" -print -quit)
  [[ -f "$pre_stock_apk_path" ]] && rm "$pre_stock_apk_path"  # Remove previous stock apk if exists
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$($PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
}

#  --- Patch Apps ---
patch_app() {
  local stock_apk_path=$1
  local -n patches=$2  # nameref (-n) accept an array name as parameter
  local outputAPK=$3
  without_ext="${outputAPK%.*}"  # remove file extension (.apk)
  local log=$4
  local appName=$5
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
    --purge $ripLib --unsigned -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "$stock_apk_path" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "$Url"
    termux-open --send "$log"
    rm -rf "$without_ext-temporary-files"  # Remove temporary files directory
  else
    [[ -f "$without_ext.keystore" ]] && rm "$without_ext.keystore"
  fi
}

# --- Collect the enable/disable patches name with options in arrays ---
yt_patches_args=(
  # enable patches with their options
  -e "Custom Shorts action buttons" -OiconType="round"
  -e "Custom branding icon for YouTube" -OappIcon="$SimplUsr/.branding/youtube/launcher/google_family" -OchangeSplashIcon=true -OrestoreOldSplashAnimation=false
  -e "Custom header for YouTube" -OcustomHeader="$SimplUsr/.branding/youtube/header/google_family"
  -e "Custom branding name for YouTube" -OappName="YouTube"
  -e "Hide shortcuts" -Oshorts=false
  -e "Visual preferences icons for YouTube" -OsettingsMenuIcon="extension"
  -e "Overlay buttons" -OiconType=thin
  -e "Spoof streaming data" -OuseIOSClient
  -e "Settings for YouTube" -OinsertPosition="@string/about_key" -OrvxSettingsLabel=RVX
  -e "Force hide player buttons background"
  -e=MaterialYou -e Theme
  -e="Return YouTube Username"
  
  # disable patches
  -d "GmsCore support"
)

yt_music_patches_args=(
  -e "Custom branding icon for YouTube Music" -OappIcon="$SimplUsr/.branding/music/launcher/google_family"
  -e "Custom header for YouTube Music" -OcustomHeader="$SimplUsr/.branding/music/header/google_family"
  -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music" -OappNameLauncher="YT Music"
  -e "Dark theme" -OmaterialYou=true
  -e "Visual preferences icons for YouTube Music" -OsettingsMenuIcon="extension"
  -e "Settings for YouTube Music" -OrvxSettingsLabel="RVX"
  -e "Custom header for YouTube Music"
  -e="Return YouTube Username" -e "Disable music video in album"
  
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
  
  
  bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "$Arch"  # Download stock apk from APKMirror
  sleep 0.5  # Wait 500 milliseconds
  second=1
  while true; do
    if [ -f "${stock_apk_path[0]}" ]; then
      break
    fi
    if [ $second -ge 30 ]; then
      echo -e "$notice Oops, ${appNameRef[0]} APK not found in $Download dir after waiting 30 seconds!"
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
    
    if [ "$pkgName" == "com.google.android.youtube" ]; then
      
      echo -e "[?] ${Yellow}Please select installation type - 'M' for Mount or 'I' for SU-Install or 'N' for Installation cancel. [M/i/N]: ${Reset}\c" && read opt
      case $opt in
        I*|i*|"")
          checkCoreLSPosed  # Call the check core patch functions
          echo -e "$running Copy signature from ${appNameRef[0]}.."
          cs "${stock_apk_ref[0]}" "$outputAPK" "$SimplUsr/${appNameRef[0]}-RVX-CS_v${pkgVersion}-$Arch.apk"
          echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RVX CS apk.."
          bash $Simplify/apkInstall.sh "$SimplUsr/${appNameRef[0]}-RVX-CS_v${pkgVersion}-$Arch.apk" "$pkgName" ""
          ;;
        M*|m*)
          echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RVX apk.."
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" | tee "$SimplUsr/${appNameRef[0]}-RVX_mount_log.txt"
          rm $outputAPK
          ;;
        N*|n*) echo -e "$notice ${appNameRef[0]} RVX Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} RVX Installaion skipped." ;;
      esac

    else
      
      echo -e "[?] ${Yellow}Do you want to Mount ${appNameRef[0]} RVX app? [Y/n] ${Reset}\c" && read opt
      case $opt in
        y*|Y*|"")
          echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RVX apk.."
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" | tee "$SimplUsr/${appNameRef[0]}-RVX_mount_log.txt"
          rm $outputAPK
          ;;
        n*|N*) echo -e "$notice ${appNameRef[0]} RVX Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} RVX Installaion skipped." ;;
      esac

    fi

  fi
}

overwriteArch() {
  if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
    cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
    echo -e "$info Device architecture spoofed to $cpuAbi!"
  else
    echo -e "$info Device architecture not spoofed yet!"
  fi
    echo -e "0. Disabled spoofing\n8. arm64-v8a\n7. armeabi-v7a\n4. x86_64\n6. x86\n"
    read -r -p "Select: " arch
    case "$arch" in
      0)
        echo -e "$running Disabling device architecture spoofing.."
        jq -e 'del(.DeviceArch)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete DeviceArch key from simplify.json
        echo -e "$good ${Green}Device architecture spoofing disabled successfully!${Reset}"
        ;;
      8)
        echo -e "$running Spoofing device architecture to arm64-v8a.."
        jq ".DeviceArch = \"arm64-v8a\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
        echo -e "$good ${Green}Device architecture spoofed to arm64-v8a successfully!${Reset}"
        ;;
      7)
        echo -e "$running Spoofing device architecture to armeabi-v7a.."
        jq ".DeviceArch = \"armeabi-v7a\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
        echo -e "$good ${Green}Device architecture spoofed to armeabi-v7a successfully!${Reset}"
        ;;
      4)
        echo -e "$running Spoofing device architecture to x86_64.."
        jq ".DeviceArch = \"x86_64\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
        echo -e "$good ${Green}Device architecture spoofed to x86_64 successfully!${Reset}"
        ;;
      6)
        echo -e "$running Spoofing device architecture to x86.."
        jq ".DeviceArch = \"x86\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
        echo -e "$good ${Green}Device architecture spoofed to x86 successfully!${Reset}"
        ;;
      *) echo -e "$info Invalid input! Please enter 0, 8, 7, 4, 6." ;;
    esac
  if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
    cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
  else
    cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
  fi
}

# Define the array
if [ $Android -ge 8 ] || [ $Android -eq 7 ] || [ $Android -eq 6 ]; then
  apps=(
    Quit
    YouTube
    YT\ Music
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
  elif [[ "$idx" =~ ^[aA][rR][cC][hH] ]]; then
    overwriteArch  # Call the overwriteArch function
  elif [ "$idx" == "" ] || [ -z "$idx" ]; then
    if [ $release == "latest" ]; then
      tag=$(curl -sL ${auth} "https://api.github.com/repos/$owner/revanced-patches/releases/latest" | jq -r '.tag_name')
    else
      tag=$(curl -sL ${auth} "https://api.github.com/repos/$owner/revanced-patches/releases" | jq -r '.[].tag_name | select(contains("dev"))' | head -n 1)
    fi
    curl -sL ${auth} "https://api.github.com/repos/$owner/revanced-patches/releases/tags/$tag" | jq -r .body | glow  # Display the release notes
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
      Type="APK"
      Arch="universal"
      stock_apk_path=("$Download/YouTube_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/youtube-rvx_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-rvx-patch_log.txt"
      appName=("YouTube")
      build_app "$pkgName" "$pkgVersion" "$Type" "$Arch" "stock_apk_path" "yt_patches_args" "$outputAPK" "$log" "appName" "$BugReportUrl"
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
      stock_apk_path=("$Download/YouTube Music_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/yt-music-rvx_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-music-rvx-patch_log.txt"
      appName=("YouTube Music")
      build_app "$pkgName" "$pkgVersion" "$Type" "$cpuAbi" "stock_apk_path" "yt_music_patches_args" "$outputAPK" "$log" "appName" "$BugReportUrl"
      ;;
  esac  
done
#################################################################################################################################################