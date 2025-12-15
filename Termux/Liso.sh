#!/usr/bin/bash

[ $su -eq 1 ] && echo -e "$info ${Blue}Target device:${Reset} $Model ($Serial)" || echo -e "$info ${Blue}Target device:${Reset} $Model"

bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli-patcher-22" "pre" ".jar" "$Liso"
ReVancedCLIJar=$(find "$Liso" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

# https://github.com/Jman-Github/ReVanced-Patch-Bundles/?tab=readme-ov-file#-lisouseinaikyrios-patches-bundle-api-v4
lisoPatchesBundleJson=$(curl -sL "https://raw.githubusercontent.com/Jman-Github/ReVanced-Patch-Bundles/bundles/patch-bundles/lisouseInaikyrios-patch-bundles/lisouseInaikyrios-latest-patches-bundle.json")
downloadUrl=$(jq -r '.download_url' <<< "$lisoPatchesBundleJson")
PatchesRvp="$Liso/$(basename "$downloadUrl")"
findPatchesRvp=$(find "$Liso" -type f -name "patches-*.rvp" -print -quit)
dlPatchesRvp() {
  while true; do
    curl -L -C - --progress-bar -o "$PatchesRvp" "$downloadUrl"
    [ $? -eq 0 ] && break || { echo -e "${bad} ${Red}Download failed! retrying in 5 seconds..${Reset}"; sleep 5; }
  done
}
if [ -f "$findPatchesRvp" ]; then
  [ "$(basename "$findPatchesRvp" 2>/dev/null)" != "$(basename "$PatchesRvp" 2>/dev/null)" ] && { echo -e "$notice diffs: "$(basename $PatchesRvp 2>/dev/null)" ~ $(basename $findPatchesRvp)"; rm -f "$findPatchesRvp"; dlPatchesRvp; }
else
  dlPatchesRvp
fi

#bash $Simplify/dlGitHub.sh "LisoUseInAIKyrios" "revanced-patches" "latest" ".rvp" "$Liso"
#PatchesRvp=$(find "$Liso" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

if [ $su -eq 0 ]; then
  bash $Simplify/dlGitHub.sh "inotia00" "VancedMicroG" "latest" ".apk" "$SimplUsr"
  VancedMicroG=$(find "$SimplUsr" -type f -name "microg-*.apk" -print -quit)
fi

getVersion() {
  pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
}

patch_app() {
  local stock_apk_ref="${1}"
  local -n patches=$2
  local outputAPK=$3
  without_ext="${outputAPK%.*}"
  local log="$SimplUsr/$appName-Liso_patch-log.txt"
  local appName=$4

  echo -e "$running Patching ${appName} Liso.."
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp -o "$outputAPK" "${stock_apk_ref}" "${patches[@]}" --custom-aapt2-binary="$HOME/aapt2" --purge $ripLib -f | tee "$log"

  if grep -q "OutOfMemory" "$log"; then
    echo -e "$bad ${Red}OutOfMemoryError${Reset}: ${Yellow}Device RAM overloaded!${Reset}\n ${Blue}Solutions${Reset}:\n   1. ${Yellow}Close background apps.${Reset}\n   2. ${Yellow}Use device with ≥4GB ~ ≥6GB RAM for patching apk.${Reset}"
  elif [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/LisoUseInAIKyrios/revanced-patches/issues/new?template=bug_report.yml"
    termux-open --send "$log"
    rm -rf "$without_ext-temporary-files"
  else
    rm -f "$without_ext.keystore"
  fi
}

yt_patches_args=(-d "Announcements")

[ $su -eq 1 ] && yt_patches_args+=(-d "GmsCore support") || yt_patches_args+=(-e "GmsCore support" -O gmsCoreVendorGroupId="com.mgoogle")

yt_music_patches_args=()

[ $su -eq 1 ] && yt_music_patches_args+=(-d "GmsCore support") || yt_music_patches_args+=(-e "GmsCore support" -O gmsCoreVendorGroupId="com.mgoogle")

if [ "$ReadPatchesFile" -eq 1 ]; then
  default_content=(
    # [0] YouTube
    '-d "Announcements"'

    # [1] YouTube Music | No default patches
    ''
  )

  arraynames=(
    yt_patches_args
    yt_music_patches_args
  )

  for ((i=0; i<${#arraynames[@]}; i++)); do
    if [ ! -e "$SimplUsr/${arraynames[$i]}.txt" ]; then
      printf "%s\n" "${default_content[i]}" > "$SimplUsr/${arraynames[$i]}.txt"
      if [ "${arraynames[$i]}" == "yt_patches_args" ] || [ "${arraynames[$i]}" == "yt_music_patches_args" ]; then
        if [ $su -eq 1 ]; then
          echo "-d \"GmsCore support\"" >> "$SimplUsr/${arraynames[$i]}.txt"
        else
          echo "-e \"GmsCore support\" -O gmsCoreVendorGroupId=\"com.mgoogle\"" >> "$SimplUsr/${arraynames[$i]}.txt"
        fi
      fi
    fi
  done

  for (( i=0; i<${#arraynames[@]}; i++ )); do
    if [ -f "$SimplUsr/${arraynames[$i]}.txt" ]; then
      if [ -s "$SimplUsr/${arraynames[$i]}.txt" ]; then
        eval "${arraynames[$i]}=()"
        mapfile -t lines < "$SimplUsr/${arraynames[$i]}.txt"
        for line in "${lines[@]}"; do
          [ -z "$line" ] && continue
          eval "args=($line)"
          eval "${arraynames[$i]}+=(\"\${args[@]}\")"
        done
      else
        eval "${arraynames[$i]}=()"
      fi
    fi
  done
fi

commonPrompt() {
  buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install ${appNameRef[0]} Liso app?" "buttons" && opt=Yes || opt=No
  case $opt in
    Yes)
      echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} Liso apk.."
      apkInstall "$outputAPK" "$activityPatched"
      ;;
    No) echo -e "$notice ${appNameRef[0]} Liso Installaion skipped!" ;;
  esac
    
  buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share ${appNameRef[0]} Liso app?" "buttons" "1" && opt=Yes || opt=No
  case $opt in
    Yes)
      echo -e "$running Please Wait !! Sharing Patched ${appNameRef[0]} Liso apk.."
      termux-open --send "$outputAPK"
      ;;
    No) echo -e "$notice ${appNameRef[0]} Liso Sharing skipped!"
      echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)" && sleep 3
      am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.google.android.documentsui/com.android.documentsui.files.FilesActivity &> /dev/null  # Open Android Files by Google
      if [ $? -ne 0 ] || [ $? -eq 2 ]; then
        am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.android.documentsui/com.android.documentsui.files.FilesActivity > /dev/null 2>&1  # Open Android Files
      fi
      ;;
  esac
}

build_app() {
  local pkgName=$1
  local -n appNameRef=$2
  local appName="${appNameRef[0]}"
  local pkgVersion=$3
  local Type=$4
  local -n archRef=$5
  local arch="${archRef[0]}"
  local appPatchesArgs=$6
  local pkgPatched=$7
  local activityPatched=$8

  bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}"
  sleep 0.5
  if [ "$Type" == "APK" ]; then
    if [ "$pkgVersion" == "Any" ] || [ -z "$pkgVersion" ]; then
      fileNamePattern=("${appNameRef[0]}_v*-${archRef[0]}.apk")
      stock_apk_path=$(find "$Download" -type f -name "${fileNamePattern[0]}" -print -quit)
    elif [ -n "$pkgVersion" ] && [ "$pkgVersion" != "Any" ]; then
      stock_apk_path="$Download/${appNameRef[0]}_v${pkgVersion}-${archRef[0]}.apk"
    fi
  else
    if [ "$pkgVersion" == "Any" ] || [ -z "$pkgVersion" ]; then
      fileNamePattern=("${appNameRef[0]}_v*-$cpuAbi.apk")
      stock_apk_path=$(find "$Download" -type f -name "${fileNamePattern[0]}" -print -quit)
    elif [ -n "$pkgVersion" ] && [ "$pkgVersion" != "Any" ]; then
      stock_apk_path="$Download/${appNameRef[0]}_v${pkgVersion}-$cpuAbi.apk"
    fi
  fi

  local outputAPK="$SimplUsr/${appNameRef[0]}-Liso_v${pkgVersion}-$cpuAbi.apk"
  local fileName=$(basename $outputAPK 2>/dev/null)

  if [ -f "${stock_apk_path}" ]; then
    echo -e "$good ${Green}Downloaded ${appName} APK found:${Reset} ${stock_apk_path}"
    termux-wake-lock
    patch_app "$stock_apk_path" "$appPatchesArgs" "$outputAPK" "${appName}"
    termux-wake-unlock
  fi

  if [ -f "$outputAPK" ]; then
    if [ $su -eq 1 ]; then
      if [ "$pkgName" == "com.google.android.youtube" ]; then
        buttons=("<Install>" "<Mount>" "<Cancel>")
        confirmPrompt "Select ${appNameRef[0]} Liso installation operation" "buttons" "1"
        exit_status=$?
        if [ $exit_status -eq 0 ]; then opt=Install; elif [ $exit_status -eq 1 ]; then opt=Mount; elif [ $exit_status -eq 2 ]; then opt=Cancel; fi
        case $opt in
          I*|i*|"")
            if [ $su -eq 1 ]; then
              pkgInstall "python"
              ! pip list 2>/dev/null | grep -q "apksigcopier" && pip install apksigcopier > /dev/null 2>&1  # install apksigcopier using pip
            fi
            checkCoreLSPosed
            echo -e "$running Copy signature from ${appNameRef[0]}.."
            termux-wake-lock
            cs "${stock_apk_path[0]}" "$outputAPK" "$SimplUsr/${appNameRef[0]}-Liso-CS_v${pkgVersion}-${archRef[0]}.apk"
            termux-wake-unlock
            echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} Liso CS apk.."
            apkInstall "$SimplUsr/${appNameRef[0]}-Liso-CS_v${pkgVersion}-${archRef[0]}.apk" ""
            ;;
          M*|m*)
            echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} Liso apk.."
            su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" &> /dev/null
            su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" | tee "$SimplUsr/${appNameRef[0]}-Liso_mount-log.txt"
            rm -f "$outputAPK"
            ;;
          C*|c*) echo -e "$notice ${appNameRef[0]} Liso Installaion skipped!" ;;
        esac
      elif [ "$pkgName" == "com.google.android.apps.youtube.music" ]; then
        buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Mount ${appNameRef[0]} Liso app?" "buttons" && opt=Yes || opt=No
        case $opt in
          y*|Y*|"")
            echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} Liso apk.."
            su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" &> /dev/null
            su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" | tee "$SimplUsr/${appNameRef[0]}-Liso_mount-log.txt"
            rm -f "$outputAPK"
            ;;
          n*|N*) echo -e "$notice ${appNameRef[0]} Liso Installaion skipped!" ;;
        esac
      fi
    else
      echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
      buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install VancedMicroG app?" "buttons" && opt=Yes || opt=No
      case $opt in
        Yes)
          echo -e "$running Please Wait !! Installing VancedMicroG apk.."
          apkInstall "$VancedMicroG" "com.mgoogle.android.gms/org.microg.gms.ui.SettingsActivity"
          ;;
        No) echo -e "$notice VancedMicroG Installaion skipped!" ;;
      esac
      commonPrompt
    fi
  fi
}

getListOfPatches() {
  local pkgName="$1"
  # https://github.com/LisoUseInAIKyrios/revanced-patches/tree/dev/bundles
  Patches=$(curl -sL 'https://raw.githubusercontent.com/LisoUseInAIKyrios/revanced-patches/refs/heads/dev/bundles/lisouseInaikyrios-latest-patches-list.json' | jq --arg pkgName "$pkgName" '.patches[] | select(if $pkgName == "null" then .compatiblePackages == null else .compatiblePackages[$pkgName] != null end)')
  if [ "$ReadPatchesFile" -eq 1 ]; then
    jq <<< "$Patches" | tee "$SimplUsr/${pkgName}_list-patches.txt"
  else
    jq <<< "$Patches"
  fi
}

options=(CHANGELOG Spoof\ Device\ Arch List\ of\ Patches)

apps=(YouTube YTMusic)

options+=(${apps[@]})

while true; do
  buttons=("<Select>" "<Back>"); if menu "options" "buttons" "${#options[@]}"; then selected="${options[$selected]}"; else break; fi
  case "$selected" in
    CHANGELOG)
      jq -r '.description' <<< "$lisoPatchesBundleJson" | glow
      #tag=$(curl -sL ${auth} "https://api.github.com/repos/LisoUseInAIKyrios/revanced-patches/releases/latest"
      #curl -sL ${auth} "https://api.github.com/repos/LisoUseInAIKyrios/revanced-patches/releases/tags/$tag" | jq -r .body | glow
      ;;
    Spoof\ Device\ Arch) overwriteArch ;;
    List\ of\ Patches)
      apps_list=(universal-patches)
      apps_list+=("${apps[@]}")
      
      buttons=("<Select>" "<Back>"); if menu "apps_list" "buttons" "${#apps_list[@]}"; then selected="${apps_list[$selected]}"; fi
      if [ -n "$selected" ]; then
        case "$selected" in
          universal-patches)
            pkgName="null"
            getListOfPatches "$pkgName"
            ;;
          YouTube)
            pkgName="com.google.android.youtube"
            getListOfPatches "$pkgName"
            ;;
          YTMusic)
            pkgName="com.google.android.apps.youtube.music"
            getListOfPatches "$pkgName"
            ;;
        esac
      fi
      ;;
    YouTube)
      pkgName="com.google.android.youtube"
      appName=("YouTube")
      [ $Android -eq 8 ] && pkgVersion="20.26.46" || pkgVersion="20.46.41"
      ([ $Android -ge 9 ] && [ $FetchPreRelease -eq 1 ]) && pkgVersion="20.47.46"
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("universal")
      pkgPatched="app.revanced.android.youtube"
      activityPatched="app.revanced.android.youtube/.revanced_original_1"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "yt_patches_args" "$pkgPatched" "$activityPatched"
      ;;
    YTMusic)
      pkgName="com.google.android.apps.youtube.music"
      appName=("YouTube Music")
      pkgVersion="8.47.54"
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      pkgPatched="app.revanced.android.apps.youtube.music"
      activityPatched="app.revanced.android.apps.youtube.music/.revanced_original_1"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "yt_music_patches_args" "$pkgPatched" "$activityPatched"
      ;;
  esac
  echo; read -p "Press Enter to continue..."
done
