#!/usr/bin/bash

[ $su -eq 1 ] && echo -e "$info ${Blue}Target device:${Reset} $Model ($Serial)" || echo -e "$info ${Blue}Target device:${Reset} $Model"

# --- Download LSPatch ---
bash $Simplify/dlGitHub.sh "JingMatrix" "LSPatch" "latest" ".jar" "$LSPatch"
LSPatchJar=$(find "$LSPatch" -type f -name "lspatch-*.jar" -print -quit)
echo -e "$info ${Blue}LSPatchJar:${Reset} $LSPatchJar"

# --- function to download artifacts from github actions (req. gh pat) ---
dlArtifacts() {
  local owner=$1
  local repo=$2
  local workflow_name=${3}
  local artifacts_name=$4
  
  workflow_filename=$(curl -sL https://api.github.com/repos/$owner/$repo/actions/workflows | jq --arg workflow_name "$workflow_name" -r '.workflows[] | select(.name == $workflow_name) | .path' | xargs basename)
  workflow_run_id=$(curl -sL "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflow_filename/runs?per_page=1" | jq -r '.workflow_runs[0].id')
  archive_download_url=$(curl -s "https://api.github.com/repos/$owner/$repo/actions/runs/$workflow_run_id/artifacts" | jq --arg artifacts_name "$artifacts_name" -r '.artifacts[] | select(.name == $artifacts_name).archive_download_url')
  
  if [ -n "$token" ]; then
    curl -L -H "Authorization: Bearer $token" --progress-bar -o "$LSPatch/$artifacts_name.zip" "$archive_download_url"
  fi
}

#  --- Patchcing Apps Method ---
patch_app() {
  local stock_apk_path=$1
  local module_apk_path=$2
  local appName=$3
  local log="$SimplUsr/$appName-LSPatch_patch-log.txt"
  local BugReportUrl=$4

  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $LSPatchJar "$stock_apk_path" -m "$module_apk_path" -o "$SimplUsr/" | tee "$log"

  if [ $? != 0 ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "$BugReportUrl"
    termux-open --send "$log"
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
  local web=$6
  local module_apk_path=$7
  local BugReportUrl=$8
  local pkgPatched=$9
  local activityPatched=$10

  if [ "${appNameRef[0]}" == "Discord" ]; then
    # src: https://github.com/revenge-mod/revenge-manager/blob/85fdd3c2d25e509960bdb99e0e9882b16f5d541f/app/src/main/java/app/revenge/manager/installer/step/download/DownloadBaseStep.kt#L20
    baseUrl="https://tracker.vendetta.rocks/tracker/download/$pkgVersion/base"  # Size >= 100 MB
    # src: https://github.com/revenge-mod/revenge-manager/blob/85fdd3c2d25e509960bdb99e0e9882b16f5d541f/app/src/main/java/app/revenge/manager/installer/step/download/DownloadLangStep.kt#L20
    langUrl="https://tracker.vendetta.rocks/tracker/download/$pkgVersion/config.en"  # Size >= 58 KB
    # src: https://github.com/revenge-mod/revenge-manager/blob/85fdd3c2d25e509960bdb99e0e9882b16f5d541f/app/src/main/java/app/revenge/manager/installer/step/download/DownloadResourcesStep.kt#L20
    resourcesUrl="https://tracker.vendetta.rocks/tracker/download/$pkgVersion/config.xxhdpi"  # Size >= 13 MB
    if [ "$cpuAbi" == "arm64-v8a" ]; then arch="arm64_v8a"; elif [ "$cpuAbi" == "armeabi-v7a" ]; then arch="armeabi_v7a"; else arch="$cpuAbi"; fi
    # src: https://github.com/revenge-mod/revenge-manager/blob/85fdd3c2d25e509960bdb99e0e9882b16f5d541f/app/src/main/java/app/revenge/manager/installer/step/download/DownloadLibsStep.kt#L26
    libsUrl="https://tracker.vendetta.rocks/tracker/download/$pkgVersion/config.$arch"  # Size >= 60 MB
    dlDIR="$Download/Discord_v$pkgVersion"
    dl() {
      dlUtility=$1
      dlUrl="$2"
      fileName="$3"
      echo -e "$running Downloading $fileName.."
      while true; do
        if [ "$dlUtility" == "curl" ]; then
          curl -L -C - --progress-bar -o "$dlDIR/$fileName" "$dlUrl"
          exit_status=$?
        else
          aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$fileName" -d "$dlDIR" "$dlUrl"
          exit_status=$?; echo
        fi
        [ $exit_status -eq 0 ] && break
        echo -e "${bad} ${Red}Download failed! retrying in 5 seconds..${Reset}"; sleep 5
      done
    }
    if [ ! -f "$dlDIR.apk" ]; then
      findFile=$(find "$Download" -type f -name "Discord_v*.apk" -print -quit)
      [ "$dlDIR.apk" != "$findFile" ] && rm -f "$findFile"
      mkdir -p "$dlDIR"
      dl "aria2" "$baseUrl" "base.apk"
      dl "curl" "$langUrl" "config.en.apk"
      dl "curl" "$resourcesUrl" "config.xxhdpi.apk"
      if [ "$cpuAbi" == "arm64-v8a" ] || [ "$cpuAbi" == "armeabi-v7a" ]; then dl "aria2" "$libsUrl" "config.$arch.apk"; else dl "aria2" "$libsUrl" "config.$cpuAbi.apk"; fi
    
      bash $Simplify/dlGitHub.sh "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
      APKEditor=$(find "$Simplify" -type f -name "APKEditor-*.jar" -print -quit)
      echo -e "$running Merge splits apks to standalone lite apk.."
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $APKEditor m -i "$dlDIR" -o "$dlDIR.apk"
      rm -rf "$dlDIR"
      echo  # Space
    fi
    cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
  else
    if [ "$web" == "APKMirror" ]; then
      APKMdl "$pkgName" "$Index" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
    else
      bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from Uptodown
    fi
  fi
  sleep 0.5  # Wait 500 milliseconds
  if [ "$Type" == "APK" ] || [ "$Type" == "apk" ]; then
    if [ -z "$pkgVersion" ]; then
      fileNamePattern=("${appNameRef[0]}_v*-${archRef[0]}.apk")
      stock_apk_path=$(find "$Download" -type f -name "${fileNamePattern[0]}" -print -quit)
    elif [ -n "$pkgVersion" ]; then
      stock_apk_path="$Download/${appNameRef[0]}_v${pkgVersion}-${archRef[0]}.apk"
    fi
  else
    if [ -z "$pkgVersion" ]; then
      fileNamePattern=("${appNameRef[0]}_v*-$cpuAbi.apk")
      stock_apk_path=$(find "$Download" -type f -name "${fileNamePattern[0]}" -print -quit)
    elif [ -n "$pkgVersion" ]; then
      stock_apk_path="$Download/${appNameRef[0]}_v${pkgVersion}-$cpuAbi.apk"
    fi
  fi
  [ "${appNameRef[0]}" == "Discord" ] && stock_apk_path="$dlDIR.apk"

  local stockFileName=$(basename "${stock_apk_path}")
  local stockFileNameWOExt="${stockFileName%.*}"
  if [ -f "${stock_apk_path}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_path}"
    echo -e "$running Patching ${appNameRef[0]} LSPatch.."
    termux-wake-lock
    patch_app "${stock_apk_path}" "$module_apk_path" "${appNameRef[0]}" "$BugReportUrl"
    termux-wake-unlock
  fi
  
  local output_apk_path=$(find "$SimplUsr" -type f -name "${stockFileNameWOExt}-*-lspatched.apk")
  local fileName=$(basename "${output_apk_path}")

  if [ -f "$output_apk_path" ]; then
    
    if [ "$pkgName" == "com.google.android.dialer" ]; then
      
      buttons=("<Install>" "<Mount>" "<Cancel>")
      confirmPrompt "Select ${appNameRef[0]} LSPatch installation operation" "buttons"
      exit_status=$?
      if [ $exit_status -eq 0 ]; then opt=Install; elif [ $exit_status -eq 1 ]; then opt=Mount; elif [ $exit_status -eq 2 ]; then opt=Cancel; fi
      case $opt in
        Install)
          checkCoreLSPosed  # Call the check core patch functions
          echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} LSPatch apk.."
          apkInstall "${output_apk_path}" ""
          ;;
        Mount)
          echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} LSPatch apk.."
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"${output_apk_path}\"" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"${output_apk_path}\"" | tee "$SimplUsr/${appNameRef[0]}-LSPatch_mount-log.txt"
          rm -f "${output_apk_path}"
          ;;
        Cancel) echo -e "$notice ${appNameRef[0]} LSPatch Installaion skipped!" ;;
      esac
    
    else
      
      buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Install ${appNameRef[0]} LSPatch app?" "buttons" && opt=Yes || opt=No
      case $opt in
        y*|Y*|"")
          echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} LSPatch apk.."
          apkInstall "${output_apk_path}" "$activityPatched"
          ;;
        n*|N*) echo -e "$notice ${appNameRef[0]} LSPatch Installaion skipped!" ;;
      esac
      
      buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share ${appNameRef[0]} LSPatch app?" "buttons" "1" && opt=Yes || opt=No
      case $opt in
        y*|Y*|"")
          echo -e "$running Please Wait !! Sharing Patched ${appNameRef[0]} LSPatch apk.."
          termux-open --send "${output_apk_path}"
          ;;
        n*|N*) echo -e "$notice ${appNameRef[0]} LSPatch Sharing skipped!"
          echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)" && sleep 3
          am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.google.android.documentsui/com.android.documentsui.files.FilesActivity &> /dev/null  # Open Android Files by Google
          if [ $? -ne 0 ] || [ $? -eq 2 ]; then
            am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.android.documentsui/com.android.documentsui.files.FilesActivity > /dev/null 2>&1  # Open Android Files
          fi
          ;;
      esac

    fi

  fi
}

# --- function to signing an apk file ---
sign_app() {
  local pkgName=$1
  local -n appNameRef=$2
  local pkgVersion=$3
  local Type=$4
  local -n ArchRef=$5
  local web=$6
  local pkgPatched=$7
  local activityPatched=$8
  
  if [ "$web" == "APKMirror" ]; then
    APKMdl "$pkgName" "" "$pkgVersion" "$Type" "${ArchRef[0]}"  # Download stock apk from APKMirror
  else
    bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${ArchRef[0]}"  # Download stock apk from Uptodown
  fi
  if [ "$Type" == "BUNDLE" ] || [ "$Type" == "xapk" ]; then
    if [ -n "$pkgVersion" ]; then
      local stock_apk_path=("$Download/${appNameRef[0]}_v${pkgVersion}-$cpuAbi.apk")
    else
      local stock_apk=$(find "$Download" -type f -name "${appNameRef[0]}_v*-$cpuAbi.apk" -print -quit)
      local stock_apk_path=("$stock_apk")  # -quit= find stops after first match
    fi
  elif [ "$Type" == "APK" ] || [ "$Type" == "apk" ]; then
    if [ -n "$pkgVersion" ]; then
      local stock_apk_path=("$Download/${appNameRef[0]}_v${pkgVersion}-${ArchRef[0]}.apk")
    else
      local stock_apk=$(find "$Download" -type f -name "${appNameRef[0]}_v*-${ArchRef[0]}.apk" -print -quit)
      local stock_apk_path=("$stock_apk")
    fi
  fi
  sleep 0.5  # Wait 500 milliseconds
  
  local stockFileName=$(basename "${stock_apk_path[0]}")
  local stockFileNameWOExt="${stockFileName%.*}"
  if [ -f "${stock_apk_path[0]}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_path[0]}"
    echo -e "$running Checking ${appNameRef[0]} Certificate.."
    checkOwner=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -printcert -jarfile "${stock_apk_path[0]}" | grep -oP 'Owner: \K.*')
    if [ -z "$checkOwner" ]; then
      echo -e "$notice keytool error: SHA-256 digest error!"
      local output_apk_path="$SimplUsr/$stockFileNameWOExt-signed.apk"
      local fileName=$(basename "${output_apk_path}")
      echo -e "$running Signing apk.."
      termux-wake-lock
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar sign --ks $Simplify/ks.keystore --ks-pass pass:123456 --ks-key-alias ReVancedKey --key-pass pass:123456 --out "${output_apk_path}" "${stock_apk_path[0]}"
      termux-wake-unlock
      rm -f "$output_apk_path.idsig"
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -printcert -jarfile "${output_apk_path}" | grep -oP 'Owner: \K.*' 2>/dev/null
      if [ $? -ne 0 ]; then
        $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar verify --print-certs "${output_apk_path}" | grep -oP 'Signer #1 certificate DN: \K.*'
      fi
    fi
  fi
  
  if [ -f "${output_apk_path}" ]; then
    
    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Install ${appNameRef[0]} Signed app?" "buttons" && opt=Yes || opt=No
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Signed ${appNameRef[0]} apk.."
        apkInstall "${output_apk_path}" "$activityPatched"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} Signed Installaion skipped!" ;;
    esac
      
    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share ${appNameRef[0]} Signed app?" "buttons" "1" && opt=Yes || opt=No
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Sharing Signed ${appNameRef[0]} apk.."
        termux-open --send "${output_apk_path}"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} Signed Sharing skipped!"
        echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)" && sleep 3
        am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.google.android.documentsui/com.android.documentsui.files.FilesActivity &> /dev/null  # Open Android Files by Google
        if [ $? -ne 0 ] || [ $? -eq 2 ]; then
          am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.android.documentsui/com.android.documentsui.files.FilesActivity > /dev/null 2>&1  # Open Android Files
        fi
        ;;
    esac
    
  fi
}

#Requires
<<comment
  Snapchat Android 5.0+
  Discord Android 7.0+
  LINE Android 10+
  Phone by Google Android 9+
  1.1.1.1 + WARP Android 5.0+
comment

# --- Decisions block for app that required specific arch && root ---
if [ "$cpuAbi" == "arm64-v8a" ] || [ "$cpuAbi" == "armeabi-v7a" ]; then
  #Snapchat="Snapchat"
  LINE="LINE"
  [ $su -eq 1 ] && googleDialer="PhoneByGoogle"
fi

# --- Arrays of apps list that required specific android version ---
if [ $Android -ge 10 ]; then
  apps=(
    ${Snapchat}
    Reddit
    Discord
    SolidExplorer
    ${LINE}
    ${googleDialer}
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 9 ]; then
  apps=(
    ${Snapchat}
    Reddit
    Discord
    SolidExplorer
    ${googleDialer}
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 8 ]; then
  apps=(
    ${Snapchat}
    Discord
    SolidExplorer
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 7 ]; then
  apps=(
    ${Snapchat}
    Discord
    SolidExplorer
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 6 ]; then
  apps=(
    ${Snapchat}
    SolidExplorer
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 5 ]; then
  apps=(
    ${Snapchat}
    "1.1.1.1 + WARP"
  )
fi

while true; do
  buttons=("<Select>" "<Back>"); if menu apps buttons; then selected="${apps[$selected]}"; else break; fi
  
  # main conditional control flow
  case "$selected" in
    Snapchat)
      appName=("Snapchat")
      pkgName="com.snapchat.android"
      pkgVersion="12.33.1.19"
      #pkgVersion=""
      Type="BUNDLE"
      Arch=("arm64-v8a + armeabi-v7a")
      if [ "$cpuAbi" == "arm64-v8a" ]; then
        arch="armv8"
      elif [ "$cpuAbi" == "armeabi-v7a" ]; then
        arch="armv7"
      else
        arch="all"
      fi
      if { [ -f "$HOME/.config/gh/hosts.yml" ] && ! grep -q "{}" "$HOME/.config/gh/hosts.yml" 2>/dev/null; } || { [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; }; then
        dlArtifacts "rhunk" "SnapEnhance" "Debug CI" "snapenhance-$arch-debug"
        archive_path="$LSPatch/snapenhance-$arch-debug.zip"
        pv "$archive_path" | bsdtar -xf - -C "$LSPatch/"
        rm "$archive_path"
        module_apk_path=$(find "$LSPatch" -type f -name "snapenhance-*-$arch-*.apk" -print -quit)
      else
        regex="snapenhance_.*-${arch}-release-signed.apk"
        bash $Simplify/dlGitHub.sh "rhunk" "SnapEnhance" "latest" ".apk" "$LSPatch" "$regex"
        module_apk_path=$(find "$LSPatch" -type f -name "snapenhance_*-${arch}-release-signed.apk")
      fi
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatched="com.snapchat.android/.LandingPageActivity"
      BugReport="https://github.com/rhunk/SnapEnhance/issues/new?template=bug_report.yml"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatched"
      ;;
    Reddit)
      appName=("Reddit")
      pkgName="com.reddit.frontpage"
      pkgVersion="2025.46.0"
      Type="BUNDLE"
      Arch=("universal")
      bash $Simplify/dlGitHub.sh "Xposed-Modules-Repo" "com.wizpizz.reddidnt" "latest" ".apk" "$LSPatch"
      module_apk_path=$(find "$LSPatch" -type f -name "com.wizpizz.reddidnt-v*.apk" -print -quit)
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatched="com.reddit.frontpage/launcher.default"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "$module_apk_path" "" "$pkgName" "$activityPatched"
      ;;
    Discord)
      appName=("Discord")
      pkgName="com.discord"
      # src: https://github.com/revenge-mod/revenge-manager/blob/85fdd3c2d25e509960bdb99e0e9882b16f5d541f/app/src/main/java/app/revenge/manager/domain/manager/PreferenceManager.kt#L81
      # src: https://github.com/revenge-mod/revenge-manager/blob/85fdd3c2d25e509960bdb99e0e9882b16f5d541f/app/src/main/java/app/revenge/manager/network/service/RestService.kt#L25
      if [ "$FetchPreRelease" -eq 0 ]; then
        pkgVersion=$(curl -sL https://tracker.vendetta.rocks/tracker/index | jq -r '.[].stable')
      else
        pkgVersion=$(curl -sL https://tracker.vendetta.rocks/tracker/index | jq -r '.[].beta')
      fi
      Arch=()
      bash $Simplify/dlGitHub.sh "revenge-mod" "revenge-xposed" "latest" ".apk" "$LSPatch"
      module_apk_path=$(find "$LSPatch" -type f -name "revenge-xposed-*.apk" -print -quit)
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatched="com.discord/.main.MainDefault"
      BugReport="https://github.com/revenge-mod/revenge-xposed/issues/new"
      build_app "$pkgName" "appName" "$pkgVersion" "" "$Arch" "" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatched"
      ;;
    SolidExplorer)
      appName=("Solid Explorer File Manager")
      pkgName="pl.solidexplorer2"
      pkgVersion=""
      Type="BUNDLE"
      Arch=("universal")
      bash $Simplify/dlGitHub.sh "fzer0x" "dev.fzer0x.fucksolidexplorer" "latest" ".apk" "$LSPatch"
      module_apk_path=$(find "$LSPatch" -type f -name "dev.fzer0x.fucksolidexplorer-*.apk" -print -quit)
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatched="pl.solidexplorer2/pl.solidexplorer.SolidExplorer"
      BugReport="https://github.com/fzer0x/dev.fzer0x.fucksolidexplorer/issues/new"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatched"
      ;;
    LINE)
      appName=("LINE")
      pkgName="jp.naver.line.android"
      pkgVersion="15.10.2"
      #pkgVersion=""
      Type="BUNDLE"
      Arch=("arm64-v8a + armeabi-v7a")
      regex="LineXtra-.*-all-release.apk"
      bash $Simplify/dlGitHub.sh "yagiyuu" "LineXtra" "latest" ".apk" "$LSPatch" "$regex"
      module_apk_path=$(find "$LSPatch" -type f -name "LineXtra-*-all-release.apk")
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatched="jp.naver.line.android/.activity.SplashActivity"
      BugReport="https://github.com/yagiyuu/LineXtra/issues"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatched"
      ;;
    PhoneByGoogle)
      appName=("Phone by Google")
      pkgName="com.google.android.dialer"
      Index=1
      if [ $Android -ge 11 ]; then
        #pkgVersion="206.0.857916353"
        pkgVersion="181.0.780184920"
      elif [ $Android -eq 10 ]; then
        pkgVersion="161.0.726587057"
      elif [ $Android -eq 9 ]; then
        pkgVersion="121.0.603393336-downloadable"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      bash $Simplify/dlGitHub.sh "Xposed-Modules-Repo" "io.github.vvb2060.callrecording" "latest" ".apk" "$LSPatch"
      module_apk_path=$(find "$LSPatch" -type f -name "io.github.vvb2060.callrecording-*.apk")
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatched="com.google.android.dialer/.extensions.GoogleDialtactsActivity"
      BugReport="https://github.com/vvb2060/CallRecording/issues/new"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatched"
      ;;
    1.1.1.1\ +\ WARP)
      appName=("1.1.1.1 + WARP")
      pkgName="com.cloudflare.onedotonedotonedotone"
      #pkgVersion="6.38.5"
      pkgVersion=""
      Type="BUNDLE"
      Arch=("universal")
      activityPatched="com.cloudflare.onedotonedotonedotone/com.cloudflare.app.presentation.main.SplashActivity"
      sign_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "$pkgName" "$activityPatched"
      ;;
  esac
  echo; read -p "Press Enter to continue..."
done
#################################################################################################################################################################################################
