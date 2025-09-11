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
  Android=$(getprop ro.build.version.release)  # Get Android version
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
RipLocale="$(jq -r '.RipLocale' "$simplifyJson" 2>/dev/null)"
RipDpi="$(jq -r '.RipDpi' "$simplifyJson" 2>/dev/null)"
RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
if [ $RipLocale -eq 1 ]; then
  locale=$(getprop persist.sys.locale | cut -d'-' -f1)  # Get System Languages
  if [ -z $locale ]; then
    locale=$(getprop ro.product.locale | cut -d'-' -f1)  # Get Languages
  fi
elif [ $RipLocale -eq 0 ]; then
  locale="[a-z][a-z]"
fi
if [ $RipDpi -eq 1 ]; then
  density=$(getprop ro.sf.lcd_density)  # Get the device screen density
  # Check and categorize the density
  if [ "$density" -le 120 ]; then
    lcd_dpi="ldpi"  # Low Density
  elif [ "$density" -le 160 ]; then
    lcd_dpi="mdpi"  # Medium Density
  elif [ "$density" -le 240 ]; then
    lcd_dpi="hdpi"  # High Density
  elif [ "$density" -le 320 ]; then
    lcd_dpi="xhdpi"  # Extra High Density
  elif [ "$density" -le 480 ]; then
    lcd_dpi="xxhdpi"  # Extra Extra High Density
  elif [ "$density" -gt 480 ] || [ "$density" -ge 640 ]; then
    lcd_dpi="xxxhdpi"  # Extra Extra Extra High Density
  else
    lcd_dpi="*dpi"
  fi
elif [ $RipDpi -eq 0 ]; then
  lcd_dpi="*dpi"
fi
Serial=$(su -c 'getprop ro.serialno')  # Get Serial Number required root
Model=$(getprop ro.product.model)  # Get Device Model
LSPatch="$Simplify/LSPatch"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$LSPatch" "$SimplUsr"  # Create $Simplify, $LSPatch and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir
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

if su -c "id" >/dev/null 2>&1; then
  echo -e "$info ${Blue}Target device:${Reset} $Model ($Serial)"
else
  echo -e "$info ${Blue}Target device:${Reset} $Model"
fi

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
    assetsName="com.discord_289.20-Stable-289020_4arch_7dpi_25lang.apks"
    dlUrl="https://github.com/arghya339/Simplify/releases/download/all/$assetsName"
    echo -e "$running Downloading ${appNameRef[0]}.."
    while true; do
      aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "${appNameRef}_v${pkgVersion}-${archRef[0]}.${Type}" -d "$Download" "$dlUrl"
      if [ $? -eq 0 ]; then
        echo  # White Space
        break
      fi
      echo -e "${bad} ${Red}Download failed! retrying in 5 seconds..${Reset}"
      sleep 5
    done
    stock_apks_path=("$Download/${appNameRef}_v${pkgVersion}-${archRef[0]}.${Type}")
    mkdir -p "$Download/${appNameRef}_v${pkgVersion}-${cpuAbi}"
    echo -e "$running Extracting APKS content.."
    if [ $RipLib -eq 1 ]; then
      pv "$stock_apks_path" | bsdtar -xf - -C "$Download/${appNameRef}_v${pkgVersion}-${cpuAbi}/" --include "base.apk" "split_config.${cpuAbi//-/_}.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
    elif [ $RipLib -eq 0 ]; then
      pv "$stock_apks_path" | bsdtar -xf - -C "$Download/${appNameRef}_v${pkgVersion}-${cpuAbi}/" --include "base.apk" "split_config.arm64_v8a.apk" "split_config.armeabi_v7a.apk" "split_config.x86_64.apk" "split_config.x86.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
    fi
    rm -f "$stock_apks_path"
    stock_apk_path=("$Download/${appNameRef}_v${pkgVersion}-${cpuAbi}.apk")
    bash $Simplify/dlGitHub.sh "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
    APKEditor=$(find "$Simplify" -type f -name "APKEditor-*.jar" -print -quit)
    echo -e "$running Merge splits apks to standalone lite apk.."
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $APKEditor m -i "$Download/${appNameRef}_v${pkgVersion}-${cpuAbi}" -o "$stock_apk_path"
    rm -rf "$Download/${appNameRef}_v${pkgVersion}-${cpuAbi}"
    echo  # Space
  else
    if [ "$web" == "APKMirror" ]; then
      bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
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
      
      echo -e "[?] ${Yellow}Please select installation type - 'M' for Mount or 'I' for SU-Install or 'N' for Installation cancel. [M/i/N]: ${Reset}\c" && read opt
      case $opt in
        I*|i*|"")
          checkCoreLSPosed  # Call the check core patch functions
          echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} LSPatch apk.."
          bash $Simplify/apkInstall.sh "${output_apk_path}" ""
          ;;
        M*|m*)
          echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} LSPatch apk.."
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"${output_apk_path}\"" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"${output_apk_path}\"" | tee "$SimplUsr/${appNameRef[0]}-LSPatch_mount-log.txt"
          rm -f "${output_apk_path}"
          ;;
        N*|n*) echo -e "$notice ${appNameRef[0]} LSPatch Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} LSPatch Installaion skipped." ;;
      esac
    
    else
      
      echo -e "[?] ${Yellow}Do you want to Install ${appNameRef[0]} LSPatch app? [Y/n] ${Reset}\c" && read opt
      case $opt in
        y*|Y*|"")
          echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} LSPatch apk.."
          bash $Simplify/apkInstall.sh "${output_apk_path}" "$activityPatched"
          ;;
        n*|N*) echo -e "$notice ${appNameRef[0]} LSPatch Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} LSPatch Installaion skipped." ;;
      esac
      
      echo -e "[?] ${Yellow}Do you want to Share ${appNameRef[0]} LSPatch app? [Y/n] ${Reset}\c" && read opt
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
        *) echo -e "$info Invalid choice! ${appNameRef[0]} LSPatch Sharing skipped." ;;
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
    bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${ArchRef[0]}"  # Download stock apk from APKMirror
    if [ "$Type" == "BUNDLE" ]; then
      if [ -n "$pkgVersion" ] && [ "$pkgVersion" != "null" ]; then
        local stock_apk_path=("$Download/${appNameRef[0]}_v${pkgVersion}-$cpuAbi.apk")
      elif [ -z "$pkgVersion" ] || [ "$pkgVersion" == "null" ]; then
        local stock_apk=$(find "$Download" -type f -name "${appNameRef[0]}_v*-$cpuAbi.apk" -print -quit)
        local stock_apk_path=("$stock_apk")  # -quit= find stops after first match
      fi
    elif [ "$Type" == "APK" ]; then
      if [ -n "$pkgVersion" ] && [ "$pkgVersion" != "null" ]; then
        local stock_apk_path=("$Download/${appNameRef[0]}_v${pkgVersion}-${ArchRef[0]}.apk")
      elif [ -z "$pkgVersion" ] || [ "$pkgVersion" == "null" ]; then
        local stock_apk=$(find "$Download" -type f -name "${appNameRef[0]}_v*-${ArchRef[0]}.apk" -print -quit)
        local stock_apk_path=("$stock_apk")
      fi
    fi
  else
    bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${ArchRef[0]}"  # Download stock apk from Uptodown
    if [ "$Type" == "xapk" ]; then
      local stock_apk_path=("$Download/${appNameRef[0]}_v${pkgVersion}-$cpuAbi.apk")
    elif [ "$Type" == "apk" ]; then
      local stock_apk_path=("$Download/${appNameRef[0]}_v${pkgVersion}-${ArchRef[0]}.apk")
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
    
    echo -e "[?] ${Yellow}Do you want to Install ${appNameRef[0]} Signed app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Signed ${appNameRef[0]} apk.."
        bash $Simplify/apkInstall.sh "${output_apk_path}" "$activityPatched"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} Signed Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! ${appNameRef[0]} Signed Installaion skipped." ;;
    esac
      
    echo -e "[?] ${Yellow}Do you want to Share ${appNameRef[0]} Signed app? [Y/n] ${Reset}\c" && read opt
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
      *) echo -e "$info Invalid choice! ${appNameRef[0]} Signed Sharing skipped." ;;
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
  Snapchat="Snapchat"
  LINE="LINE"
  if su -c "id" >/dev/null 2>&1; then
    googleDialer="PhoneByGoogle"
  fi
fi

# --- Arrays of apps list that required specific android version ---
if [ $Android -ge 10 ]; then
  apps=(
    Quit
    ${Snapchat}
    Discord
    ${LINE}
    ${googleDialer}
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 9 ]; then
  apps=(
    Quit
    ${Snapchat}
    Discord
    ${googleDialer}
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 8 ]; then
  apps=(
    Quit
    ${Snapchat}
    Discord
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 7 ]; then
  apps=(
    Quit
    ${Snapchat}
    Discord
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 6 ]; then
  apps=(
    Quit
    ${Snapchat}
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    ${Snapchat}
    "1.1.1.1 + WARP"
  )
fi

while true; do
  # Display the apps list
  echo -e "$info Available apps:"
  for i in "${!apps[@]}"; do
    if [ -n "${apps[$i]}" ] && [ "${apps[$i]}" != "null" ]; then
      printf "%d. %s\n" "$i" "${apps[$i]}"
    fi
  done

  # Ask for an index, showing the valid range
  max=$(( ${#apps[@]} - 1 ))  # highest legal index
  read -rp "Enter the index [0-${max}] of apps you want to patch: " idx

  # Validate and respond
  if [ "$idx" == 0 ]; then
    break  # break the while loop
  elif [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice Selected: ${apps[$idx]}"
  else
    echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
  fi
  
  # main conditional control flow
  case "${apps[$idx]}" in
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
    Discord)
      appName=("Discord")
      pkgName="com.discord"
      pkgVersion="289.20-Stable"
      Type="apks"
      Arch=("universal")
      releasesTagName=$(curl -s ${auth} "https://api.github.com/repos/revenge-mod/revenge-xposed/releases/latest" | jq -r '.tag_name')  # 1202
      releasesName=$(curl -s ${auth} "https://api.github.com/repos/revenge-mod/revenge-xposed/releases/latest" | jq -r '.name')  # 1.2.2
      dlLink="https://github.com/revenge-mod/revenge-xposed/releases/download/$releasesTagName/app-release.apk"
      module_apk_path="$LSPatch/revenge-xposed-${releasesName}.apk"
      curl -L --progress-bar -C - -o "$module_apk_path" "$dlLink"
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatched="com.discord/.main.MainDefault"
      BugReport="https://github.com/revenge-mod/revenge-xposed/issues/new"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "$Arch" "" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatched"
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
      if [ $Android -ge 11 ]; then
        pkgVersion="189.0.798816824"
        #pkgVersion=""
      elif [ $Android -eq 10 ]; then
        pkgVersion="161.0.726587057"
      elif [ $Android -eq 9 ]; then
        pkgVersion="121.0.603393336-downloadable"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      releasesTagName=$(curl -s ${auth} "https://api.github.com/repos/Xposed-Modules-Repo/io.github.vvb2060.callrecording/releases/latest" | jq -r '.tag_name')  # 2-1.1
      releasesName=$(curl -s ${auth} "https://api.github.com/repos/Xposed-Modules-Repo/io.github.vvb2060.callrecording/releases/latest" | jq -r '.name')  # 1.1
      dlUrl="https://github.com/Xposed-Modules-Repo/io.github.vvb2060.callrecording/releases/download/${releasesTagName}/app-release.apk"
      curl -L --progress-bar -C - -o "$LSPatch/callrecording-${releasesName}.apk" "$dlUrl"
      module_apk_path=$(find "$LSPatch" -type f -name "callrecording-*.apk")
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
      activityPatched=""
      sign_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "$pkgName" "$activityPatched"
      ;;
  esac
done
#################################################################################################################################################################################################
