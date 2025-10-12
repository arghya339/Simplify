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
  jdkVersion=$(jq -r '.openjdk' "$simplifyJson" 2>/dev/null)  # Get openjdk value (version) from json
else
  jdkVersion="21"
fi
Serial=$(su -c 'getprop ro.serialno')  # Get Serial Number required root
Model=$(getprop ro.product.model)  # Get Device Model
RV="$Simplify/RV"
RVX="$Simplify/RVX"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$RV" "$RVX" "$SimplUsr"  # Create $Simplify, $RV, $RVX and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir
FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null)
RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
ReadPatchesFile="$(jq -r '.ReadPatchesFile' "$simplifyJson" 2>/dev/null)"
Branding=$(jq -r '.Branding' "$simplifyJson" 2>/dev/null)
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

# --- Download ReVanced CLI ---
bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

# --- Download ReVanced Patches ---
if [ "$FetchPreRelease" -eq 0 ]; then
  release="latest"  # Use latest release
else
  release="pre"  # Use pre-release
fi
bash $Simplify/dlGitHub.sh "ReVanced" "revanced-patches" "$release" ".rvp" "$RV"
PatchesRvp=$(find "$RV" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

# --- Download Vanced MicroG ---
if ! su -c "id" >/dev/null 2>&1; then
  if [ "$Android" -ge "6" ]; then
    bash $Simplify/dlGitHub.sh "inotia00" "VancedMicroG" "latest" ".apk" "$SimplUsr"
    VancedMicroG=$(find "$SimplUsr" -type f -name "microg-*.apk" -print -quit)
    echo -e "$info ${Blue}VancedMicroG:${Reset} $VancedMicroG"
  elif [ $Android -eq 5 ]; then
    VancedMicroG="$SimplUsr/microg-0.2.22.212658.apk"
    if [ ! -f "$VancedMicroG" ]; then
      curl -sL "https://github.com/TeamVanced/VancedMicroG/releases/download/v0.2.22.212658-212658001/microg.apk" --progress-bar -C - -o "$VancedMicroG"
    fi
  fi
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
  
  preVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | tail -n 1)
  pre_stock_apk_path=$(find "$Download" -type f -name "${appName[0]}_v${preVersion}-*.apk" -print -quit)
  [[ -f "$pre_stock_apk_path" ]] && rm "$pre_stock_apk_path"  # Remove previous stock apk if exists
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
}

#  --- Patching Apps Method ---
patch_app() {
  local stock_apk_ref="${1}"
  local -n patches=$2  # nameref (-n) accept an array name as parameter
  local outputAPK=$3
  without_ext="${outputAPK%.*}"  # remove file extension (.apk)
  local log="$SimplUsr/$appName-RV_patch-log.txt"
  local appName=$4
  
  if [ "$appName" == "Instagram" ] || [ "$appName" == "Facebook" ] || [ "$appName" == "Facebook Messenger" ] || [ "$appName" == "Threads" ]; then
    bash $Simplify/dlGitHub.sh "ReVanced" "revanced-cli" "pre" ".jar" "$RV"
    ReVancedCLIJar=$(find "$RV" -type f -name "revanced-cli-*-all.jar" -print -quit)
    echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"
    universalPatches=(
      -d "Hex"
    )
  elif [ "$appName" == "TikTok" ]; then
    universalPatches=(
      -e "Spoof SIM country" -OnetworkCountryIso="US (United States)" -OsimCountryIso="US (United States)"
      -e "Disable Pairip license check"
    )
  elif [ "$appName" == "Rakuten Viber Messenger" ]; then
    universalPatches=(
      -e "Spoof SIM country" -OnetworkCountryIso="US (United States)" -OsimCountryIso="US (United States)"
      -e "Disable Pairip license check"
      -e "Remove screenshot restriction"
    )
  else
    universalPatches=(
      -e "Change version code" -OversionCode="2147483647" 
      -e "Disable Pairip license check" 
      -e "Predictive back gesture" 
      -e "Remove share targets"
      -e "Remove screen capture restriction"
      -e "Remove screenshot restriction"
    )
  fi
  echo -e "$running Patching ${appName} RV.."
  if [ "$appName" == "Instagram" ] || [ "$appName" == "Facebook" ] || [ "$appName" == "Facebook Messenger" ] || [ "$appName" == "Threads" ]; then
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "${stock_apk_ref}" \
    "${patches[@]}" \
    "${universalPatches[@]}" \
    --custom-aapt2-binary="$HOME/aapt2" \
    --purge -f | tee "$log"
  else
    ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
      -o "$outputAPK" "${stock_apk_ref}" \
      "${patches[@]}" \
      "${universalPatches[@]}" \
      --custom-aapt2-binary="$HOME/aapt2" \
      --purge $ripLib -f | tee "$log"
  fi
  
  if grep -q "OutOfMemory" "$log"; then
    echo -e "$bad ${Red}OutOfMemoryError${Reset}: ${Yellow}Device RAM overloaded!${Reset}\n ${Blue}Solutions${Reset}:\n   1. ${Yellow}Close background apps.${Reset}\n   2. ${Yellow}Use device with ≥4GB ~ ≥6GB RAM for patching apk.${Reset}"
  elif [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/ReVanced/revanced-patches/issues/new?template=bug_report.yml"
    termux-open --send "$log"
    rm -rf "$without_ext-temporary-files"  # Remove temporary files directory
  else
    if [ "$appName" == "Instagram" ] || [ "$appName" == "Facebook" ] || [ "$appName" == "Facebook Messenger" ] || [ "$appName" == "Threads" ]; then
      [[ -f "$without_ext-options.json" ]] && rm -f "$without_ext-options.json"
      rm -f "$without_ext.keystore"
    else
      rm -f "$without_ext.keystore"
    fi
  fi
}

# --- Collect the enable/disable patches name with options in arrays ---
yt_patches_args=(
  # enable patches with their options
  -e "Change header" -O header="$SimplUsr/.branding/youtube/header/$Branding"
  
  # disable patches
  -d "Announcements"
)

if su -c "id" >/dev/null 2>&1; then
  yt_patches_args+=(
    -d "GmsCore support"
    -e "Custom branding" -O appName=YouTube -O iconPath="$SimplUsr/.branding/youtube/launcher/$Branding"
  )
else
  yt_patches_args+=(
    -e "GmsCore support" -O gmsCoreVendorGroupId="com.mgoogle"
    -e "Custom branding" -O appName="YouTube RV" -O iconPath="$SimplUsr/.branding/youtube/launcher/$Branding"
  )
fi

if su -c "id" >/dev/null 2>&1; then
  spotify_patches_args=(
    -e "Change lyrics provider"
    -e "Custom theme"
    -d "Spoof client"
    -d "Hide Create button"
 )
else
  spotify_patches_args=(
    -e "Change lyrics provider"
    -e "Custom theme"
    
    -d "Hide Create button"
 )
fi

tiktok_patches_args=(
  -e "SIM spoof"
)

photos_patches_args=()

if su -c "id" >/dev/null 2>&1; then
  photos_patches_args+=(-d "GmsCore support")
else
  photos_patches_args+=(-e "GmsCore support" -O gmsCoreVendorGroupId="com.mgoogle")
fi

recorder_patches_args=()

instagram_patches_args=()

facebook_patches_args=()

fb_messenger_patches_args=()

viber_patches_args=()

lightroom_patches_args=()

photomath_patches_args=()

duolingo_patches_args=()

rar_patches_args=()

prime_video_patches_args=(
  -e "Rename shared permissions"
)

twitch_patches_args=()

tumblr_patches_args=(
  -e "Fix old versions"
)

threads_patches_args=()

strava_patches_args=()

soundcloud_patches_args=()

protonmail_patches_args=()

myfitnesspal_patches_args=()

crunchyroll_patches_args=()

cricbuzz_patches_args=()

# When $ReadPatchesFile is Enabled
if [ "$ReadPatchesFile" -eq 1 ]; then
  
  # Default content for new files
  default_content=(
    # [0] YouTube
    '-e "Change header" -O header="/sdcard/Simplify/.branding/youtube/header/google_family"
-d "Announcements"'
    
    # [1] Spotify
    '-e "Change lyrics provider"
-e "Custom theme"
-d "Hide Create button"'
    
    # [2] TikTok
    '-e "SIM spoof"'
    
    # [3] Photos
    ''
    
    # [4] Instagram, [5] Facebook, [6] FbMessenger, [7] Viber, [8] Lightroom, [9] Photomath, [10] Duolingo, [11] RAR | No default patches
    '' '' '' '' '' '' '' ''
    
    # [12] PrimeVideo
    '-e "Rename shared permissions"'
    
    # [13] Twitch | No default patches
    ''
    
    # [14] Tumblr
    '-e "Fix old versions"'
    
    # [15] Threads, [16] Strava, [17] SoundCloud, [18] ProtonMail, [19] MyFitnessPal, [20] Crunchyroll, [21] Cricbuzz | No default patches
    '' '' '' '' '' '' ''
  )
  
  # Array to stores arrays-names
  arraynames=(
    yt_patches_args
    spotify_patches_args
    tiktok_patches_args
    photos_patches_args
    instagram_patches_args
    facebook_patches_args
    fb_messenger_patches_args
    viber_patches_args
    lightroom_patches_args
    photomath_patches_args
    duolingo_patches_args
    rar_patches_args
    prime_video_patches_args
    twitch_patches_args
    tumblr_patches_args
    threads_patches_args
    strava_patches_args
    soundcloud_patches_args
    protonmail_patches_args
    myfitnesspal_patches_args
    crunchyroll_patches_args
    cricbuzz_patches_args
  )
  
  # Create Empty Files if it doesn’t exist
  for ((i=0; i<${#arraynames[@]}; i++)); do
    if [ ! -e "$SimplUsr/${arraynames[$i]}.txt" ]; then
      #touch "$SimplUsr/${arraynames[$i]}.txt"
      printf "%s\n" "${default_content[i]}" > "$SimplUsr/${arraynames[$i]}.txt"
      if [ "${arraynames[$i]}" == "yt_patches_args" ] || [ "${arraynames[$i]}" == "photos_patches_args" ]; then
        if su -c "id" >/dev/null 2>&1; then
          echo "-d \"GmsCore support\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          if [ "${arraynames[$i]}" == "yt_patches_args" ]; then
            echo "-e \"Custom branding\" -O appName=YouTube -O iconPath=\"/sdcard/Simplify/.branding/youtube/launcher/google_family\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          fi
        else
          echo "-e \"GmsCore support\" -O gmsCoreVendorGroupId=\"com.mgoogle\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          if [ "${arraynames[$i]}" == "yt_patches_args" ]; then
            echo "-e \"Custom branding\" -O appName=\"YouTube RV\" -O iconPath=\"/sdcard/Simplify/.branding/youtube/launcher/google_family\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          fi
        fi
      fi
      if su -c "id" >/dev/null 2>&1 && [ "${arraynames[$i]}" == "spotify_patches_args" ]; then
        echo "-d \"Spoof client\"" >> "$SimplUsr/${arraynames[$i]}.txt"
      fi
    fi
  done
  
  # Read Files into Arrays
  for (( i=0; i<${#arraynames[@]}; i++ )); do
    if [ -f "$SimplUsr/${arraynames[$i]}.txt" ]; then
      if [ -s "$SimplUsr/${arraynames[$i]}.txt" ]; then
        eval "${arraynames[$i]}=()"  # Clear target array
        mapfile -t lines < "$SimplUsr/${arraynames[$i]}.txt"  # Read file into lines array
        # Process each line
        for line in "${lines[@]}"; do
          [ -z "$line" ] && continue  # Skip empty lines
          eval "args=($line)"  # Use eval to properly split arguments while preserving quotes
          eval "${arraynames[$i]}+=(\"\${args[@]}\")"  # Add to target array
        done
      else
        eval "${arraynames[$i]}=()"
      fi
    fi
  done
  
fi

changeVersionCode() {
  versionCode="2147483647"  # Sets the maximum version code to prevent an update.
  input_apk_path=${1}
  filename_wo_ext="${input_apk_path%.*}"
  input_apk_packageName=$($HOME/aapt2 dump badging "$input_apk_path" 2>/dev/null | awk -F"'" '/package/ {print $2}')
  input_apk_versionCode=$($HOME/aapt2 dump badging "$input_apk_path" 2>/dev/null | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p")
  
  # Download apktool
  bash $Simplify/dlGitHub.sh "iBotPeaches" "Apktool" "latest" ".jar" "$RV"
  apktoolJar=$(find "$RV" -type f -name "apktool_*.jar" -print -quit)
  
  # Decoding
  echo -e "$running Decoding resources.."
  if [ "$input_apk_packageName" == "com.instagram.android" ] || [ "$input_apk_packageName" == "com.instagram.barcelona" ]; then
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $apktoolJar d -s -f "$input_apk_path" -o "${filename_wo_ext}_src"  # -s,--no-src = Skip src (no smali files), Java bytecode (.dex files) decompilation. It's improve significant decompilation speed | --no-assets = Skip decoding assets folder (apk data) - it's causes app crashes after aligning | -f,--force = force overwrite output directory (Auto deletes existing output dir) | Change versionCode failed: -r,--no-res --only-manifest
  fi
  if [ $? -eq 0 ]; then
    sleep 0.5  # wait 500 milliseconds
    # Wait for output dir (max 60 seconds)
    wait_time=0
    while [ ! -d "${filename_wo_ext}_src" ] && [ $wait_time -lt 60 ]; do
      sleep 1
      wait_time=$((wait_time + 1))
    done
    if [ ! -d "${filename_wo_ext}_src" ]; then
      echo "$notice Not found output resource directory after waiting 60 seconds!"
    else
      # Wait for apktool.yml file (max 30 seconds)
      wait_time=0
      while [ ! -f "${filename_wo_ext}_src/apktool.yml" ] && [ $wait_time -lt 30 ]; do
        sleep 1
        ((wait_time++))  # wait_time=wait_time+1
      done
      if [ -f "${filename_wo_ext}_src/apktool.yml" ]; then
        cat "${filename_wo_ext}_src/apktool.yml" | grep -E "versionCode"
      else
        echo "$notice Not found output resource files after waiting 30 seconds!"
      fi
    fi
  else
    rm -rf "${filename_wo_ext}_src"
  fi  
  
  # Overwrite versionCode
  if [ -d "${filename_wo_ext}_src" ]; then
    if [ -f "${filename_wo_ext}_src/apktool.yml" ]; then
      sed -i.bak "s/versionCode: [0-9]*/versionCode: $versionCode/" "${filename_wo_ext}_src/apktool.yml"
      #sed -i '' "s/versionCode: [0-9]*/versionCode: $versionCode/" "${filename_wo_ext}_src/apktool.yml"
      if grep -q "$versionCode" "${filename_wo_ext}_src/apktool.yml"; then
        echo -e "$info \"Change version code\" succeeded"
        cat "${filename_wo_ext}_src/apktool.yml" | grep -E "versionCode"
      fi
    fi
  fi
  
  # Building
  if [ -d "${filename_wo_ext}_src" ] && grep -q "$versionCode" "${filename_wo_ext}_src/apktool.yml"; then
    echo -e "$running Building modified resources.."
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $apktoolJar b --use-aapt1 "${filename_wo_ext}_src" -o "${filename_wo_ext}_src.apk"
    if [ $? -ne 0 ] || [ ! -f "${filename_wo_ext}_src.apk" ]; then
      rm -rf "${filename_wo_ext}_src"
    fi
  fi
  
  # Purge tmp dir
  if [ -f "${filename_wo_ext}_src.apk" ] && [ -d "${filename_wo_ext}_src" ]; then
    echo -e "$running Purging temporary resource files & directory.."
    rm -rf "${filename_wo_ext}_src"
  fi
  
  # Download zipalign binary for Android from GitHub/@rendiix/termux-zipalign
  <<comment
  arch=$(getprop ro.product.cpu.abi)  # Get Device arch
  if [ ! -f "$Simplify/zipalign" ]; then
    echo -e "$running Downloading zipalign binary for Android from ${Blue}https://github.com/rendiix/termux-zipalign/raw/refs/heads/main/prebuilt-binary/$arch/zipalign${Reset}.."
    curl -L --progress-bar -o $Simplify/zipalign https://github.com/rendiix/termux-zipalign/raw/refs/heads/main/prebuilt-binary/$arch/zipalign
    ls -l "$Simplify/zipalign"
    echo -e "$running Give excute (--x) permissions to zipalign binary.."
    chmod +x "$Simplify/zipalign"
    if ls -l "$Simplify/zipalign" | grep -q "-rwx------"; then
      echo -e "$good Successfully give exe (--x) permissions to zipalign"
      ls -l "$Simplify/zipalign"
    fi
  fi
comment
  if [ ! -f "$PREFIX/etc/apt/sources.list.d/rendiix.list" ]; then
    echo -e "$running Installing rendiix repo.."
    curl -s https://raw.githubusercontent.com/rendiix/rendiix.github.io/master/install-repo.sh | bash > /dev/null 2>&1
  fi
  if [ ! -f "$PREFIX/bin/zipalign" ]; then
    echo -e "$running Installing zipalign pkg.."
    pkg install zipalign -y > /dev/null 2>&1
  fi
  
  # Zip aligning APK
  if [ -f "${filename_wo_ext}_src.apk" ]; then
    echo -e "$running Aligning APK.."
    #~/Simplify/zipalign -f 4 "${filename_wo_ext}_src.apk" "${filename_wo_ext}_src_aligned.apk"  # -v = verbose - shows detailed progress info | -f = force - overwrites existing output file | -p = page-align - ensures proper alignment for .so files - it's causes app crashes
    $PREFIX/bin/zipalign -f 4 "${filename_wo_ext}_src.apk" "${filename_wo_ext}_src_aligned.apk"
  fi
  
  # Signing APK
  if [ -f "${filename_wo_ext}_src_aligned.apk" ]; then
    echo -e "$running Signing APK.."
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar sign --ks $Simplify/ks.keystore --ks-pass pass:123456 --ks-key-alias ReVancedKey --key-pass pass:123456 --out "${filename_wo_ext}_src_aligned_signed.apk" "${filename_wo_ext}_src_aligned.apk"
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -printcert -jarfile "${filename_wo_ext}_src_aligned_signed.apk" | grep -oP 'Owner: \K.*' 2>/dev/null
    if [ $? -ne 0 ]; then
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar verify --print-certs "${filename_wo_ext}_src_aligned_signed.apk" | grep -oP 'Signer #1 certificate DN: \K.*'
    fi
  fi
  
  # Rename
  if [ -f "${filename_wo_ext}_src_aligned_signed.apk" ]; then
    output_apk_versionCode=$($HOME/aapt2 dump badging "${filename_wo_ext}_src_aligned_signed.apk" 2>/dev/null | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p")
    rm -f "$input_apk_path"  # remove input file
    rm -f "${filename_wo_ext}_src.apk"  # rm modified output apk
    rm -f "${filename_wo_ext}_src_aligned.apk"  # rm zip aligning output apk
    rm -f "${filename_wo_ext}_src_aligned_signed.apk.idsig"  # rm apksigner generated .idsig file
    mv "${filename_wo_ext}_src_aligned_signed.apk" "$input_apk_path"  # rename file using move command
    echo -e "$good ${Green}Successfully Change versionCode: $input_apk_versionCode → $output_apk_versionCode${Reset}"
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

# --- function for common app installation prompt ---
commonPrompt() {
    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install ${appNameRef[0]} RV app?" "buttons" && opt=Yes || opt=No
    case $opt in
      y*|Y*|"")
        if [ $pkgName == "com.instagram.android" ] || [ $pkgName == "com.instagram.barcelona" ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Change ${appNameRef[0]} RV app versionCode?" "buttons" && opt=Yes || opt=No
          case $opt in
            y*|Y*|"")
              termux-wake-lock
              changeVersionCode "$outputAPK" | tee "$SimplUsr/${appNameRef[0]}-RV_changeVersionCode-log.txt"  # Change app versionCode by calling changeVersionCode method
              termux-wake-unlock
              if grep -q "OutOfMemory" "$SimplUsr/${appNameRef[0]}-RV_changeVersionCode-log.txt"; then
                echo -e "$bad ${Red}OutOfMemoryError${Reset}: ${Yellow}Device RAM overloaded!${Reset}\n ${Blue}Solutions${Reset}:\n   1. ${Yellow}Close background apps.${Reset}\n   2. ${Yellow}Use device with ≥4GB ~ ≥6GB RAM for patching apk.${Reset}"
              fi
              ;;
            n*|N*) echo -e "$notice ${Yellow}Warning! Disable auto updates for the patched app to avoid unexpected issues.${Reset}" ;;
          esac
        elif [ $pkgName == "com.facebook.katana" ] || [ $pkgName == "com.facebook.orca" ] || [ $pkgName == "com.zhiliaoapp.musically" ]; then
          echo -e "$notice ${Yellow}Warning! Disable auto updates for the patched app to avoid unexpected issues.${Reset}"
        fi
        echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RV apk.."
        bash $Simplify/apkInstall.sh "$outputAPK" "$activityPatched"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} RV Installaion skipped!" ;;
    esac
    
    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share ${appNameRef[0]} RV app?" "buttons" "1" && opt=Yes || opt=No
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Sharing Patched ${appNameRef[0]} RV apk.."
        termux-open --send "$outputAPK"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} RV Sharing skipped!"
        echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)" && sleep 3
        am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.google.android.documentsui/com.android.documentsui.files.FilesActivity &> /dev/null  # Open Android Files by Google
        if [ $? -ne 0 ] || [ $? -eq 2 ]; then
          am start -a android.intent.action.VIEW -d "content://com.android.externalstorage.documents/document/primary:Simplify" -t "vnd.android.document/directory" -n com.android.documentsui/com.android.documentsui.files.FilesActivity > /dev/null 2>&1  # Open Android Files
        fi
        ;;
    esac
}

# --- function to Build App ---
build_app() {
  # local variables
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
  local os_val=${10}
  local dpi_val=${11}
  local or_val=${12}
  
  
  if [ "$web" == "APKMirror" ]; then
    bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}" "$os_val" "$dpi_val" "$or_val"  # Download stock apk from APKMirror
  elif [ "$web" == "Uptodown" ]; then
    bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from Uptodown
  elif [ "$web" == "APKPure" ]; then
    bash $Simplify/dlAPKPure.sh "${appNameRef[0]}" "$pkgName" "$pkgVersion" "${archRef[0]}"  # Download stock apk from APKPure
  fi
  sleep 0.5  # Wait 500 milliseconds
  if [ "$Type" == "APK" ] || [ "${orRef[0]}" == "Download APK" ] || [ "$Type" == "apk" ]; then
    if [ "$pkgVersion" == "Any" ] || [ -z "$pkgVersion" ]; then
      fileNamePattern=("${appNameRef[0]}_v*-${archRef[0]}.apk")
      stock_apk_path=$(find "$Download" -type f -name "${fileNamePattern[0]}" -print -quit)
    elif [ -n "$pkgVersion" ] && [ "$pkgVersion" != "Any" ]; then
      stock_apk_path="$Download/${appNameRef[0]}_v${pkgVersion}-${archRef[0]}.apk"
      if [ ! -f "${stock_apk_path}" ]; then
        fileNamePattern=("${appNameRef[0]}_v${pkgVersion}*-${archRef[0]}.apk")  # for primeVideo, primeVideo version in APKMirror version page: 3.0.412 but primeVideo version in Variant list & dlPage: 3.0.412.2947. after primeVide downloaded complete it's match: 3.0.412* 
        stock_apk_path=$(find "$Download" -type f -name "${fileNamePattern[0]}" -print -quit)
      fi
    fi
  else
    if [ "$pkgVersion" == "Any" ] || [ -z "$pkgVersion" ]; then
      fileNamePattern=("${appNameRef[0]}_v*-$cpuAbi.apk")
      stock_apk_path=$(find "$Download" -type f -name "${fileNamePattern[0]}" -print -quit)
    elif [ -n "$pkgVersion" ] && [ "$pkgVersion" != "Any" ]; then
      stock_apk_path="$Download/${appNameRef[0]}_v${pkgVersion}-$cpuAbi.apk"
    fi
  fi
  
  local outputAPK="$SimplUsr/${appNameRef[0]}-RV_v${pkgVersion}-$cpuAbi.apk"
  local fileName=$(basename $outputAPK 2>/dev/null)
  
  if [ -f "${stock_apk_path}" ]; then
    echo -e "$good ${Green}Downloaded ${appName} APK found:${Reset} ${stock_apk_path}"
    termux-wake-lock
    patch_app "$stock_apk_path" "$appPatchesArgs" "$outputAPK" "${appName}"
    termux-wake-unlock
  fi
  
  if [ -f "$outputAPK" ]; then
    if [ "$pkgName" == "com.google.android.youtube" ] || [ "$pkgName" == "com.google.android.apps.photos" ] || [ "$pkgName" == "com.google.android.apps.recorder" ] || [ "$pkgName" == "com.spotify.music" ]; then
      if su -c "id" >/dev/null 2>&1; then
        
        if [ "$pkgName" == "com.google.android.youtube" ]; then
          buttons=("<Install>" "<Mount>" "<Cancel>")
          confirmPrompt "Select ${appNameRef[0]} RV installation operation" "buttons"
          exit_status=$?
          if [ $exit_status -eq 0 ]; then opt=Install; elif [ $exit_status -eq 1 ]; then opt=Mount; elif [ $exit_status -eq 2 ]; then opt=Cancel; fi
          case $opt in
            I*|i*|"")
              checkCoreLSPosed  # Call the check core patch functions
              echo -e "$running Copy signature from ${appNameRef[0]}.."
              termux-wake-lock
              cs "${stock_apk_path[0]}" "$outputAPK" "$SimplUsr/${appNameRef[0]}-RV-CS_v${pkgVersion}-${archRef[0]}.apk"
              termux-wake-unlock
              echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RV CS apk.."
              bash $Simplify/apkInstall.sh "$SimplUsr/${appNameRef[0]}-RV-CS_v${pkgVersion}-${archRef[0]}.apk" ""
              ;;
            M*|m*)
              echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RV apk.."
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" &> /dev/null
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" | tee "$SimplUsr/${appNameRef[0]}-RV_mount-log.txt"
              rm -f "$outputAPK"
              ;;
            C*|c*) echo -e "$notice ${appNameRef[0]} RV Installaion skipped!" ;;
          esac
        elif [ "$pkgName" == "com.google.android.apps.photos" ] || [ "$pkgName" == "com.google.android.apps.recorder" ] || [ "$pkgName" == "com.spotify.music" ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Mount ${appNameRef[0]} RV app?" "buttons" && opt=Yes || opt=No
          case $opt in
            y*|Y*|"")
              echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RV apk.."
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" &> /dev/null
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path}\" \"$outputAPK\"" | tee "$SimplUsr/${appNameRef[0]}-RV_mount-log.txt"
              rm -f "$outputAPK"
              ;;
            n*|N*) echo -e "$notice ${appNameRef[0]} RV Installaion skipped!" ;;
          esac
        fi
      
      else
        
        echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
        buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install VancedMicroG app?" "buttons" && opt=Yes || opt=No
        case $opt in
          y*|Y*|"")
            echo -e "$running Please Wait !! Installing VancedMicroG apk.."
            bash $Simplify/apkInstall.sh "$VancedMicroG" "com.mgoogle.android.gms/org.microg.gms.ui.SettingsActivity"
            ;;
          n*|N*) echo -e "$notice VancedMicroG Installaion skipped!" ;;
        esac
        commonPrompt
        
      fi
    
    else
      commonPrompt
    fi
  fi
}

# --- Function to retrieve the list of patches for a specific filtered app
getListOfPatches() {
  local pkgName="$1"
  curl -sL 'https://api.revanced.app/v4/patches/list' | jq --arg pkgName "$pkgName" '.[] | select(.compatiblePackages."'"$pkgName"'" != null)'
  if [ "$ReadPatchesFile" -eq 1 ]; then
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-patches -d=true -f=$pkgName -i=true -o=true -p=false -u -v=false $PatchesRvp > "$SimplUsr/${pkgName}_list-patches.txt"
  fi
  Patches=$(curl -sL 'https://api.revanced.app/v4/patches/list' | jq --arg pkgName "$pkgName" '.[] | select(.compatiblePackages."'"$pkgName"'" != null)')
  if [ "$pkgName" == "app.revanced" ]; then
    if [ "$ReadPatchesFile" -eq 1 ]; then
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-patches -d=true -f=$pkgName -i=true -o=true -p=false -u=true -v=false $PatchesRvp | tee "$SimplUsr/${pkgName}_list-patches.txt"
    else
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-patches -d=true -f=$pkgName -i=true -o=true -p=false -u=true -v=false $PatchesRvp  # get only universal-patches list
    fi
  elif [ -z "$Patches" ]; then
    # java -jar revanced-cli-*-all.jar list-patches patches-*.rvp -h
    # -d=--with-descriptions, -f=--filter-package-name, -i=--index, -o=--with-options, -p=--with-packages, -u=--with-universal-patches, -v, --with-versions
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-patches -d=true -f=$pkgName -i=true -o=true -p=false -u -v=false $PatchesRvp
  fi
}

# Req
<<comment
  YouTube 8.0+
  Spotify 7.0+
  TikTok 5.0+
  Google Photos 5.0+
  Google Recorder 10+
  Instagram arm64 + x64 9.0+
  Instagram arm32 + x86 7.0+
  Facebook arm64 + x64 9.0+
  Facebook arm32 + x86 8.0+
  Facebook Messenger arm64 + x64 9.0+
  Facebook Messenger arm32 + x86 5.0+
  Viber 5.0+
  Lightroom 8.0+
  Photomath 5.0+
  Duolingo 10+
  RAR 4.4+
  Amazon Prime Video 5.0
  Twitch 5.0
  Tumblr 7.0+
  Threads arm64 + x64 9.0+
  Threads arm32 + x86 8.0+
  Strava 8.0+
  SoundCloud 8.0+
  Proton Mail 9.0+
  MyFitnessPal 12+
  Crunchyroll 8.0+
  Cricbuzz 5.0+
comment

# --- Decisions block for app that required specific arch & android version ---
if su -c "id" >/dev/null 2>&1 && [ "$cpuAbi" == "arm64-v8a" ]; then
  googleRecorder="GoogleRecorder"
fi
if  [[ $Android -ge 9  &&  ( "$cpuAbi" == "arm64-v8a" || "$cpuAbi" == "x86_64" ) ]]; then
  Instagram="Instagram"
  #Facebook="Facebook"
  fbMessenger="FacebookMessenger"
  Threads="Threads"
fi
if [[ $Android -ge 8  &&  ( "$cpuAbi" == "armeabi-v7a" || "$cpuAbi" == "x86" ) ]]; then
  #Facebook="Facebook"
  Threads="Threads"
fi
if [[ $Android -ge 7  &&  ( "$cpuAbi" == "armeabi-v7a" || "$cpuAbi" == "x86" ) ]]; then
  Instagram="Instagram"
fi
if [[ $Android -ge 5  &&  ( "$cpuAbi" == "armeabi-v7a" || "$cpuAbi" == "x86" ) ]]; then
  fbMessenger="FacebookMessenger"
fi
if [ $cpuAbi == "arm64-v8a" ] || [ $cpuAbi == "armeabi-v7a" ]; then
  amazonPrimeVideo="AmazonPrimeVideo"
fi
if  [[ $Android -ge 11  &&  ( "$cpuAbi" == "arm64-v8a" || "$cpuAbi" == "armeabi-v7a" ) ]]; then
  Facebook="Facebook"
fi
if su -c "id" >/dev/null 2>&1; then
  Spotify="Spotify"
fi

options=(CHANGELOG Spoof\ Device\ Arch List\ of\ Patches)

# --- Arrays of apps list that required specific android version ---
if [ $Android -ge 12 ]; then
  apps=(
    YouTube
    $Spotify
    TikTok
    GooglePhotos
    $googleRecorder
    $Instagram
    $Facebook
    ${fbMessenger}
    Viber
    Lightroom
    Photomath
    Duolingo
    RAR
    ${amazonPrimeVideo}
    Twitch
    Tumblr
    $Threads
    Strava
    SoundCloud
    ProtonMail
    MyFitnessPal
    Crunchyroll
    Cricbuzz
  )
elif [ $Android -eq 11 ]; then
  apps=(
    YouTube
    $Spotify
    TikTok
    GooglePhotos
    $googleRecorder
    $Instagram
    $Facebook
    ${fbMessenger}
    Viber
    Lightroom
    Photomath
    Duolingo
    RAR
    ${amazonPrimeVideo}
    Twitch
    Tumblr
    $Threads
    Strava
    SoundCloud
    ProtonMail
    Crunchyroll
    Cricbuzz
  )
elif [ $Android -eq 10 ]; then
  apps=(
    YouTube
    $Spotify
    TikTok
    GooglePhotos
    $googleRecorder
    $Instagram
    $Facebook
    ${fbMessenger}
    Viber
    Lightroom
    Photomath
    Duolingo
    RAR
    ${amazonPrimeVideo}
    Twitch
    Tumblr
    $Threads
    Strava
    SoundCloud
    ProtonMail
    Crunchyroll
    Cricbuzz
  )
elif [ $Android -eq 9 ]; then
  apps=(
    YouTube
    $Spotify
    TikTok
    GooglePhotos
    $Instagram
    $Facebook
    ${fbMessenger}
    Viber
    Lightroom
    Photomath
    RAR
    ${amazonPrimeVideo}
    Twitch
    Tumblr
    $Threads
    Strava
    SoundCloud
    ProtonMail
    Crunchyroll
    Cricbuzz
  )
elif [ $Android -eq 8 ]; then
  apps=(
    YouTube
    $Spotify
    TikTok
    GooglePhotos
    $Instagram
    $Facebook
    ${fbMessenger}
    Viber
    Lightroom
    Photomath
    RAR
    ${amazonPrimeVideo}
    Twitch
    Tumblr
    $Threads
    Strava
    SoundCloud
    Crunchyroll
    Cricbuzz
  )
elif [ $Android -eq 7 ]; then
  apps=(
    $Spotify
    TikTok
    GooglePhotos
    $Instagram
    ${fbMessenger}
    Viber
    Photomath
    RAR
    ${amazonPrimeVideo}
    Twitch
    Tumblr
    Cricbuzz
  )
elif [ $Android -eq 6 ]; then
  apps=(
    TikTok
    GooglePhotos
    ${fbMessenger}
    Viber
    Photomath
    RAR
    ${amazonPrimeVideo}
    Twitch
    Cricbuzz
  )
elif [ $Android -eq 5 ]; then
  apps=(
    TikTok
    GooglePhotos
    ${fbMessenger}
    Viber
    Photomath
    RAR
    ${amazonPrimeVideo}
    Twitch
    Cricbuzz
  )
elif [ $Android -eq 4 ]; then
  apps=(RAR)
fi

options+=(${apps[@]})

menu() {
  local -n menu_options=$1
  local -n menu_buttons=$2
  items_per_page=${3:-12}  # Default to 12 if items/page not provided
  
  selected_option=0
  selected_button=0
  
  current_page=0
  total_pages=$(( (${#menu_options[@]} + items_per_page - 1) / items_per_page ))  # Convert to integer from floating point page number

  show_menu() {
    printf '\033[2J\033[3J\033[H'
    # Display guide
    echo -n "Navigate with [↑] [↓] [←] [→]"
    [ $total_pages -gt 1 ] && echo -n " [PGUP] [PGDN]"
    echo -e "\nSelect with [↵]\n"
    
    # Calculate start and end indices for current page
    start_index=$(( current_page * items_per_page ))
    end_index=$(( start_index + (items_per_page - 1) ))
    [ $end_index -ge ${#menu_options[@]} ] && end_index=$((${#menu_options[@]} - 1))
    
    # Display menu options for current page
    for ((i=start_index; i<=end_index; i++)); do
      if [ $i -eq $selected_option ]; then
        echo -e "${whiteBG}➤ ${menu_options[$i]} $Reset"
      else
        [ $(($i + 1)) -le 9 ] && echo " $(($i + 1)). ${menu_options[$i]}" || echo "$(($i + 1)). ${menu_options[$i]}"
      fi
    done
    
    for ((i=end_index+1; i < start_index + items_per_page; i++)); do echo; done  # Fill remaining lines if current page has fewer than items/page options
    
    [ $total_pages -gt 1 ] && echo -e "\nPage: $((current_page + 1))/$total_pages\n" || echo  # Display page info if multiple pages exist
    
    # Display buttons
    for ((i=0; i<=$((${#menu_buttons[@]} - 1)); i++)); do
      if [ $i -eq $selected_button ]; then
        [ $i -eq 0 ] && echo -ne "${whiteBG}➤ ${menu_buttons[$i]} $Reset" || echo -ne "  ${whiteBG}➤ ${menu_buttons[$i]} $Reset"
      else
        [ $i -eq 0 ] && echo -n "  ${menu_buttons[$i]}" || echo -n "   ${menu_buttons[$i]}"
      fi
    done
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
            current_page=$((selected_option / items_per_page))  # Auto switch page
            ;;
          '[B')  # Down arrow
            selected_option=$((selected_option + 1))
            [ $selected_option -ge ${#menu_options[@]} ] && selected_option=0
            current_page=$((selected_option / items_per_page))  # Auto switch page
            ;;
          '[C')  # Right arrow
            [ $selected_button -lt $((${#menu_buttons[@]} - 1)) ] && selected_button=$((selected_button + 1))
            ;;
          '[D')  # Left arrow
            [ $selected_button -gt 0 ] && selected_button=$((selected_button - 1))
            ;;
          '[5') # Page Up
            read -rsn1 -t 0.1 key3
            if [ "$key3" == "~" ]; then
              current_page=$((current_page - 1))
              [ $current_page -lt 0 ] && current_page=$((total_pages - 1))
              selected_option=$((current_page * items_per_page))  # Update selected option to start indices on new page
            fi
            ;;
          '[6') # Page Down
            read -rsn1 -t 0.1 key3
            if [ "$key3" == "~" ]; then
              current_page=$((current_page + 1))
              [ $current_page -ge $total_pages ] && current_page=0
              selected_option=$((current_page * items_per_page))  # Update selected option to start indices on new page
            fi
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
          selected_option=$((${#menu_options[@]} - 1))
        elif [ $key -gt ${#menu_options[@]} ]; then
          selected_option=0
        else
          selected_option=$(($key - 1))
        fi
        current_page=$((selected_option / items_per_page))  # Auto switch page
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
  buttons=("<Select>" "<Back>"); if menu "options" "buttons" "22"; then selected="${options[$selected]}"; else break; fi
  
  # main conditional control flow
  case "$selected" in
    CHANGELOG)
      [ $release == "latest" ] && tag=$(curl -sL ${auth} "https://api.github.com/repos/ReVanced/revanced-patches/releases/latest" | jq -r '.tag_name') || tag=$(curl -sL ${auth} "https://api.github.com/repos/ReVanced/revanced-patches/releases" | jq -r '.[].tag_name | select(contains("dev"))' | head -n 1)
      curl -sL ${auth} "https://api.github.com/repos/ReVanced/revanced-patches/releases/tags/$tag" | jq -r .body | glow  # Display release notes
      ;;
    Spoof\ Device\ Arch)
      if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
        cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
        echo -e "$info Device architecture spoofed to $cpuAbi!"
      else
        echo -e "$info Device architecture not spoofed yet!"
      fi
      options=(Disabled\ Arch\ spoofing arm64-v8a armeabi-v7a x86_64 x86); buttons=("<Select>" "<Back>"); if menu "options" "buttons"; then arch="${options[$selected]}"; fi
      if [ -n "$arch" ]; then
        case "$arch" in
          Disabled\ Arch\ spoofing)
            echo -e "$running Disabling device architecture spoofing.."
            jq -e 'del(.DeviceArch)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete DeviceArch key from simplify.json
            echo -e "$good ${Green}Device architecture spoofing disabled successfully!${Reset}"
            ;;
          arm64-v8a)
            echo -e "$running Spoofing device architecture to arm64-v8a.."
            jq ".DeviceArch = \"arm64-v8a\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
            echo -e "$good ${Green}Device architecture spoofed to arm64-v8a successfully!${Reset}"
            ;;
          armeabi-v7a)
            echo -e "$running Spoofing device architecture to armeabi-v7a.."
            jq ".DeviceArch = \"armeabi-v7a\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
            echo -e "$good ${Green}Device architecture spoofed to armeabi-v7a successfully!${Reset}"
            ;;
          x86_64)
            echo -e "$running Spoofing device architecture to x86_64.."
            jq ".DeviceArch = \"x86_64\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
            echo -e "$good ${Green}Device architecture spoofed to x86_64 successfully!${Reset}"
            ;;
          x86)
            echo -e "$running Spoofing device architecture to x86.."
            jq ".DeviceArch = \"x86\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
            echo -e "$good ${Green}Device architecture spoofed to x86 successfully!${Reset}"
            ;;
        esac
        # update cpuAbi value
        jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1 && cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
      fi
      ;;
    List\ of\ Patches)
      apps_list=(universal-patches)
      apps_list+=("${apps[@]}")
      
      buttons=("<Select>" "<Back>"); if menu "apps_list" "buttons" "22"; then selected="${apps_list[$selected]}"; fi
      if [ -n "$selected" ]; then
        case "$selected" in
          universal-patches)
            pkgName="app.revanced"
            getListOfPatches "$pkgName"
            ;;
          YouTube)
            pkgName="com.google.android.youtube"
            getListOfPatches "$pkgName"
            ;;
          Spotify)
            pkgName="com.spotify.music"
            getListOfPatches "$pkgName"
            ;;
          TikTok)
            pkgName="com.zhiliaoapp.musically"
            getListOfPatches "$pkgName"
            ;;
          GooglePhotos)
            pkgName="com.google.android.apps.photos"
            getListOfPatches "$pkgName"
            ;;
          GoogleRecorder)
            pkgName="com.google.android.apps.recorder"
            getListOfPatches "$pkgName"
            ;;
          Instagram)
            pkgName="com.instagram.android"
            getListOfPatches "$pkgName"
            ;;
          Facebook)
            pkgName="com.facebook.katana"
            getListOfPatches "$pkgName"
            ;;
          FacebookMessenger)
            pkgName="com.facebook.orca"
            getListOfPatches "$pkgName"
            ;;
          Threads)
            pkgName="com.instagram.barcelona"
            getListOfPatches "$pkgName"
            ;;
          Viber)
            pkgName="com.viber.voip"
            getListOfPatches "$pkgName"
            ;;
          Lightroom)
            pkgName="com.adobe.lrmobile"
            getListOfPatches "$pkgName"
            ;;
          Photomath)
            pkgName="com.microblink.photomath"
            getListOfPatches "$pkgName"
            ;;
          Duolingo)
            pkgName="com.duolingo"
            getListOfPatches "$pkgName"
            ;;
          RAR)
            pkgName="com.rarlab.rar"
            getListOfPatches "$pkgName"
            ;;
          AmazonPrimeVideo)
            pkgName="com.amazon.avod.thirdpartyclient"
            getListOfPatches "$pkgName"
            ;;
          Twitch)
            pkgName="tv.twitch.android.app"
            getListOfPatches "$pkgName"
            ;;
          Tumblr)
            pkgName="com.tumblr"
            getListOfPatches "$pkgName"
            ;;
          Strava)
            pkgName="com.strava"
            getListOfPatches "$pkgName"
            ;;
          SoundCloud)
            pkgName="com.soundcloud.android"
            getListOfPatches "$pkgName"
            ;;
          ProtonMail)
            pkgName="ch.protonmail.android"
            getListOfPatches "$pkgName"
            ;;
          MyFitnessPal)
            pkgName="com.myfitnesspal.android"
            getListOfPatches "$pkgName"
            ;;
          Crunchyroll)
            pkgName="com.crunchyroll.crunchyroid"
            getListOfPatches "$pkgName"
            ;;
          Cricbuzz)
            pkgName="com.cricbuzz.android"
            getListOfPatches "$pkgName"
            ;;
        esac
        sleep 10  # wait 10 seconds
      fi
      ;;
    YouTube)
      pkgName="com.google.android.youtube"
      appName=("YouTube")
      #pkgVersion="20.13.41"
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      if su -c "id" >/dev/null 2>&1; then
        Type="APK"
      else
        Type="BUNDLE"
      fi
      Arch=("universal")
      pkgPatched="app.revanced.android.youtube"
      activityPatched="com.google.android.youtube/.app.honeycomb.Shell\$HomeActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "yt_patches_args" "$pkgPatched" "$activityPatched" "" "" ""
      ;;
    Spotify)
      pkgName="com.spotify.music"
      appName=("Spotify")
      pkgVersion="9.0.84.1338"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="apk"
      Arch=("armeabi-v7a, x86, arm64-v8a, x86_64")
      activityPatched="com.spotify.music/.MainActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "Uptodown" "spotify_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    TikTok)
      pkgName="com.zhiliaoapp.musically"
      appName=("TikTok")
      #pkgVersion="36.5.4"
      pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      #web=APKMirror
      web="Uptodown"
      if [ "$web" == "APKMirror" ]; then
        Type="APK"
        Arch=("arm64-v8a + armeabi-v7a")
      else
        Type="apk"
        Arch=("arm64-v8a, armeabi-v7a")
      fi
      activityPatched="com.zhiliaoapp.musically/com.ss.android.ugc.aweme.splash.SplashActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "$web" "tiktok_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    GooglePhotos)
      pkgName="com.google.android.apps.photos"
      appName=("Google Photos")
      if [ $Android -ge 6 ]; then
        pkgVersion="6.95.0.663027175"
        #pkgVersion=""
        if [ -z "$pkgVersion" ]; then
          getVersion "$pkgName"
          pkgVersion="$pkgVersion"
        fi
      elif [ $Android -eq 5 ]; then
        pkgVersion="5.78.0.430249291"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      pkgPatched="app.revanced.android.apps.photos"
      activityPatched="com.google.android.apps.photos/.home.HomeActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "photos_patches_args" "$pkgPatched" "$activityPatched" "" "" ""
      ;;
    GoogleRecorder)
      pkgName="com.google.android.apps.recorder"
      appName=("Google Recorder")
      pkgVersion="4.2.20230801.561280372"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "recorder_patches_args" "$pkgName" "" "" "" ""
      ;;
    Instagram)
      pkgName="com.instagram.android"
      appName=("Instagram")
      pkgVersion="397.1.0.52.81"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      if [ $cpuAbi == x86_64 ] || [ $cpuAbi == x86 ]; then
        web="APKMirror"
      else
        web="APKPure"
      fi
      if [ $web == "APKMirror" ]; then
        Type="BUNDLE"
        Arch=("$cpuAbi")
      else
        if [ $cpuAbi == arm64-v8a ]; then
          Arch=("380306835")
        elif [ $cpuAbi == armeabi-v7a ]; then
          Arch=("380306859")
        fi
        Type="APK"
      fi
      activityPatched="com.instagram.android/.activity.MainTabActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "$web" "instagram_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Facebook)
      pkgName="com.facebook.katana"
      appName=("Facebook")
      pkgVersion="490.0.0.63.82"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      #web="APKMirror"
      web="APKPure"
      if [ $web == "APKMirror" ]; then
        Arch=("$cpuAbi")
        if [ $cpuAbi == arm64-v8a ] && [ $Android -ge 11 ]; then
          Type="APK"
        elif [ $cpuAbi == armeabi-v7a ] && [ $Android -ge 11 ]; then
          Type="BUNDLE"
        fi
        Os=("Android 11+")
        Dpi="nodpi"
        Or=("Download APK")
      else
        if [ $cpuAbi == arm64-v8a ] && [ $Android -ge 11 ]; then Arch=("457020014"); elif [ $cpuAbi == armeabi-v7a ] && [ $Android -ge 11 ]; then Arch=("457020009"); fi
        Type="APK"; Os=(); Dpi=""; Or=()
      fi
      activityPatched="com.facebook.katana/.LoginActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "$web" "facebook_patches_args" "$pkgName" "$activityPatched" "${Os[0]}" "$Dpi" "${Or[0]}"
      ;;
    FacebookMessenger)
      pkgName="com.facebook.orca"
      appName=("Facebook Messenger")
      pkgVersion="518.0.0.53.109"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      if [ "$cpuAbi" == "x86_64" ]; then
        web="APKMirror"
      else
        web="APKPure"
      fi
      if [ $web == "APKMirror" ]; then
        if [ "$cpuAbi" == "x86_64" ]; then
          Type="BUNDLE"  # for x64, APK Type variant not available, only BUNDLE Type exist in variant page
        else
          Type="APK"
        fi
        Arch=("$cpuAbi")
      else
        if [ $cpuAbi == arm64-v8a ]; then
          Arch=("333817144")
        elif [ $cpuAbi == armeabi-v7a ]; then
          Arch=("333817140")
        elif [ $cpuAbi == x86 ]; then
          Arch=("333615840")
        fi
        Type="APK"
      fi
      activityPatched="com.facebook.orca/.auth.StartScreenActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "$web" "fb_messenger_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Viber)
      pkgName="com.viber.voip"
      appName="Rakuten Viber Messenger"
      pkgVersion="26.1.2.0"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch=("universal")
      activityPatched="com.viber.voip/.WelcomeActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "viber_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Lightroom)
      pkgName="com.adobe.lrmobile"
      appName=("Adobe Lightroom Mobile")
      pkgVersion="9.2.0"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="apk"
      Arch=("arm64-v8a, x86_64")
      activityPatched="com.adobe.lrmobile/.StorageCheckActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "Uptodown" "lightroom_patches_args" "$pkgName" "$activityPatched" "" "" ""  # F*** Cloudflare DDoS Protection on APKMirror Lightroom Page
      ;;
    Photomath)
      pkgName="com.microblink.photomath"
      appName=("Photomath")
      pkgVersion="8.43.0"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch=("universal")
      activityPatched="com.microblink.photomath/.main.activity.LauncherActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "photomath_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Duolingo)
      pkgName="com.duolingo"
      appName=("Duolingo")
      pkgVersion="6.47.6"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch=("universal")
      activityPatched="com.duolingo/.app.LoginActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "duolingo_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    RAR)
      pkgName="com.rarlab.rar"
      appName=("RAR")
      pkgVersion="7.01.build123"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      activityPatched="com.rarlab.rar/.MainActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "rar_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    AmazonPrimeVideo)
      pkgName="com.amazon.avod.thirdpartyclient"
      #web="APKMirror"
      web="Uptodown"
      if [ "$web" == "APKMirror" ]; then
        appName=("Amazon Prime Video")
        pkgVersion="3.0.412"
        Type="APK"
      else
        appName=("Amazon Video")
        if [ "$cpuAbi" == "arm64-v8a" ]; then
          pkgVersion="3.0.412.2947"
        elif [ "$cpuAbi" == "armeabi-v7a" ]; then
          pkgVersion="3.0.412.2945"
        fi
        Type="apk"
      fi
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Arch=("$cpuAbi")
      activityPatched="com.amazon.avod.thirdpartyclient/.LauncherActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "$web" "prime_video_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Twitch)
      pkgName="tv.twitch.android.app"
      appName=("Twitch")
      pkgVersion="25.3.0"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch=("universal")
      activityPatched="tv.twitch.android.app/.core.LandingActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "twitch_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Tumblr)
      pkgName="com.tumblr"
      appName=("Tumblr - Social Fandom Art")
      pkgVersion="33.8.0.110"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch=("universal")
      activityPatched="com.tumblr/.ui.activity.JumpoffActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "tumblr_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Threads)
      pkgName="com.instagram.barcelona"
      appName=("Threads")
      pkgVersion="382.0.0.51.85"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      #web="APKMirror"
      web="APKPure"
      if [ $web == "APKMirror" ]; then
        Type="BUNDLE"
        Arch=("$cpuAbi")
      else
        if [ $cpuAbi == arm64-v8a ]; then
          Arch=("505205644")
        elif [ $cpuAbi == armeabi-v7a ]; then
          Arch=("505205643")
        elif [ $cpuAbi == x86_64 ]; then
          Arch=("505205646")
        else
          Arch=("505205645")
        fi
        Type="APK"
      fi
      activityPatched="com.instagram.barcelona/.mainactivity.BarcelonaActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "$web" "threads_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Strava)
      pkgName="com.strava"
      appName=("Strava")
      pkgVersion="418.11"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="xapk"
      Arch=("arm64-v8a, armeabi-v7a, x86, x86_64")
      activityPatched="com.strava/.SplashActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "Uptodown" "strava_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    SoundCloud)
      pkgName="com.soundcloud.android"
      appName=("SoundCloud")
      #pkgVersion="2025.05.27-release"
      pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      #web="APKMirror"
      web="Uptodown"
      if [ "$web" == "APKMirror" ]; then
        Type="BUNDLE"
        Arch=("universal")
      else
        Type="xapk"
        Arch=("arm64-v8a, armeabi-v7a, x86_64")
      fi
      activityPatched="com.soundcloud.android/.launcher.LauncherActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "$web" "soundcloud_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    ProtonMail)
      pkgName="ch.protonmail.android"
      appName=("ProtonMail")
      pkgVersion="4.15.0"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      #web="APKMirror"
      web="Uptodown"
      if [ "$web" == "APKMirror" ]; then
        Type="APK"
        Arch=("universal")
      else
        Type="apk"
        Arch=("armeabi-v7a, x86, arm64-v8a, x86_64")
      fi
      activityPatched="ch.protonmail.android/.MainActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "$web" "protonmail_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    MyFitnessPal)
      pkgName="com.myfitnesspal.android"
      appName=("Calorie Counter MyFitnessPal")
      #pkgVersion="24.14.2"
      pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="apk"
      Arch=("armeabi-v7a, x86, arm64-v8a, x86_64")
      activityPatched="com.myfitnesspal.android/.splash.SplashActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "Uptodown" "myfitnesspal_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Crunchyroll)
      pkgName="com.crunchyroll.crunchyroid"
      appName=("Crunchyroll")
      pkgVersion="3.85.2"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="xapk"
      Arch=("arm64-v8a, armeabi-v7a, x86, x86_64")
      activityPatched="com.crunchyroll.crunchyroid/com.ellation.crunchyroll.presentation.startup.StartupActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "Uptodown" "crunchyroll_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Cricbuzz)
      pkgName="com.cricbuzz.android"
      appName=("Cricbuzz Cricket Scores and News")
      #pkgVersion="6.24.01"
      pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="xapk"
      Arch=("arm64-v8a, armeabi-v7a, x86_64")
      activityPatched="com.cricbuzz.android/.lithium.app.view.activity.NyitoActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "Uptodown" "cricbuzz_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
  esac
  sleep 5  # wait 5 seconds
done
###########################################################################################################################################
