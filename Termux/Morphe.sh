#!/usr/bin/bash

[ $su -eq 1 ] && echo -e "$info ${Blue}Target device:${Reset} $Model ($Serial)" || echo -e "$info ${Blue}Target device:${Reset} $Model"

branding "morphe_branding"  # Call branding function

bash $Simplify/dlGitHub.sh "MorpheApp" "morphe-cli" "latest" ".jar" "$Morphe"
MorpheCLIJar=$(find "$Morphe" -type f -name "morphe-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}MorpheCLIJar:${Reset} $MorpheCLIJar"

if [ $FetchPreRelease -eq 0 ]; then
  release="latest"  # Use latest release
  branch="main"
else
  release="pre"  # Use pre-release
  branch="dev"
fi

morphePatchesBundleJson=$(curl -sL "https://raw.githubusercontent.com/MorpheApp/morphe-patches/refs/heads/${branch}/patches-bundle.json")
downloadUrl=$(jq -r '.download_url' <<< "$morphePatchesBundleJson")
PatchesMpp="$Morphe/$(basename "$downloadUrl")"
findPatchesMpp=$(find "$Morphe" -type f -name "patches-*.mpp" -print -quit)
dlPatchesMpp() {
  while true; do
    curl -L -C - --progress-bar -o "$PatchesMpp" "$downloadUrl"
    [ $? -eq 0 ] && break || { echo -e "${bad} ${Red}Download failed! retrying in 5 seconds..${Reset}"; sleep 5; }
  done
}
if [ -f "$findPatchesMpp" ]; then
  [ "$(basename "$findPatchesMpp" 2>/dev/null)" != "$(basename "$PatchesMpp" 2>/dev/null)" ] && { echo -e "$notice diffs: "$(basename $PatchesMpp 2>/dev/null)" ~ $(basename $findPatchesMpp)"; rm -f "$findPatchesMpp"; dlPatchesMpp; }
else
  dlPatchesMpp
fi

#bash $Simplify/dlGitHub.sh "MorpheApp" "morphe-patches" "$release" ".mpp" "$Morphe"
#PatchesMpp=$(find "$Morphe" -type f -name "patches-*.mpp" -print -quit)
echo -e "$info ${Blue}PatchesMpp:${Reset} $PatchesMpp"

if [ $su -eq 0 ]; then
  bash $Simplify/dlGitHub.sh "MorpheApp" "MicroG-RE" "latest" ".apk" "$SimplUsr"
  MicroGRE=$(find "$SimplUsr" -type f -name "MicroG-RE-*.apk" -print -quit)
fi

getVersion() {
  pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $MorpheCLIJar list-versions $PatchesMpp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
}

patch_app() {
  local stock_apk_ref="${1}"
  local -n patches=$2
  local outputAPK=$3
  without_ext="${outputAPK%.*}"
  local log="$SimplUsr/$appName-Morphe_patch-log.txt"
  local appName=$4

  echo -e "$running Patching ${appName}.."
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $MorpheCLIJar patch -p $PatchesMpp -o "$outputAPK" "${stock_apk_ref}" "${patches[@]}" --purge -f | tee "$log"

  if grep -q "OutOfMemory" "$log"; then
    echo -e "$bad ${Red}OutOfMemoryError${Reset}: ${Yellow}Device RAM overloaded!${Reset}\n ${Blue}Solutions${Reset}:\n   1. ${Yellow}Close background apps.${Reset}\n   2. ${Yellow}Use device with ≥4GB ~ ≥6GB RAM for patching apk.${Reset}"
  elif [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/MorpheApp/morphe-patches/issues/new?template=bug_report.yml"
    termux-open --send "$log"
    rm -rf "$without_ext-temporary-files"
  else
    rm -f "$without_ext.keystore"
  fi
}

yt_patches_args=(-e "Change header" -O custom="$SimplUsr/.morphe_branding/youtube/header/$Branding")

[ $su -eq 1 ] && yt_patches_args+=(-d "GmsCore support" -e "Custom branding" -O customName=YouTube -O customIcon="$SimplUsr/.morphe_branding/youtube/launcher/$Branding") || yt_patches_args+=(-e "Custom branding" -O customName="YouTube Morphe" -O customIcon="$SimplUsr/.morphe_branding/youtube/launcher/$Branding")

[ $su -eq 1 ] && yt_music_patches_args=(-d "GmsCore support" -e "Custom branding" -O customName="YouTube Music" -O customIcon="$SimplUsr/.morphe_branding/music/launcher/$Branding") || yt_music_patches_args=(-e "Custom branding" -O customName="YouTube Music Morphe" -O customIcon="$SimplUsr/.morphe_branding/music/launcher/$Branding")

if [ "$ReadPatchesFile" -eq 1 ]; then
  default_content=(
    # [0] YouTube
    '-e "Change header" -O custom="/sdcard/Simplify/.morphe_branding/youtube/header/google_family"'

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
          if [ "${arraynames[$i]}" == "yt_patches_args" ]; then
            echo "-e \"Custom branding\" -O customName=YouTube -O customIcon=\"/sdcard/Simplify/.morphe_branding/youtube/launcher/google_family\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          else
            echo "-e \"Custom branding\" -O customName="YouTube Music" -O customIcon=\"/sdcard/Simplify/.morphe_branding/music/launcher/google_family\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          fi
        else
          if [ "${arraynames[$i]}" == "yt_patches_args" ]; then
            echo "-e \"Custom branding\" -O customName="YouTube Morphe" -O customIcon=\"/sdcard/Simplify/.morphe_branding/youtube/launcher/google_family\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          else
            echo "-e \"Custom branding\" -O customName="YouTube Music Morphe" -O customIcon=\"/sdcard/Simplify/.morphe_branding/music/launcher/google_family\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          fi
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
  buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install ${appNameRef[0]} Morphe app?" "buttons" && opt=Yes || opt=No
  case $opt in
    Yes)
      echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} Morphe apk.."
      apkInstall "$outputAPK" "$activityPatched"
      ;;
    No) echo -e "$notice ${appNameRef[0]} Morphe Installaion skipped!" ;;
  esac
    
  buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share ${appNameRef[0]} Morphe app?" "buttons" "1" && opt=Yes || opt=No
  case $opt in
    Yes)
      echo -e "$running Please Wait !! Sharing Patched ${appNameRef[0]} Morphe apk.."
      termux-open --send "$outputAPK"
      ;;
    No) echo -e "$notice ${appNameRef[0]} Morphe Sharing skipped!"
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

  APKMdl "$pkgName" "" "$pkgVersion" "$Type" "${archRef[0]}"
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

  local outputAPK="$SimplUsr/${appNameRef[0]}-Morphe_v${pkgVersion}-$cpuAbi.apk"
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
        confirmPrompt "Select ${appNameRef[0]} Morphe installation operation" "buttons" "1"
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
            cs "${stock_apk_path[0]}" "$outputAPK" "$SimplUsr/${appNameRef[0]}-Morphe-CS_v${pkgVersion}-${archRef[0]}.apk"
            termux-wake-unlock
            echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} Morphe CS apk.."
            apkInstall "$SimplUsr/${appNameRef[0]}-Morphe-CS_v${pkgVersion}-${archRef[0]}.apk" ""
            ;;
          M*|m*)
            echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} Morphe apk.."
            su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" &> /dev/null
            su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" | tee "$SimplUsr/${appNameRef[0]}-Morphe_mount-log.txt"
            rm -f "$outputAPK"
            ;;
          C*|c*) echo -e "$notice ${appNameRef[0]} Morphe Installaion skipped!" ;;
        esac
      elif [ "$pkgName" == "com.google.android.apps.youtube.music" ]; then
        buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Mount ${appNameRef[0]} Morphe app?" "buttons" && opt=Yes || opt=No
        case $opt in
          y*|Y*|"")
            echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} Morphe apk.."
            su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" &> /dev/null
            su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" | tee "$SimplUsr/${appNameRef[0]}-Morphe_mount-log.txt"
            rm -f "$outputAPK"
            ;;
          n*|N*) echo -e "$notice ${appNameRef[0]} Morphe Installaion skipped!" ;;
        esac
      fi
    else
      echo -e "$info MicroG-RE is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have MicroG-RE, You don't need to install it."
      buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install MicroG-RE app?" "buttons" && opt=Yes || opt=No
      case $opt in
        Yes)
          echo -e "$running Please Wait !! Installing MicroG-RE apk.."
          apkInstall "$MicroGRE" "app.revanced.android.gms/org.microg.gms.ui.SettingsActivity"
          ;;
        No) echo -e "$notice MicroG-RE Installaion skipped!" ;;
      esac
      commonPrompt
    fi
  fi
}

getListOfPatches() {
  local pkgName="$1"
  Patches=$(curl -sL "https://raw.githubusercontent.com/MorpheApp/morphe-patches/refs/heads/${branch}/patches-list.json" | jq --arg pkgName "$pkgName" '.patches[] | select(if $pkgName == "null" then .compatiblePackages == null else .compatiblePackages[$pkgName] != null end)')
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
  buttons=("<Select>" "<Back>"); if menu options buttons; then selected="${options[$selected]}"; else break; fi
  case "$selected" in
    CHANGELOG)
      jq -r '.description' <<< "$morphePatchesBundleJson" | glow
      ;;
    Spoof\ Device\ Arch) overwriteArch ;;
    List\ of\ Patches)
      apps_list=(universal-patches)
      apps_list+=("${apps[@]}")
      
      buttons=("<Select>" "<Back>"); if menu apps_list buttons; then selected="${apps_list[$selected]}"; fi
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
      [ $Android -eq 8 ] && pkgVersion="20.26.46" || pkgVersion="20.37.48"
      ([ $Android -ge 9 ] && [ $FetchPreRelease -eq 1 ]) && pkgVersion="21.04.221"
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("universal")
      pkgPatched="app.morphe.android.youtube"
      activityPatched="app.morphe.android.youtube/.morphe_black_1"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "yt_patches_args" "$pkgPatched" "$activityPatched"
      ;;
    YTMusic)
      pkgName="com.google.android.apps.youtube.music"
      appName=("YouTube Music")
      pkgVersion="8.37.56"
      [ $FetchPreRelease -eq 1 ] && pkgVersion="9.03.52"
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      pkgPatched="app.morphe.android.apps.youtube.music"
      activityPatched="app.morphe.android.apps.youtube.music/.morphe_black_1"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "yt_music_patches_args" "$pkgPatched" "$activityPatched"
      ;;
  esac
  echo; read -p "Press Enter to continue..."
done
