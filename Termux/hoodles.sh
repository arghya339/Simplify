#!/usr/bin/bash

[ $FetchPreRelease -eq 0 ] && { release="latest"; branch="main"; } || { release="pre"; branch="dev"; }

bash $Simplify/dlGitHub.sh "MorpheApp" "morphe-cli" "$release" ".jar" "$Morphe"
MorpheCLIJar=$(find "$Morphe" -type f -name "morphe-cli-*-all.jar" -print -quit)

patchesBundleJson=$(curl -sL "https://raw.githubusercontent.com/hoo-dles/morphe-patches/refs/heads/${branch}/patches-bundle.json")
patchesDownloadURL=$(jq -r '.download_url' <<< "$patchesBundleJson")
patchesPath="$hoodles/$(basename "$patchesDownloadURL")"
localPatchesPath=$(find "$hoodles" -type f -name "patches-*.mpp" -print -quit)
dlPatchesMpp() {
  while true; do
    curl -L -C - --progress-bar -o "$patchesPath" "$patchesDownloadURL"
    [ $? -eq 0 ] && break || { echo -e "$bad ${Red}Download failed! retrying in 5 seconds..${Reset}"; sleep 5; }
  done
}
if [ -f "$localPatchesPath" ]; then
  [ "$(basename "$localPatchesPath" 2>/dev/null)" != "$(basename "$patchesPath" 2>/dev/null)" ] && { echo -e "$notice diffs: "$(basename $patchesPath 2>/dev/null)" ~ $(basename $localPatchesPath)"; rm -f "$localPatchesPath"; dlPatchesMpp; }
else
  dlPatchesMpp
fi

getVersion() {
  pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $MorpheCLIJar list-versions $patchesPath -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
}

patchApp() {
  local stock_apk_ref="${1}"
  local -n patches=$2
  local outputAPK=$3
  output_filename_wo_ext="${outputAPK%.*}"
  local log="$SimplUsr/$appName-hoodles_patch-log.txt"
  local appName=$4

  echo -e "$running Patching ${appName}.."
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $MorpheCLIJar patch -p $patchesPath -o "$outputAPK" "${stock_apk_ref}" "${patches[@]}" --purge $stripLibs -f | tee "$log"

  if grep -q "OutOfMemory" "$log"; then
    echo -e "$bad ${Red}OutOfMemoryError${Reset}: ${Yellow}Device RAM overloaded!${Reset}\n ${Blue}Solutions${Reset}:\n   1. ${Yellow}Close background apps.${Reset}\n   2. ${Yellow}Use device with ≥4GB ~ ≥6GB RAM for patching apk.${Reset}"
  elif [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to $log. Share the Patchlog to developer."
    termux-open-url "https://github.com/hoo-dles/morphe-patches/issues/new?template=bug_report.yml"
    termux-open --send "$log"
    rm -rf "$output_filename_wo_ext-temporary-files"
  else
    rm -f "$output_filename_wo_ext.keystore"
  fi
}

wpsoffice_patches_args=()
ibispaintx_patches_args=()
solidexplorer_patches_args=()

if [ "$ReadPatchesFile" -eq 1 ]; then
  default_patches=(
    # [0] WPS Office, [1] ibis Paint X, [2] Solid Explorer | No default patches
    '' '' ''
  )
  patches_array_names=(
    wpsoffice_patches_args
    ibispaintx_patches_args
    solidexplorer_patches_args
  )
  for ((i=0; i<${#patches_array_names[@]}; i++)); do
    [ ! -e "$SimplUsr/${patches_array_names[i]}.txt" ] && printf "%s\n" "${default_patches[i]}" > "$SimplUsr/${patches_array_names[i]}.txt"
  done
  for (( i=0; i<${#patches_array_names[@]}; i++ )); do
    if [ -f "$SimplUsr/${patches_array_names[i]}.txt" ]; then
      if [ -s "$SimplUsr/${patches_array_names[i]}.txt" ]; then
        eval "${patches_array_names[i]}=()"
        mapfile -t lines < "$SimplUsr/${patches_array_names[i]}.txt"
        for line in "${lines[@]}"; do
          [ -z "$line" ] && continue
          eval "args=($line)"
          eval "${patches_array_names[i]}+=(\"\${args[@]}\")"
        done
      else
        eval "${patches_array_names[i]}=()"
      fi
    fi
  done
fi

commonPrompt() {
  buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install ${appNameRef[0]} hoodles app?" "buttons" && opt=Yes || opt=No
  case $opt in
    Yes)
      echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} hoodles apk.."
      apkInstall "$outputAPK" "$activityPatched"
      ;;
    No) echo -e "$notice ${appNameRef[0]} hoodles Installaion skipped!" ;;
  esac
    
  buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share ${appNameRef[0]} hoodles app?" "buttons" "1" && opt=Yes || opt=No
  case $opt in
    Yes)
      echo -e "$running Please Wait !! Sharing Patched ${appNameRef[0]} hoodles apk.."
      termux-open --send "$outputAPK"
      ;;
    No) echo -e "$notice ${appNameRef[0]} hoodles Sharing skipped!"
      echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)" && sleep 3
      am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.google.android.documentsui/com.android.documentsui.files.FilesActivity &> /dev/null  # Open Android Files by Google
      [ $? -ne 0 ] && am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.android.documentsui/com.android.documentsui.files.FilesActivity > /dev/null 2>&1  # Open Android Files
      ;;
  esac
}

buildApp() {
  local pkgName=$1
  local -n appNameRef=$2
  local appName="${appNameRef[0]}"
  local pkgVersion=$3
  local Type=$4
  local -n archRef=$5
  local arch="${archRef[0]}"
  local web=$6
  local appPatchesArgs=$7
  local pkgPatched=$8
  local activityPatched=$9

  if [ "$web" == "APKMirror" ]; then
    APKMdl "$pkgName" "" "$pkgVersion" "$Type" "$arch"  # Download stock apk from APKMirror
  elif [ "$web" == "Uptodown" ]; then
    bash $Simplify/dlUptodown.sh "${appName}" "$pkgVersion" "$Type" "${arch}"  # Download stock apk from Uptodown
  fi
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
  local outputAPK="$SimplUsr/${appNameRef[0]}-hoodles_v${pkgVersion}-$cpuAbi.apk"
  local fileName=$(basename $outputAPK 2>/dev/null)
  if [ -f "${stock_apk_path}" ]; then
    echo -e "$good ${Green}Downloaded ${appName} APK found:${Reset} ${stock_apk_path}"
    termux-wake-lock
    patchApp "$stock_apk_path" "$appPatchesArgs" "$outputAPK" "${appName}"
    termux-wake-unlock
  fi
  [ -f "$outputAPK" ] && commonPrompt
}

getListOfPatches() {
  local pkgName=${1}
  patchesJson=$(curl -sL "https://raw.githubusercontent.com/hoo-dles/morphe-patches/refs/heads/${branch}/patches-list.json" | jq --arg pkgName "$pkgName" '.patches[] | select(if $pkgName == "null" then .compatiblePackages == null else .compatiblePackages[$pkgName] != null end)')
  [ $ReadPatchesFile -eq 0 ] && jq <<< "$patchesJson" || jq <<< "$patchesJson" | tee "$SimplUsr/${pkgName}_list-patches.txt"
}

options=(CHANGELOG Spoof\ Device\ Arch List\ of\ Patches)
[ $Android -ge 7 ] && apps=(WPSOffice ibisPaintX)
[ $Android -ge 6 ] && apps+=(SolidExplorer)
options+=(${apps[@]})

while true; do
  buttons=("<Select>" "<Back>"); if menu options buttons; then selected="${options[$selected]}"; else break; fi
  case "$selected" in
    CHANGELOG)
      jq -r '.description' <<< "$patchesBundleJson" | glow
      ;;
    Spoof\ Device\ Arch) overwriteArch ;;
    List\ of\ Patches)
      apps_list=(universalPatches)
      apps_list+=("${apps[@]}")
      
      buttons=("<Select>" "<Back>"); if menu apps_list buttons; then selected="${apps_list[$selected]}"; fi
      if [ -n "$selected" ]; then
        case "$selected" in
          universalPatches)
            pkgName="null"
            getListOfPatches "$pkgName"
            ;;
          WPSOffice)
            pkgName="cn.wps.moffice_eng"
            getListOfPatches "$pkgName"
            ;;
          ibisPaintX)
            pkgName="jp.ne.ibis.ibispaintx.app"
            getListOfPatches "$pkgName"
            ;;
          SolidExplorer)
            pkgName="pl.solidexplorer2"
            getListOfPatches "$pkgName"
            ;;
        esac
      fi
      ;;
    WPSOffice)
      pkgName="cn.wps.moffice_eng"
      appName=("WPS Office-PDF, Word, Sheet")
      pkgVersion=""
      Type="APK"
      Arch=("arm64-v8a + armeabi-v7a")
      activityPatched="cn.wps.moffice_eng/cn.wps.moffice.documentmanager.PreStartActivity"
      buildApp "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "wpsoffice_patches_args" "$pkgName" "$activityPatched"
      ;;
    ibisPaintX)
      pkgName="jp.ne.ibis.ibispaintx.app"
      appName=("ibis Paint X")
      pkgVersion="13.1.19"
      Type="xapk"
      Arch=("arm64-v8a, armeabi-v7a, x86_64")
      activityPatched="jp.ne.ibis.ibispaintx.app/.InitializeCheckActivity"
      buildApp "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "Uptodown" "ibispaintx_patches_args" "$pkgName" "$activityPatched"
      ;;
    SolidExplorer)
      pkgName="pl.solidexplorer2"
      appName=("Solid Explorer File Manager")
      pkgVersion=""
      Type="BUNDLE"
      Arch=("universal")
      activityPatched="pl.solidexplorer2/pl.solidexplorer.SolidExplorer"
      buildApp "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "solidexplorer_patches_args" "$pkgName" "$activityPatched"
      ;;
  esac
  echo; read -p "Press Enter to continue..."
done