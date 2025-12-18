#!/usr/bin/bash

echo -e "$info ${Blue}Target device:${Reset} $Model"

bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

bash $Simplify/dlGitHub.sh "indrastorms" "Dropped-Patches" "latest" ".rvp" "$Dropped"
PatchesRvp=$(find "$Dropped" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

if [ $RipLib -eq 1 ]; then
  # Display the final ripLib arguments
  echo -e "$info ${Blue}cpuAbi:${Reset} $cpuAbi"
  echo -e "$info ${Blue}ripLib:${Reset} $ripLib"
else
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
  

  APKMdl "$pkgName" "" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
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

    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Install ${appNameRef[0]} Dropped app?" "buttons" && opt=Yes || opt=No
    case $opt in
      y*|Y*|"")
        echo -e "$notice ${Yellow}Warning! Disable auto updates for the patched app to avoid unexpected issues.${Reset}"
        echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} Dropped apk.."
        apkInstall "$outputAPK" "$activityPatched"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} Dropped Installaion skipped!" ;;
    esac
    
    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share ${appNameRef[0]} Dropped app?" "buttons" "1" && opt=Yes || opt=No
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
    CHANGELOG
    ${novaLauncher}
    Tasker
  )
elif [ $Android -eq 7 ] || [ $Android -eq 6 ] || [ $Android -eq 5 ]; then
  apps=(
    CHANGELOG
    Tasker
  )
fi

while true; do
  buttons=("<Select>" "<Back>"); if menu "apps" "buttons" "3"; then selected="${apps[$selected]}"; else break; fi
  
  # main conditional control flow
  case "$selected" in
    CHANGELOG) curl -sL ${auth} "https://api.github.com/repos/indrastorms/Dropped-Patches/releases/latest" | jq -r .body | glow; echo; read -p "Press Enter to continue..." ;;  # Display release notes
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
  sleep 5  # wait 5 seconds
done
###################################################################################################################
