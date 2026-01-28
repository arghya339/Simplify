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
pikoTwitter="$Simplify/pikoTwitter"
RVX="$Simplify/RVX"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$pikoTwitter" "$RVX" "$SimplUsr"  # Create $Simplify, $pikoTwitter, $RVX and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir
FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null)
RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
if [ -f "$HOME/.config/gh/hosts.yml" ] && gh auth status > /dev/null 2>&1; then
  token="$(gh auth token)"  # oauth_token: gho_************************************
elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
  token="$(jq -r '.PAT' "$simplifyJson" 2>/dev/null)"  # PAT: ghp_************************************
fi
[ -n "$token" ] && auth="-H \"Authorization: Bearer $token\"" || auth=""

# --- Checking Android Version ---
if [ $Android -le 7 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by pikoTwitter Patches.${Reset}"
  return 1
fi

echo -e "$info ${Blue}Target device:${Reset} $Model"

if [ "$FetchPreRelease" -eq 0 ]; then
  # --- Download ReVanced CLI v3 ---
  ReVancedCLIJar="$pikoTwitter/revanced-cli-4.6.2-all.jar"
  if [ ! -f "$ReVancedCLIJar" ]; then
    echo -e "$running Downloading revanced-cli-4.6.2-all.jar.."
    url="https://github.com/inotia00/revanced-cli/releases/download/v4.6.2/revanced-cli-4.6.2-all.jar"
    while true; do
      #curl -L --progress-bar -C - -o "$ReVancedCLIJar" "$url"
      aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$(basename "$ReVancedCLIJar")" -d "$(dirname "$ReVancedCLIJar")" "$url"
      if [ $? -eq 0 ]; then
        echo  # White Space
        break
      fi
      echo -e "${bad} ${Red}Download failed! retrying in 5 seconds..${Reset}"
      sleep 5  # Wait 5 seconds
    done
  fi
  # --- Download ReVanced Integrations ---
  bash $Simplify/dlGitHub.sh "crimera" "revanced-integrations" "$release" ".apk" "$pikoTwitter"
  IntegrationsApk=$(find "$pikoTwitter" -type f -name "revanced-integrations-*.apk" -print -quit)
  echo -e "$info ${Blue}IntegrationsApk:${Reset} $IntegrationsApk"
else
  # --- Download ReVanced CLI v5 ---
  bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
  ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
fi
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

if [ "$FetchPreRelease" -eq 0 ]; then
  release="latest"  # Use latest release
  fileType=".jar"
  fileName="piko-twitter-patches-*.jar"
  tag=$(curl -sL ${auth} "https://api.github.com/repos/crimera/piko/releases/latest" | jq -r '.tag_name')
else
  release="pre"  # Use pre-release
  fileType=".rvp"
  fileName="patches-*.rvp"
  tag=$(curl -sL ${auth} "https://api.github.com/repos/crimera/piko/releases" | jq -r '.[].tag_name | select(contains("dev"))' | head -n 1)
fi

# --- Download piko Patches ---
bash $Simplify/dlGitHub.sh "crimera" "piko" "$release" "$fileType" "$pikoTwitter"
PatchesRvp=$(find "$pikoTwitter" -type f -name "$fileName" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"
#echo -e "${Cyan}~~~~~~~~~~~~~~~~~~~~~release notes~~~~~~~~~~~~~~~~~~~~~~${Reset}"
echo -e "${Cyan}~~~~~~~~~~~~~~~~~~~~~~~changelog~~~~~~~~~~~~~~~~~~~~~~~~${Reset}"
curl -sL ${auth} "https://api.github.com/repos/crimera/piko/releases/tags/$tag" | jq -r .body | glow  # Display the release notes
echo -e "${Cyan}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${Reset}"

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

# --- Get compatible Packages version ---
getVersion() {
  local pkgName="$1"
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
  preVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | tail -n 1)
  if [ -z "$pkgVersion" ] || [ "$pkgVersion" == "Any" ] || [ "$pkgVersion" == "null" ]; then
    if [ "$release" == "pre" ]; then
      pkgVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases" | jq -r '.[].tag_name' | head -1)  # Last Releases
    else
      pkgVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases/latest" | jq -r '.tag_name')  # Latest Releases
    fi
    preVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases" | jq -r '.[].tag_name' | head -n 2 | tail -n 1)  # Previous Releases
    if [ -z "$pkgVersion" ]; then
      pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-patches -d=true -f=$pkgName -i=false -o=false -p=false -u -v=true $PatchesRvp | grep -oP 'Requires X \K[\d.]+-release\.\d+' | sort -rV | head -n 1)
      preVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-patches -d=true -f=$pkgName -i=false -o=false -p=false -u -v=true $PatchesRvp | grep -oP 'Requires X \K[\d.]+-release\.\d+' | sort -rV | head -n 2 | tail -n 1)
    fi
  fi

  pre_stock_apk_path=$(find "$Download" -type f -name "${appName[0]}_v${preVersion}-*.apk" -print -quit)
  [[ -f "$pre_stock_apk_path" ]] && rm "$pre_stock_apk_path"  # Remove previous stock apk if exists
}

#  --- Patching Twitter apk ---
patch_twitter() {
  local -n stock_apk_ref=$1
  local outputAPK=$2
  without_ext="${outputAPK%.*}"  # remove file extension (.apk)
  local log="$SimplUsr/piko-twitter_patch-log.txt"
  
  if [ "$FetchPreRelease" -eq 0 ]; then
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar patch -b $PatchesRvp -m $IntegrationsApk \
      -o "$outputAPK" "${stock_apk_ref[0]}" \
      -i "Bring back twitter" -i "Enable app downgrading" -e "Export all activities" \
      --custom-aapt2-binary="$HOME/aapt2" --purge $ripLib -f | tee "$log"
  else
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
      -o "$outputAPK" "${stock_apk_ref}" \
      -e "Bring back twitter" -e "Enable app downgrading" -d "Export all activities" \
      --custom-aapt2-binary="$HOME/aapt2" --purge $ripLib -f | tee "$log"
  fi
  
  if [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, Piko Twitter Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/crimera/piko/issues/new"
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

# --- Twitter app Info ---
appName=("X")
pkgName="com.twitter.android"
#pkgVersion="11.4.0-release.0"
if [ -z "$pkgVersion" ]; then
  getVersion "$pkgName"
  pkgVersion="$pkgVersion"
fi
Type="BUNDLE"
Arch=("universal")
outputAPK="$SimplUsr/piko-twitter_v${pkgVersion}-$cpuAbi.apk"
fileName=$(basename $outputAPK)
activityPatched="com.twitter.android/.StartActivity"

# --- Download Twitter apk ---
APKMdl "$pkgName" "" "$pkgVersion" "$Type" "${Arch[0]}"  # Download stock Twitter apk from APKMirror
xFileName=$(basename "$(find "$Download" -type f -name "${appName[0]}_v*-$cpuAbi.apk" -print -quit)")
stock_apk_path=("$Download/$xFileName")

sleep 0.5  # Wait 500 milliseconds
if [ -f "${stock_apk_path[0]}" ]; then
  echo -e "$good ${Green}Downloaded ${appName[0]} APK found:${Reset} ${stock_apk_path[0]}"
  echo -e "$running Patching Piko Twitter.."
  termux-wake-lock
  patch_twitter "stock_apk_path" "$outputAPK"
  termux-wake-unlock
fi

# --- app installation prompt ---
if [ -f "$outputAPK" ]; then
  buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install Piko Twitter app?" "buttons" && opt=Yes || opt=No
  case $opt in
    y*|Y*|"")
      echo -e "$running Please Wait !! Installing Patched Piko Twitter apk.."
      bash $Simplify/apkInstall.sh "$outputAPK" "$activityPatched"
      ;;
    n*|N*) echo -e "$notice Piko Twitter Installaion skipped!" ;;
  esac
    
  buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share Piko Twitter app?" "buttons" "1" && opt=Yes || opt=No
  case $opt in
    y*|Y*|"")
      echo -e "$running Please Wait !! Sharing Patched Piko Twitter apk.."
      termux-open --send "$outputAPK"
      ;;
    n*|N*) echo -e "$notice Piko Twitter Sharing skipped!"
      echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)" && sleep 3
      am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.google.android.documentsui/com.android.documentsui.files.FilesActivity &> /dev/null  # Open Android Files by Google
      if [ $? -ne 0 ] || [ $? -eq 2 ]; then
        am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.android.documentsui/com.android.documentsui.files.FilesActivity > /dev/null 2>&1  # Open Android Files
      fi
      ;;
  esac
fi
#######################################################################