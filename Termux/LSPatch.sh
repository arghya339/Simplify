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
LSPatch="$Simplify/LSPatch"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$LSPatch" "$SimplUsr"  # Create $Simplify, $LSPatch and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
if [ -f "$HOME/.config/gh/hosts.yml" ] && gh auth status > /dev/null 2>&1; then
  # oauth_token: gho_************************************
  token=$(grep -A2 "users:" ~/.config/gh/hosts.yml | grep -v "users:" | grep -A1 "oauth_token:" | awk '/oauth_token:/ {getline; print $2}')
elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
  # PAT: ghp_************************************
  token=$(jq -r '.PAT' "$simplifyJson" 2>/dev/null)
else
  token=""
fi
if [ -z "$token" ]; then
  auth="-H \"Authorization: Bearer $token\""
else
  auth=""
fi

# --- Checking Android Version ---
if [ $Android -le 4 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by LSPatch Module.${Reset}"
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

bash $Simplify/dlGitHub.sh "JingMatrix" "LSPatch" "latest" ".jar" "$LSPatch"
LSPatchJar=$(find "$LSPatch" -type f -name "lspatch-*.jar" -print -quit)
echo -e "$info ${Blue}LSPatchJar:${Reset} $LSPatchJar"

#  --- Patch Apps ---
patch_app() {
  local stock_apk_path=$1
  local module_apk_path=$2
  local appName=$3
  local log="$SimplUsr/$appName-LSPatch_patch-log.txt"
  local BugReportUrl=$4

  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $LSPatchJar "$stock_apk_path" -m "$module_apk_path" -o "$SimplUsr/" | tee "$log"

  if [ $? != 0 ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "$BugReportUrl"
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
  local web=$6
  local -n stock_apk_ref=$7
  local stockFileName=$(basename "${stock_apk_ref[0]}")
  local stockFileNameWOExt="${stockFileName%.*}"
  local module_apk_path=$8
  local BugReportUrl=$9
  local pkgPatches=$10
  local activityPatches=$11


  if [ "$web" == "APKMirror" ]; then
    bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
  elif [ "$web" == "Uptodown" ]; then
    bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from Uptodown
  fi

  if [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_ref[0]}"
    echo -e "$running Patching ${appNameRef[0]} LSPatch.."
    patch_app "${stock_apk_ref[0]}" "$module_apk_path" "${appNameRef[0]}" "$BugReportUrl"
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
          bash $Simplify/apkInstall.sh "${output_apk_path}" "$pkgName" ""
          ;;
        M*|m*)
          echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} LSPatch apk.."
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" "${output_apk_path}" \"${appNameRef[0]}\" $pkgName $pkgVersion" &> /dev/null
          su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" "${output_apk_path}" \"${appNameRef[0]}\" $pkgName $pkgVersion" | tee "$SimplUsr/${appNameRef[0]}-LSPatch_mount-log.txt"
          rm "${output_apk_path}"
          ;;
        N*|n*) echo -e "$notice ${appNameRef[0]} LSPatch Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} LSPatch Installaion skipped." ;;
      esac
    
    else
      
      echo -e "[?] ${Yellow}Do you want to Install ${appNameRef[0]} LSPatch app? [Y/n] ${Reset}\c" && read opt
      case $opt in
        y*|Y*|"")
          echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} LSPatch apk.."
          bash $Simplify/apkInstall.sh "${output_apk_path}" "$pkgName" "$activityPatches"
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
          echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
          ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} LSPatch Sharing skipped." ;;
      esac

    fi

  fi
}

sign_app() {
  local pkgName=$1
  local -n appNameRef=$2
  local pkgVersion=$3
  local Type=$4
  local -n ArchRef=$5
  local web=$6
  local -n stock_apk_ref=$7
  local stockFileName=$(basename "${stock_apk_ref[0]}")
  local stockFileNameWOExt="${stockFileName%.*}"
  local pkgPatches=$8
  local activityPatches=$9
  
  
  if [ "$web" == "APKMirror" ]; then
    bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
  else
    bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from Uptodown
  fi
  
  if [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_ref[0]}"
    echo -e "$running Checking ${appNameRef[0]} Certificate.."
    checkOwner=$($PREFIX/lib/jvm/java-21-openjdk/bin/keytool -printcert -jarfile "${stock_apk_ref[0]}" | grep -oP 'Owner: \K.*')
    if [ -z "$checkOwner" ]; then
      echo -e "$notice keytool error: SHA-256 digest error!"
      local output_apk_path="$SimplUsr/$stockFileNameWOExt-signed.apk"
      local fileName=$(basename "${output_apk_path}")
      $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar sign --ks $Simplify/ks.keystore --ks-pass pass:123456 --ks-key-alias ReVancedKey --key-pass pass:123456 --out "${output_apk_path}" "${stock_apk_ref[0]}"
      rm "$output_apk_path.idsig"
      $PREFIX/lib/jvm/java-21-openjdk/bin/keytool -printcert -jarfile "${output_apk_path}" | grep -oP 'Owner: \K.*' 2>/dev/null
      if [ $? == 0 ]; then
        $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar verify --print-certs "${output_apk_path}" | grep -oP 'Signer #1 certificate DN: \K.*'
      fi
    fi
  fi
  
  if [ -f "${output_apk_path}" ]; then
    
    echo -e "[?] ${Yellow}Do you want to Install ${appNameRef[0]} Signed app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Signed ${appNameRef[0]} apk.."
        bash $Simplify/apkInstall.sh "${output_apk_path}" "$pkgName" "$activityPatches"
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
        echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
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

if [ "$cpuAbi" == "arm64-v8a" ] || [ "$cpuAbi" == "armeabi-v7a" ]; then
  Snapchat=("Snapchat")
  LINE=("LINE")
  if su -c "id" >/dev/null 2>&1; then
    googleDialer=("Phone by Google")
  fi
fi

if [ $Android -ge 10 ]; then
  apps=(
    Quit
    "${Snapchat[0]}"
    Discord
    "${LINE[0]}"
    "${googleDialer[0]}"
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 9 ]; then
  apps=(
    Quit
    "${Snapchat[0]}"
    Discord
    "${googleDialer[0]}"
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 8 ]; then
  apps=(
    Quit
    "${Snapchat[0]}"
    Discord
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 7 ]; then
  apps=(
    Quit
    "${Snapchat[0]}"
    Discord
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 6 ]; then
  apps=(
    Quit
    "${Snapchat[0]}"
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    "${Snapchat[0]}"
    "1.1.1.1 + WARP"
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
  elif [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice You chose: ${apps[$idx]}"
  else
    echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
  fi
  
  case "${apps[$idx]}" in
    Snapchat)
      appName=("Snapchat")
      pkgName="com.snapchat.android"
      pkgVersion="12.33.1.19"
      #pkgVersion=""
      Type="BUNDLE"
      Arch=("arm64-v8a + armeabi-v7a")
      stock_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      if [ "$cpuAbi" == "arm64-v8a" ]; then
        arch="armv8"
      elif [ "$cpuAbi" == "armeabi-v7a" ]; then
        arch="armv7"
      else
        arch="all"
      fi
      regex="snapenhance_.*-${arch}-release-signed.apk"
      bash $Simplify/dlGitHub.sh "rhunk" "SnapEnhance" "latest" ".apk" "$LSPatch" "$regex"
      module_apk_path=$(find "$LSPatch" -type f -name "snapenhance_*-${arch}-release-signed.apk")
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatches="com.snapchat.android/.LandingPageActivity"
      BugReport="https://github.com/rhunk/SnapEnhance/issues/new?template=bug_report.yml"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "stock_apk_path" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatches"
      ;;
    Discord)
      appName=("Discord")
      pkgName="com.discord"
      pkgVersion="289.20-Stable"
      assetsName="Discord_v289.20-Stable-289020-arm64-v8a+armeabi-v7a+x86_64+x86-en-xxhdpi.apks"
      dlUrl="https://github.com/arghya339/Simplify/releases/download/all/$assetsName"
      aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$assetsName" -d "$Download" "$dlUrl"
      stock_apks_path=("$Download/$assetsName")
      apks_without_ext="${assetsName%.*}"
      stock_apk_path=("$Download/$apks_without_ext.apk")
      bash $Simplify/dlGitHub.sh "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
      APKEditor=$(find "$Simplify" -type f -name "APKEditor-*.jar" -print -quit)
      $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $APKEditor m -i $stock_apks_path -o "$stock_apk_path"
      releasesTagName=$(curl -s ${auth} "https://api.github.com/repos/revenge-mod/revenge-xposed/releases/latest" | jq -r '.tag_name')  # 1202
      releasesName=$(curl -s ${auth} "https://api.github.com/repos/revenge-mod/revenge-xposed/releases/latest" | jq -r '.name')  # 1.2.2
      dlLink="https://github.com/revenge-mod/revenge-xposed/releases/download/$releasesTagName/app-release.apk"
      module_apk_path="$LSPatch/revenge-xposed-${releasesName}.apk"
      curl -L --progress-bar -C - -o "$module_apk_path" "$dlLink"
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatches="com.discord/.main.MainDefault"
      BugReport="https://github.com/revenge-mod/revenge-xposed/issues/new"
      build_app "$pkgName" "appName" "$pkgVersion" "" "" "" "stock_apk_path" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatches"
      ;;
    LINE)
      appName=("LINE")
      pkgName="jp.naver.line.android"
      pkgVersion="15.10.2"
      #pkgVersion=""
      Type="BUNDLE"
      Arch=("arm64-v8a + armeabi-v7a")
      stock_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      regex="LineXtra-.*-all-release.apk"
      bash $Simplify/dlGitHub.sh "yagiyuu" "LineXtra" "latest" ".apk" "$LSPatch" "$regex"
      module_apk_path=$(find "$LSPatch" -type f -name "LineXtra-*-all-release.apk")
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatches="jp.naver.line.android/.activity.SplashActivity"
      BugReport="https://github.com/yagiyuu/LineXtra/issues"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "stock_apk_path" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatches"
      ;;
    Phone\ by\ Google)
      appName=("Phone by Google")
      pkgName="com.google.android.dialer"
      if [ $Android -ge 11 ]; then
        pkgVersion="180.0.771769344"
        #pkgVersion=""
      elif [ $Android -eq 10 ]; then
        pkgVersion="161.0.726587057"
      elif [ $Android -eq 9 ]; then
        pkgVersion="121.0.603393336-downloadable"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      stock_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      releasesTagName=$(curl -s ${auth} "https://api.github.com/repos/Xposed-Modules-Repo/io.github.vvb2060.callrecording/releases/latest" | jq -r '.tag_name')  # 2-1.1
      releasesName=$(curl -s ${auth} "https://api.github.com/repos/Xposed-Modules-Repo/io.github.vvb2060.callrecording/releases/latest" | jq -r '.name')  # 1.1
      dlUrl="https://github.com/Xposed-Modules-Repo/io.github.vvb2060.callrecording/releases/download/${releasesTagName}/app-release.apk"
      curl -L --progress-bar -C - -o "$LSPatch/callrecording-${releasesName}.apk" "$dlUrl"
      module_apk_path=$(find "$LSPatch" -type f -name "callrecording-*.apk")
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatches="com.google.android.dialer/.extensions.GoogleDialtactsActivity"
      BugReport="https://github.com/vvb2060/CallRecording/issues/new"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "stock_apk_path" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatches"
      ;;
    1.1.1.1\ +\ WARP)
      appName=("1.1.1.1 + WARP")
      pkgName="com.cloudflare.onedotonedotonedotone"
      #pkgVersion="6.38.4"
      pkgVersion=""
      Type="BUNDLE"
      Arch=("universal")
      apk_path=$(find "$Download" -type f -name "${appName[0]}_v*-$cpuAbi.apk")
      stock_apk_path=("$apk_path")
      activityPatches=""
      sign_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "stock_apk_path" "$pkgName" "$activityPatches"
      ;;
  esac
done
#########################################################################################################################################################################################
