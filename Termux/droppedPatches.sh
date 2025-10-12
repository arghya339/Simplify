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
      [ $Selected -eq 0 ] && echo -ne "${whiteBG}➤ ${prompt_buttons[0]} $Reset   ${prompt_buttons[1]}" || echo -ne "  ${prompt_buttons[0]}  ${whiteBG}➤ ${prompt_buttons[1]} $Reset"  # highlight selected bt with white bg
    }; show_prompt

    read -rsn1 key
    case $key in
      $'\E')
      # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
        read -rsn2 -t 0.1 key2  # -r=readRawInput -s=silent(noOutput) -t=timeout -n2=readTwoChar | waits upto 0.1s=100ms to read key 
        case $key2 in 
          '[C') Selected=1 ;;  # right arrow key
          '[D') Selected=0 ;;  # left arrow key
        esac
        ;;
      [Yy]*) Selected=0; show_prompt; break ;;
      [Nn]*) Selected=1; show_prompt; break ;;
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

    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Install ${appNameRef[0]} Dropped app?" "buttons" && opt=Yes || opt=No
    case $opt in
      y*|Y*|"")
        echo -e "$notice ${Yellow}Warning! Disable auto updates for the patched app to avoid unexpected issues.${Reset}"
        echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} Dropped apk.."
        bash $Simplify/apkInstall.sh "$outputAPK" "$activityPatched"
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
        if [ $key -eq 0 ]; then
          selected_option=$((${#menu_options[@]} - 1))
        elif [ $key -gt ${#menu_options[@]} ]; then
          selected_option=0
        else
          selected_option=$((key - 1))
        fi
        show_menu; sleep 0.5; break
       ;;
    esac
  done
  printf '\033[?25h'

  [ $selected_button -eq 0 ] && { printf '\033[2J\033[3J\033[H'; selected=$selected_option;}
  if [ $selected_button -eq $((${#menu_buttons[@]} - 1)) ]; then
    [ "${menu_buttons[$((${#menu_buttons[@]} - 1))]}" == "<Back>" ] && { printf '\033[2J\033[3J\033[H'; return 1; } || { [ $isOverwriteTermuxProp -eq 1 ] && sed -i '/allow-external-apps/s/^/# /' "$HOME/.termux/termux.properties"; printf '\033[2J\033[3J\033[H'; echo "Script exited !!"; exit 0; }
  fi
}

while true; do
  buttons=("<Select>" "<Back>"); if menu "apps" "buttons"; then selected="${apps[$selected]}"; else break; fi
  
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
