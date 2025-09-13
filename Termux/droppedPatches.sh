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
Simplify="$HOME/Simplify"  # /data/data/com.termux/files/home/Simplify dir
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
if jq -e '.AndroidVersion != null' "$simplifyJson" >/dev/null 2>&1; then
  Android=$(jq -r '.AndroidVersion' "$simplifyJson" 2>/dev/null)  # Get Android version from json
else
  Android=$(getprop ro.build.version.release | cut -d. -f1)  # Get major Android version
fi
if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
  cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
else
  cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
fi
if jq -e '.openjdk != null' "$simplifyJson" >/dev/null 2>&1; then
  jdkVersion=$(jq -r '.openjdk' "$simplifyJson" 2>/dev/null)  # Get openjdk value (verison) from json
else
  jdkVersion="21"
fi
Model=$(getprop ro.product.model)  # Get Device Model
RVX="$Simplify/RVX"
Dropped="$Simplify/Dropped"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$RVX" "$Dropped" "$SimplUsr"  # Create $Simplify, $RV, $RVX and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir
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

echo -e "$info ${Blue}Target device:${Reset} $Model"

bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

bash $Simplify/dlGitHub.sh "indrastorms" "Dropped-Patches" "latest" ".rvp" "$Dropped"
PatchesRvp=$(find "$Dropped" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

# --- Generate ripLib arg ---
if [ "$RipLib" -eq 1 ]; then
  all_arch="arm64-v8a armeabi-v7a x86_64 x86"  # all ABIs
  # Generate ripLib arguments for all ABIs EXCEPT the device ABI
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

# Get compatiblePackages version from patches
getVersion() {
  local pkgName="$1"
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
}

#  --- Patching Apps Method ---
patch_app() {
  local -n stock_apk_ref=$1
  local outputAPK=$2
  without_ext="${outputAPK%.*}"  # remove file extension (.apk)
  local log=$3
  local appName=$4
  
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "${stock_apk_ref[0]}" \
    --custom-aapt2-binary="$HOME/aapt2" --purge $ripLib -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/indrastorms/Dropped-Patches/issues/new"
    termux-open --send "$log"
    rm -rf "$without_ext-temporary-files"  # Remove temporary files directory
  else
    rm -f "$without_ext-options.json" && rm -f "$without_ext.keystore"
  fi
}

# --- function to Build App ---
build_app() {
  # local variables
  local pkgName=$1
  local -n appNameRef=$2
  local pkgVersion=$3
  local Type=$4
  local -n archRef=$5
  local outputAPK=$6
  local fileName=$(basename $outputAPK)
  local log=$7
  local pkgPatched=$8
  local activityPatched=$9
  

  bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
  stockFileName=$(basename "$(find "$Download" -type f -name "${appNameRef[0]}_v*-${archRef[0]}.apk" -print -quit)")
  local stock_apk_path=("$Download/$stockFileName")
  
  sleep 0.5  # Wait 500 milliseconds
  if [ -f "${stock_apk_path[0]}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_path[0]}"
    echo -e "$running Patching ${appNameRef[0]} Dropped.."
    termux-wake-lock
    patch_app "stock_apk_path" "$outputAPK" "$log" "${appNameRef[0]}"
    termux-wake-unlock
  fi
  
  if [ -f "$outputAPK" ]; then

    echo -e "[?] ${Yellow}Do you want to install ${appNameRef[0]} Dropped app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$notice ${Yellow}Warning! Disable auto updates for the patched app to avoid unexpected issues.${Reset}"
        echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} Dropped apk.."
        bash $Simplify/apkInstall.sh "$outputAPK" "$activityPatched"
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
        echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)" && sleep 3
        am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.google.android.documentsui/com.android.documentsui.files.FilesActivity &> /dev/null  # Open Android Files by Google
        if [ $? -ne 0 ] || [ $? -eq 2 ]; then
          am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.android.documentsui/com.android.documentsui.files.FilesActivity > /dev/null 2>&1  # Open Android Files
        fi
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


# --- Decisions block for app that required specific arch ---
if [ $cpuAbi == "arm64-v8a" ] || [ $cpuAbi == "armeabi-v7a" ]; then
  novaLauncher="NovaLauncher"
fi

# --- Arrays of apps list that required specific android version ---
if [ $Android -ge 8 ]; then
  apps=(
    Quit
    ${novaLauncher}
    Tasker
  )
elif [ $Android -eq 7 ] || [ $Android -eq 6 ] || [ $Android -eq 5 ]; then
  apps=(
    Quit
    Tasker
  )
fi

while true; do
  # Display the apps list
  echo -e "$info Available apps:"
  echo -e "↵. CHANGELOG"
  for i in "${!apps[@]}"; do
    if [ -n "${apps[$i]}" ] && [ "${apps[$i]}" != "null" ]; then
      printf "%d. %s\n" "$i" "${apps[$i]}"
    fi
  done

  # Ask for an index, showing the valid range
  max=$(( ${#apps[@]} - 1 ))  # highest legal index
  read -rp "Enter the index [0-${max}] of the apps you want to patch: " idx

  # Validate and respond
  if [ "$idx" == 0 ]; then
    break  # break the while loop
  elif [ "$idx" == "" ] || [ -z "$idx" ]; then
    curl -sL ${auth} "https://api.github.com/repos/indrastorms/Dropped-Patches/releases/latest" | jq -r .body | glow  # Display the release notes
  elif [[ $idx =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice Selected: ${apps[$idx]}"
  else
    echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
  fi
  
  # main conditional control flow
  case ${apps[$idx]} in
    NovaLauncher)
      pkgName="com.teslacoilsw.launcher"
      appName=("Nova Launcher")
      pkgVersion="8.0.18"
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("arm64-v8a + armeabi-v7a")
      outputAPK="$SimplUsr/nova-launcher-dropped_v${pkgVersion}-${Arch[0]}.apk"
      log="$SimplUsr/nova-launcher-dropped_patch-log.txt"
      activityPatched="com.teslacoilsw.launcher/.NovaShortcutHandler"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "$outputAPK" "$log" "$pkgName" "$activityPatched"
      ;;
    Tasker)
      pkgName="net.dinglisch.android.taskerm"
      appName=("Tasker")
      pkgVersion="6.5.11"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("universal")
      outputAPK="$SimplUsr/tasker-dropped_v${pkgVersion}-${Arch[0]}.apk"
      log="$SimplUsr/tasker-dropped_patch-log.txt"
      activityPatched="net.dinglisch.android.taskerm/.Tasker"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "$outputAPK" "$log" "$pkgName" "$activityPatched"
      ;;
  esac  
done
###################################################################################################################
