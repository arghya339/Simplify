#!/usr/bin/bash

echo -e "$info ${Blue}Target device:${Reset} $Model"

# --- Download ReVanced CLI v5 ---
bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

if [ "$FetchPreRelease" -eq 0 ]; then
  release="latest"  # Use latest release
  tag=$(curl -sL ${auth} "https://api.github.com/repos/crimera/piko/releases/latest" | jq -r '.tag_name')
else
  release="pre"  # Use pre-release
  tag=$(curl -sL ${auth} "https://api.github.com/repos/crimera/piko/releases" | jq -r '.[].tag_name | select(contains("dev"))' | head -n 1)
fi

# --- Download piko Patches ---
bash $Simplify/dlGitHub.sh "crimera" "piko" "$release" ".rvp" "$pikoTwitter"
PatchesRvp=$(find "$pikoTwitter" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"
#echo -e "${Cyan}~~~~~~~~~~~~~~~~~~~~~release notes~~~~~~~~~~~~~~~~~~~~~~${Reset}"
echo -e "${Cyan}~~~~~~~~~~~~~~~~~~~~~~~changelog~~~~~~~~~~~~~~~~~~~~~~~~${Reset}"
curl -sL ${auth} "https://api.github.com/repos/crimera/piko/releases/tags/$tag" | jq -r .body | glow  # Display the release notes
echo -e "${Cyan}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${Reset}"

# --- Get compatible Packages version ---
getVersion() {
  local pkgName="$1"
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
  preVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | tail -n 1)
  if [ -z "$pkgVersion" ] || [ "$pkgVersion" == "Any" ] || [ "$pkgVersion" == "null" ]; then
    if [ "$release" == "pre" ]; then
      pkgVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases" | jq -r '.[0].tag_name')  # Last Releases
    else
      pkgVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases/latest" | jq -r '.tag_name')  # Latest Releases
    fi
    preVersion=$(curl -sL ${auth} "https://api.github.com/repos/crimera/twitter-apk/releases" | jq -r '.[1].tag_name')  # Previous Releases
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
  
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "${stock_apk_ref}" \
    -e "Bring back twitter" -e "Enable app downgrading" -d "Export all activities" \
    --custom-aapt2-binary="$HOME/aapt2" --purge $ripLib -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, Piko Twitter Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/crimera/piko/issues/new"
    termux-open --send "$log"
    rm -rf "$without_ext-temporary-files"  # Remove temporary files directory
  else
    rm -f "$without_ext-options.json" "$without_ext.keystore"
  fi
}

# --- Twitter app Info ---
appName=("X")
pkgName="com.twitter.android"
pkgVersion=""
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
    Yes)
      echo -e "$running Please Wait !! Installing Patched Piko Twitter apk.."
      apkInstall "$outputAPK" "$activityPatched"
      ;;
    No) echo -e "$notice Piko Twitter Installaion skipped!" ;;
  esac
    
  buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share Piko Twitter app?" "buttons" "1" && opt=Yes || opt=No
  case $opt in
    Yes)
      echo -e "$running Please Wait !! Sharing Patched Piko Twitter apk.."
      termux-open --send "$outputAPK"
      ;;
    No) echo -e "$notice Piko Twitter Sharing skipped!"
      echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)" && sleep 3
      am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.google.android.documentsui/com.android.documentsui.files.FilesActivity &> /dev/null  # Open Android Files by Google
      if [ $? -ne 0 ] || [ $? -eq 2 ]; then
        am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.android.documentsui/com.android.documentsui.files.FilesActivity > /dev/null 2>&1  # Open Android Files
      fi
      ;;
  esac
fi
#######################################################################