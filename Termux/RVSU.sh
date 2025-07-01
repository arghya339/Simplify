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

#bash $Simplify/dlGitHub.sh "ReVanced" "revanced-patches" "latest" ".rvp" "$RV"
bash $Simplify/dlGitHub.sh "ReVanced" "revanced-patches" "pre" ".rvp" "$RV"
PatchesRvp=$(find "$RV" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

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
  local -n stock_apk_path=$1
  local -n patches=$2  # nameref (-n) accept an array name as parameter
  local outputAPK=$3
  local log=$4
  local appName=$5
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "${stock_apk_path[0]}" \
    "${patches[@]}" \
    -e "Change version code" -OversionCode="2147483647" -e "Disable Pairip license check" -e "Predictive back gesture" -e "Remove share targets" \
    --custom-aapt2-binary="$HOME/aapt2" \
    --purge $ripLib --unsigned -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "${stock_apk_path[0]}" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/ReVanced/revanced-patches/issues/new?template=bug_report.yml"
    termux-open --send "$log"
  fi
}

# --- Collect the enable/disable patches name with options in arrays ---
yt_patches_args=(
  # enable patches with their options
  -e "Custom branding" -O appName="YouTube RV" -O iconPath="$SimplUsr/branding/youtube/launcher/google_family"
  -e "Change header" -O header="$SimplUsr/branding/youtube/header/google_family"
  
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
  echo -e "$notice DEBUG - archRef: ${archRef[0]}"
  local web=$6
  local -n stock_apk_path=$7
  local appPatchesArgs=$8
  local outputAPK=$9
  local fileName=$(basename $outputAPK)
  local log=$10
  

  if [ "$web" == "APKMirror" ]; then
    bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
  else
    bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from Uptodown
  fi
  
  if [ -f "${stock_apk_path[0]}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_path[0]}"
    echo -e "$running Patching ${appNameRef[0]} RV.."
    patch_app "stock_apk_path" "$appPatchesArgs" "$outputAPK" "$log" "${appNameRef[0]}"
  fi
  
  if [ -f "$outputAPK" ]; then
    
    if [ "$pkgName" == "com.google.android.youtube" ]; then
      
      echo -e "[?] ${Yellow}Please select installation type - 'M' for Mount or 'I' for SU-Install or 'N' for Installation cancel. [M/i/N]: ${Reset}\c" && read opt
      case $opt in
        I*|i*|"")
          checkCoreLSPosed  # Call the check core patch functions
          echo -e "$running Copy signature from ${appNameRef[0]}.."
          cs "${stock_apk_path[0]}" "$outputAPK" "$SimplUsr/${appNameRef[0]}-RV-CS_v${pkgVersion}-${archRef[0]}.apk"
          echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RV CS apk.."
          bash $Simplify/apkInstall.sh "$SimplUsr/${appNameRef[0]}-RV-CS_v${pkgVersion}-${archRef[0]}.apk" "$pkgName" ""
          ;;
        M*|m*)
          echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RV apk.."
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh ${stock_apk_path[0]} $outputAPK ${appNameRef[0]} $pkgName $pkgVersion" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh ${stock_apk_path[0]} $outputAPK ${appNameRef[0]} $pkgName $pkgVersion" | tee "$SimplUsr/${appNameRef[0]}-RV_mount-log.txt"
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
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh ${stock_apk_path[0]} $outputAPK ${appNameRef[0]} $pkgName $pkgVersion" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh ${stock_apk_path[0]} $outputAPK ${appNameRef[0]} $pkgName $pkgVersion" | tee "$SimplUsr/${appNameRef[0]}-RV_mount-log.txt"
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
  googleRecorder=("Google Recorder")
fi

if [ $Android -ge 10 ]; then
  apps=(
    Quit
    YouTube
    Google\ Photos
    "${googleRecorder[0]}"
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
      #pkgVersion="20.13.41"
      pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("universal")
      yt_apk_path=("$Download/YouTube_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/youtube-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-rv-patch_log.txt"
      appName=("YouTube")
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "yt_apk_path" "yt_patches_args" "$outputAPK" "$log"
      ;;
    Google\ Recorder)
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
      recorder_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/recorder-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/recorder-rv-patch_log.txt"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "recorder_apk_path" "recorder_patches_args" "$outputAPK" "$log"
      ;;
  esac  
done
#############################################################################################################################################