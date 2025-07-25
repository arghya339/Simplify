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
Dropped="$Simplify/Dropped"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$RVX" "$Dropped" "$SimplUsr"  # Create $Simplify, $RV, $RVX and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir

# --- Checking Android Version ---
if [ $Android -le 4 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by Dropped Patches.${Reset}"
  return 1
fi

echo -e "$info ${Blue}Target device:${Reset} $Model"

bash $Simplify/dlGitHub.sh "arghya339" "revanced-cli" "pre" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

bash $Simplify/dlGitHub.sh "indrastorms" "Dropped-Patches" "latest" ".rvp" "$Dropped"
PatchesRvp=$(find "$Dropped" -type f -name "patches-*.rvp" -print -quit)
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

if [ -f "$Dropped/patches.json" ]; then
  rm $Dropped/patches.json
  touch "$Dropped/patches.json"  # Create patches json file
fi
$PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patches -p="$Dropped/patches.json" $PatchesRvp
if [ $? == 0 ] && [ -f "$Dropped/patches.json" ]; then
  echo -e "$info patches.json generated successfully."
  jq -r '.[] | .compatiblePackages // empty | .[] | {name: .name, version: .versions[-1]} | "\(.name) \(.version)"' $Dropped/patches.json | sort -u | awk '{a[$1]=$2} END{for (i in a) printf "\"%s\" \"%s\"\n", i, a[i]}'
else
  echo -e "$bad patches.json was not generated!"
fi

# Get compatiblePackages version from json
getVersion() {
  local pkgName="$1"
  local json="$Dropped/patches.json"
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$(jq -r --arg pkg "$pkgName" '[.[] | .compatiblePackages // empty | .[] | select(.name == $pkg and .versions != null) | .versions[]] | sort | last' $json 2>/dev/null)
}

#  --- Patch Apps ---
patch_app() {
  local -n stock_apk_ref=$1
  local outputAPK=$2
  local log=$3
  local appName=$4
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "${stock_apk_ref[0]}" \
    --custom-aapt2-binary="$HOME/aapt2" --purge $ripLib -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/indrastorms/Dropped-Patches/issues/new"
    termux-open --send "$log"
  fi
}

# --- Build App ---
build_app() {
  # local variables
  local pkgName=$1
  local -n appNameRef=$2
  local pkgVersion=$3
  local Type=$4
  local -n archRef=$5
  local -n stock_apk_path=$6
  local outputAPK=$7
  local fileName=$(basename $outputAPK)
  local log=$8
  local pkgPatches=$9
  local activityPatches=$10
  

  bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
  
  if [ -f "${stock_apk_path[0]}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_path[0]}"
    echo -e "$running Patching ${appNameRef[0]} Dropped.."
    patch_app "stock_apk_path" "$outputAPK" "$log" "${appNameRef[0]}"
  fi
  
  if [ -f "$outputAPK" ]; then

    echo -e "[?] ${Yellow}Do you want to install ${appNameRef[0]} Dropped app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$notice ${Yellow}Warning! Disable auto updates for the patched app to avoid unexpected issues.${Reset}"
        echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} Dropped apk.."
        bash $Simplify/apkInstall.sh "$outputAPK" "$pkgPatches" "$activityPatches"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} Dropped Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! ${appNameRef[0]} Dropped Installaion skipped." ;;
    esac
    
    echo -e "[?] ${Yellow}Do you want to Share ${appNameRef[0]} Dropped app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Sharing Patched ${appNameRef[0]} Dropped apk.."
        termux-open --send "$outputAPK"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} Dropped Sharing skipped!"
        echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
        ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} Dropped Sharing skipped." ;;
    esac
  
  fi
}

# Req
<<comment
  Nova Launcher 8.0+
  Tasker 5.0+
comment

if [ $cpuAbi == "arm64-v8a" ] || [ $cpuAbi == "armeabi-v7a" ]; then
  novaLauncher=("Nova Launcher")
fi

if [ $Android -ge 8 ]; then
  apps=(
    Quit
    "${novaLauncher[0]}"
    Tasker
  )
elif [ $Android -eq 7 ]; then
  apps=(
    Quit
    Tasker
  )
elif [ $Android -eq 6 ]; then
  apps=(
    Quit
    Tasker
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    Tasker
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
    Nova\ Launcher)
      pkgName="com.teslacoilsw.launcher"
      appName=("Nova Launcher")
      #pkgVersion="8.0.18"
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("arm64-v8a + armeabi-v7a")
      novaLauncherFileName=$(basename "$(find "$Download" -type f -name "${appName[0]}_v*-${Arch[0]}.apk" -print -quit)")
      nova_launcher_apk_path=("$Download/$novaLauncherFileName")
      outputAPK="$SimplUsr/nova-launcher-dropped_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/nova-launcher-dropped_patch-log.txt"
      activityPatches="com.teslacoilsw.launcher/.NovaShortcutHandler"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "nova_launcher_apk_path" "$outputAPK" "$log" "$pkgName" "$activityPatches"
      ;;
    Tasker)
      pkgName="net.dinglisch.android.taskerm"
      appName=("Tasker")
      #pkgVersion="6.3.13"
      pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("universal")
      taskerFileName=$(basename "$(find "$Download" -type f -name "${appName[0]}_v*-${Arch[0]}.apk" -print -quit)")
      tasker_apk_path=("$Download/$taskerFileName")
      outputAPK="$SimplUsr/tasker-dropped_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/tasker-dropped_patch-log.txt"
      activityPatches="net.dinglisch.android.taskerm/.Tasker"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "tasker_apk_path" "$outputAPK" "$log" "$pkgName" "$activityPatches"
      ;;
  esac  
done
#####################################################################################################################################