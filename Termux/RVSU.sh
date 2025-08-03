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
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
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
if [ $Android -le 4 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by ReVanced Patches.${Reset}"
  return 1
fi

echo -e "$info ${Blue}Target device:${Reset} $Model"

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

bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

if [ "$FetchPreRelease" -eq 0 ]; then
  release="latest"  # Use latest release
else
  release="pre"  # Use pre-release
fi
bash $Simplify/dlGitHub.sh "ReVanced" "revanced-patches" "$release" ".rvp" "$RV"
PatchesRvp=$(find "$RV" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

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

#  --- Patch Apps ---
patch_app() {
  local stock_apk_path=$1
  local -n patches=$2  # nameref (-n) accept an array name as parameter
  local outputAPK=$3
  without_ext="${outputAPK%.*}"  # remove file extension (.apk)
  local log=$4
  local appName=$5
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "$stock_apk_path" \
    "${patches[@]}" \
    -e "Change version code" -OversionCode="2147483647" -e "Disable Pairip license check" -e "Predictive back gesture" -e "Remove share targets" \
    --custom-aapt2-binary="$HOME/aapt2" \
    --purge $ripLib --unsigned -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "$stock_apk_path" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/ReVanced/revanced-patches/issues/new?template=bug_report.yml"
    termux-open --send "$log"
    rm -rf "$without_ext-temporary-files"  # Remove temporary files directory
  else
    rm "$without_ext.keystore"
  fi
}

# --- Collect the enable/disable patches name with options in arrays ---
yt_patches_args=(
  # enable patches with their options
  -e "Custom branding" -O appName="YouTube RV" -O iconPath="$SimplUsr/.branding/youtube/launcher/google_family"
  -e "Change header" -O header="$SimplUsr/.branding/youtube/header/google_family"
  
  # disable patches
  -d "GmsCore support"
  -d "Announcements"
)

photos_patches_args=(
  -d "GmsCore support"
)

recorder_patches_args=()

# --- Build App ---
build_app() {
  # local variables
  local pkgName=$1
  local -n appNameRef=$2
  local pkgVersion=$3
  local Type=$4
  local -n archRef=$5
  local web=$6
  local -n stock_apk_ref=$7
  local appPatchesArgs=$8
  local outputAPK=$9
  local fileName=$(basename $outputAPK)
  local log=$10
  

  if [ "$web" == "APKMirror" ]; then
    bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
  else
    bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from Uptodown
  fi
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
    echo -e "$running Patching ${appNameRef[0]} RV.."
    patch_app "${stock_apk_ref[0]}" "$appPatchesArgs" "$outputAPK" "$log" "${appNameRef[0]}"
  fi
  
  if [ -f "$outputAPK" ]; then
    
    if [ "$pkgName" == "com.google.android.youtube" ]; then
      
      echo -e "[?] ${Yellow}Please select installation type - 'M' for Mount or 'I' for SU-Install or 'N' for Installation cancel. [M/i/N]: ${Reset}\c" && read opt
      case $opt in
        I*|i*|"")
          checkCoreLSPosed  # Call the check core patch functions
          echo -e "$running Copy signature from ${appNameRef[0]}.."
          cs "${stock_apk_ref[0]}" "$outputAPK" "$SimplUsr/${appNameRef[0]}-RV-CS_v${pkgVersion}-${archRef[0]}.apk"
          echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RV CS apk.."
          bash $Simplify/apkInstall.sh "$SimplUsr/${appNameRef[0]}-RV-CS_v${pkgVersion}-${archRef[0]}.apk" "$pkgName" ""
          ;;
        M*|m*)
          echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RV apk.."
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" | tee "$SimplUsr/${appNameRef[0]}-RV_mount-log.txt"
          rm $outputAPK
          ;;
        N*|n*) echo -e "$notice ${appNameRef[0]} RV Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} RV Installaion skipped." ;;
      esac

    else
      
      echo -e "[?] ${Yellow}Do you want to Mount ${appNameRef[0]} RV app? [Y/n] ${Reset}\c" && read opt
      case $opt in
        y*|Y*|"")
          echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RV apk.."
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" | tee "$SimplUsr/${appNameRef[0]}-RV_mount-log.txt"
          rm $outputAPK
          ;;
        n*|N*) echo -e "$notice ${appNameRef[0]} RV Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} RV Installaion skipped." ;;
      esac

    fi

  fi
}

# Req
<<comment
  YouTube 8.0+
  Google Photos 5.0+
  Google Recorder 10+
comment

if [ "$cpuAbi" == "arm64-v8a" ]; then
  googleRecorder="GoogleRecorder"
fi

if [ $Android -ge 10 ]; then
  apps=(
    Quit
    YouTube
    Google\ Photos
    ${googleRecorder}
  )
elif [ $Android -eq 9 ]; then
  apps=(
    Quit
    YouTube
    Google\ Photos
  )
elif [ $Android -eq 8 ]; then
  apps=(
    Quit
    YouTube
    Google\ Photos
  )
elif [ $Android -eq 7 ]; then
  apps=(
    Quit
    Google\ Photos
  )
elif [ $Android -eq 6 ]; then
  apps=(
    Quit
    Google\ Photos
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    Google\ Photos
  )
fi

while true; do
  # Display the list
  echo -e "$info Available apps:"
  for i in "${!apps[@]}"; do
    if [ -n "${apps[$i]}" ] && [ "${apps[$i]}" != "null" ]; then
      printf "%d. %s\n" "$i" "${apps[$i]}"
    fi
  done

  # Ask for an index, showing the valid range
  max=$(( ${#apps[@]} - 1 ))  # highest legal index
  read -rp "Enter the index [0-${max}] of apps you want to patch or '0' to Quit: " idx

  # Validate and respond
  if [ "$idx" == 0 ]; then
    break  # break the while loop
  elif [ "$idx" == "" ] || [ -z "$idx" ]; then
    if [ $release == "latest" ]; then
      tag=$(curl -sL ${auth} "https://api.github.com/repos/ReVanced/revanced-patches/releases/latest" | jq -r '.tag_name')
    else
      tag=$(curl -sL ${auth} "https://api.github.com/repos/ReVanced/revanced-patches/releases" | jq -r '.[].tag_name | select(contains("dev"))' | head -n 1)
    fi
    curl -sL ${auth} "https://api.github.com/repos/ReVanced/revanced-patches/releases/tags/$tag" | jq -r .body | glow  # Display the release notes
  elif [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice You chose: ${apps[$idx]}"
  else
    echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
  fi
  
  case "${apps[$idx]}" in
    YouTube)
      pkgName="com.google.android.youtube"
      #pkgVersion="20.13.41"
      pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("universal")
      stock_apk_path=("$Download/YouTube_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/youtube-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-rv-patch_log.txt"
      appName=("YouTube")
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "stock_apk_path" "yt_patches_args" "$outputAPK" "$log"
      ;;
    Google\ Photos)
      pkgName="com.google.android.apps.photos"
      appName=("Google Photos")
      if [ $Android -ge 6 ]; then
        pkgVersion="6.95.0.663027175"
        #pkgVersion=""
        if [ -z "$pkgVersion" ]; then
          getVersion "$pkgName"
          pkgVersion="$pkgVersion"
        fi
      elif [ $Android -eq 5 ]; then
        pkgVersion="5.78.0.430249291"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      stock_apk_path=("$Download/${appName[0]}_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/google-photos-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/google-photos-rv_patch-log.txt"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "stock_apk_path" "photos_patches_args" "$outputAPK" "$log"
      ;;
    GoogleRecorder)
      pkgName="com.google.android.apps.recorder"
      appName=("Google Recorder")
      pkgVersion="4.2.20230801.561280372"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      stock_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/recorder-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/recorder-rv-patch_log.txt"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "stock_apk_path" "recorder_patches_args" "$outputAPK" "$log"
      ;;
  esac  
done
#############################################################################################################################################
