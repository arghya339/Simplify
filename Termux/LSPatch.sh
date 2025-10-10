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
whiteBG="\e[47m\e[30m"
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
FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null)
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

confirmPrompt() {
  Prompt=${1}
  local -n prompt_buttons=$2
  Selected=${3:-0}  # :- set value as 0 if unset
  maxLen=50
  
  # breaks long prompts into multiple lines (50 characters per line)
  lines=()  # empty array
  while [ -n "$Prompt" ]; do
    lines+=("${Prompt:0:$maxLen}")  # take first 50 characters from $Prompt starting at index 0
    Prompt="${Prompt:$maxLen}"  # removes first 50 characters from $Prompt by starting at 50 to 0
  done
  
  # print all-lines except last-line
  last_line_index=$(( ${#lines[@]} - 1 ))  # ${#lines[@]} = number of elements in lines array
  for (( i=0; i<last_line_index; i++ )); do
    echo -e "${lines[i]}"
  done
  last_line="${lines[$last_line_index]}"
  
  echo -ne '\033[?25l'  # Hide cursor
  while true; do
    show_prompt() {
      echo -ne "\r\033[K"  # n=noNewLine r=returnCursorToStartOfLine \033[K=clearLine
      echo -ne "$last_line "
      if [ ${#prompt_buttons[@]} -eq 2 ]; then
        [ $Selected -eq 0 ] && echo -ne "${whiteBG}➤ ${prompt_buttons[0]} $Reset   ${prompt_buttons[1]}" || echo -ne "  ${prompt_buttons[0]}  ${whiteBG}➤ ${prompt_buttons[1]} $Reset"  # highlight selected bt with white bg
      elif [ ${#prompt_buttons[@]} -eq 3 ]; then
        if [ $Selected -eq 0 ]; then
          echo -ne "${whiteBG}➤ ${prompt_buttons[0]} $Reset   ${prompt_buttons[1]}    ${prompt_buttons[2]}"
        elif [ $Selected -eq 1 ]; then
          echo -ne "  ${prompt_buttons[0]}  ${whiteBG}➤ ${prompt_buttons[1]} $Reset   ${prompt_buttons[2]}"
        elif [ $Selected -eq 2 ]; then
          echo -ne "  ${prompt_buttons[0]}    ${prompt_buttons[1]}  ${whiteBG}➤ ${prompt_buttons[2]} $Reset"
        fi
      fi
    }; show_prompt

    read -rsn1 key
    case $key in
      $'\E')
      # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
        read -rsn2 -t 0.1 key2  # -r=readRawInput -s=silent(noOutput) -t=timeout -n2=readTwoChar | waits upto 0.1s=100ms to read key 
        case $key2 in 
          '[C')  # right arrow key
            Selected=$((Selected + 1))
            [ $Selected -gt ${#prompt_buttons[@]} ] && Selected=$((${#prompt_buttons[@]} - 1))
            ;;
          '[D')  # left arrow key
            Selected=$((Selected - 1))
            [ $Selected -lt 0 ] && Selected=0
            ;;
        esac
        ;;
      [Yy]*|[Ii]*) Selected=0; show_prompt; break ;;
      [Nn]*|[Mm]*) Selected=1; show_prompt; break ;;
      [Cc]*) Selected=2; show_prompt; break ;;
      "") break ;;  # Enter key
    esac
  done
  echo -e '\033[?25h' # Show cursor
  return $Selected  # return Selected int index from this fun
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
    if [ "$cpuAbi" == "arm64-v8a" ]; then cpuAbi="arm64_v8a"; elif [ "$cpuAbi" == "armeabi-v7a" ]; then cpuAbi="armeabi_v7a"; fi
    # src: https://github.com/revenge-mod/revenge-manager/blob/85fdd3c2d25e509960bdb99e0e9882b16f5d541f/app/src/main/java/app/revenge/manager/installer/step/download/DownloadLibsStep.kt#L26
    libsUrl="https://tracker.vendetta.rocks/tracker/download/$pkgVersion/config.$cpuAbi"  # Size >= 60 MB
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
      dl "aria2" "$libsUrl" "config.$cpuAbi.apk"
    
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
          bash $Simplify/apkInstall.sh "${output_apk_path}" ""
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
          bash $Simplify/apkInstall.sh "${output_apk_path}" "$activityPatched"
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
    
    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Install ${appNameRef[0]} Signed app?" "buttons" && opt=Yes || opt=No
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Signed ${appNameRef[0]} apk.."
        bash $Simplify/apkInstall.sh "${output_apk_path}" "$activityPatched"
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
  Snapchat="Snapchat"
  LINE="LINE"
  if su -c "id" >/dev/null 2>&1; then
    googleDialer="PhoneByGoogle"
  fi
fi

# --- Arrays of apps list that required specific android version ---
if [ $Android -ge 10 ]; then
  apps=(
    ${Snapchat}
    Discord
    ${LINE}
    ${googleDialer}
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 9 ]; then
  apps=(
    ${Snapchat}
    Discord
    ${googleDialer}
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 8 ]; then
  apps=(
    ${Snapchat}
    Discord
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 7 ]; then
  apps=(
    ${Snapchat}
    Discord
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 6 ]; then
  apps=(
    ${Snapchat}
    "1.1.1.1 + WARP"
  )
elif [ $Android -eq 5 ]; then
  apps=(
    ${Snapchat}
    "1.1.1.1 + WARP"
  )
fi

menu() {
  local -n menu_options=$1
  local -n menu_buttons=$2
  
  selected_option=0
  selected_button=0
  
  show_menu() {
    printf '\033[2J\033[3J\033[H'
    echo "Navigate with [↑] [↓] [←] [→]"
    echo -e "Select with [↵]\n"
    for ((i=0; i<=$((${#menu_options[@]} - 1)); i++)); do
      if [ $i -eq $selected_option ]; then
        echo -e "${whiteBG}➤ ${menu_options[$i]} $Reset"
      else
        [ $(($i + 1)) -le 9 ] && echo " $(($i + 1)). ${menu_options[$i]}" || echo "$(($i + 1)). ${menu_options[$i]}"
      fi
    done
    echo
    for ((i=0; i<=$((${#menu_buttons[@]} - 1)); i++)); do
      if [ $i -eq $selected_button ]; then
        [ $i -eq 0 ] && echo -ne "${whiteBG}➤ ${menu_buttons[$i]} $Reset" || echo -ne "  ${whiteBG}➤ ${menu_buttons[$i]} $Reset"
      else
        [ $i -eq 0 ] && echo -n "  ${menu_buttons[$i]}" || echo -n "   ${menu_buttons[$i]}"
      fi
    done
    echo
  }

  printf '\033[?25l'
  while true; do
    show_menu
    read -rsn1 key
    case $key in
      $'\E')  # ESC
        # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
        read -rsn2 -t 0.1 key2
        case "$key2" in
          '[A')  # Up arrow
            selected_option=$((selected_option - 1))
            [ $selected_option -lt 0 ] && selected_option=$((${#menu_options[@]} - 1))
            ;;
          '[B')  # Down arrow
            selected_option=$((selected_option + 1))
            [ $selected_option -ge ${#menu_options[@]} ] && selected_option=0
            ;;
          '[C')  # Right arrow
            [ $selected_button -lt $((${#menu_buttons[@]} - 1)) ] && selected_button=$((selected_button + 1))
            ;;
          '[D')  # Left arrow
            [ $selected_button -gt 0 ] && selected_button=$((selected_button - 1))
            ;;
        esac
        ;;
      '')  # Enter key
        break
        ;;
      [0-9])
        read -rsn2 -t0.5 key2
        [[ "$key2" == [0-9] ]] && { key="${key}${key2}"; key=$((10#$key)); }  # Convert to integer (decimal) from strings
        if [ $key -eq 0 ]; then
          selected_option=$((${#options[@]} - 1))
        elif [ $key -gt ${#options[@]} ]; then
          selected_option=0
        else
          selected_option=$(($key - 1))
        fi
        show_menu; sleep 0.5; break
       ;;
    esac
  done
  printf '\033[?25h'

  [ $selected_button -eq 0 ] && { printf '\033[2J\033[3J\033[H'; selected=$selected_option; }
  if [ $selected_button -eq $((${#menu_buttons[@]} - 1)) ]; then
    [ "${menu_buttons[$((${#menu_buttons[@]} - 1))]}" == "<Back>" ] && { printf '\033[2J\033[3J\033[H'; return 1; } || { [ $isOverwriteTermuxProp -eq 1 ] && sed -i '/allow-external-apps/s/^/# /' "$HOME/.termux/termux.properties"; printf '\033[2J\033[3J\033[H'; echo "Script exited !!"; exit 0; }
  fi
}

while true; do
  buttons=("<Select>" "<Back>"); selected=""; if menu "apps" "buttons"; then selected="${apps[$selected]}"; else break; fi
  
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
      ghApiResponseJson=$(curl -s ${auth} "https://api.github.com/repos/revenge-mod/revenge-xposed/releases/latest")
      releasesTagName=$(jq -r '.tag_name' <<< "$ghApiResponseJson")  # 1202
      releasesName=$(jq -r '.name' <<< "$ghApiResponseJson")  # 1.2.2
      dlLink="https://github.com/revenge-mod/revenge-xposed/releases/download/$releasesTagName/app-release.apk"
      module_apk_path="$LSPatch/revenge-xposed-${releasesName}.apk"
      curl -L --progress-bar -C - -o "$module_apk_path" "$dlLink"
      echo -e "$info module_apk_path: $module_apk_path"
      activityPatched="com.discord/.main.MainDefault"
      BugReport="https://github.com/revenge-mod/revenge-xposed/issues/new"
      build_app "$pkgName" "appName" "$pkgVersion" "" "$Arch" "" "$module_apk_path" "$BugReport" "$pkgName" "$activityPatched"
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
        pkgVersion="194.0.813798200"
        #pkgVersion=""
      elif [ $Android -eq 10 ]; then
        pkgVersion="161.0.726587057"
      elif [ $Android -eq 9 ]; then
        pkgVersion="121.0.603393336-downloadable"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      ghApiResponseJson=$(curl -s ${auth} "https://api.github.com/repos/Xposed-Modules-Repo/io.github.vvb2060.callrecording/releases/latest")
      releasesTagName=$(jq -r '.tag_name' <<< "$ghApiResponseJson")  # 2-1.1
      releasesName=$(jq -r '.name' <<< "$ghApiResponseJson")  # 1.1
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
      activityPatched="com.cloudflare.onedotonedotonedotone/com.cloudflare.app.presentation.main.SplashActivity"
      sign_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "$pkgName" "$activityPatched"
      ;;
  esac
done
#################################################################################################################################################################################################
