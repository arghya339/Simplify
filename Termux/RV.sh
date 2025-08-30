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
Serial=$(su -c 'getprop ro.serialno')  # Get Serial Number required root
Model=$(getprop ro.product.model)  # Get Device Model
jdkVersion="21"
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

bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

if [ "$FetchPreRelease" -eq 0 ]; then
  release="latest"  # Use latest release
else
  release="pre"  # Use pre-release
fi
bash $Simplify/dlGitHub.sh "ReVanced" "revanced-patches" "$release" ".rvp" "$RV"
PatchesRvp=$(find "$RV" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

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

if [ "$RipLib" -eq 1 ]; then
  # --- Architecture Detection ---
  all_arch="arm64-v8a armeabi-v7a x86_64 x86"  # Space-separated list instead of array
  # Generate ripLib arguments for all ABIs EXCEPT the detected one
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

# Get compatiblePackages version from json
getVersion() {
  local pkgName="$1"
  
  preVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | tail -n 1)
  pre_stock_apk_path=$(find "$Download" -type f -name "${appName[0]}_v${preVersion}-*.apk" -print -quit)
  [[ -f "$pre_stock_apk_path" ]] && rm "$pre_stock_apk_path"  # Remove previous stock apk if exists
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-versions $PatchesRvp -f=$pkgName | sed 's/^[[:space:]]*//; s/ (.*//;' | grep -E '^[0-9]|^Any$' | sort -rV | head -n 2 | head -n 1)
}

#  --- Patch Apps ---
patch_app() {
  local -n stock_apk_ref=$1
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
    -o "$outputAPK" "${stock_apk_ref[0]}" \
    "${patches[@]}" \
    "${universalPatches[@]}" \
    --custom-aapt2-binary="$HOME/aapt2" \
    --purge -f | tee "$log"
  else
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
      -o "$outputAPK" "${stock_apk_ref[0]}" \
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

spotify_patches_args=(
  -e "Change lyrics provider"
  -e "Custom theme"
  
  -d "Hide Create button"
)

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
    
    # [4] Instagram, [5] Facebook, [6] FbMessenger, [7] Lightroom, [8] Photomath, [9] Duolingo, [10] RAR | No default patches
    '' '' '' '' '' '' ''
    
    # [11] PrimeVideo
    '-e "Rename shared permissions"'
    
    # [12] Twitch | No default patches
    ''
    
    # [13] Tumblr
    '-e "Fix old versions"'
    
    # [14] Threads, [15] Strava, [16] SoundCloud, [17] ProtonMail, [18] MyFitnessPal, [19] Crunchyroll, [20] Cricbuzz | No default patches
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

commonPrompt() {
    echo -e "[?] ${Yellow}Do you want to install ${appNameRef[0]} RV app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        if [ $pkgName == "com.instagram.android" ] || [ $pkgName == "com.facebook.katana" ] || [ $pkgName == "com.facebook.orca" ] || [ $pkgName == "com.instagram.barcelona" ] || [ $pkgName == "com.zhiliaoapp.musically" ]; then
          echo -e "$notice ${Yellow}Warning! Disable auto updates for the patched app to avoid unexpected issues.${Reset}"
        fi
        echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RV apk.."
        bash $Simplify/apkInstall.sh "$outputAPK" "$pkgPatched" "$activityPatched"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} RV Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! ${appNameRef[0]} RV Installaion skipped." ;;
    esac
    
    echo -e "[?] ${Yellow}Do you want to Share ${appNameRef[0]} RV app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Sharing Patched ${appNameRef[0]} RV apk.."
        termux-open --send "$outputAPK"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} RV Sharing skipped!"
        echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)" && sleep 3
        am start -n "com.google.android.documentsui/com.android.documentsui.files.FilesActivity" > /dev/null 2>&1  # Open Android Files by Google
        if [ $? -ne 0 ] || [ $? -eq 2 ]; then
          am start -n "com.android.documentsui/com.android.documentsui.files.FilesActivity" > /dev/null 2>&1  # Open Android Files
        fi
        ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} RV Sharing skipped." ;;
    esac
}

# --- Build App ---
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
    sleep 0.5  # Wait 500 milliseconds
    if [ "$Type" == "BUNDLE" ] || [ "${orRef[0]}" == "Download APK Bundle" ]; then
      if [ -n "$pkgVersion" ] && [ "$pkgVersion" != "null" ]; then
        local stock_apk_path=("$Download/${appNameRef[0]}_v${pkgVersion}-$cpuAbi.apk")
      elif [ -z "$pkgVersion" ] || [ "$pkgVersion" == "null" ]; then
        fileNamePattern="${appNameRef[0]}_v*-$cpuAbi.apk"
        local stock_apk_path=$(find "$Download" -type f -name "${fileNamePattern}" -print -quit)  # -quit= find stops after first match
        local stock_apk_path=("$stock_apk_path")  # convert into arrays
      fi
    elif [ "$Type" == "APK" ] || [ "${orRef[0]}" == "Download APK" ]; then
      if [ -n "$pkgVersion" ] && [ "$pkgVersion" != "null" ]; then
        local stock_apk_path=("$Download/${appNameRef[0]}_v${pkgVersion}-${archRef[0]}.apk")
        sleep 0.5  # Wait 500 milliseconds
        if [ ! -f "${stock_apk_path[0]}" ]; then
          fileNamePattern="${appNameRef[0]}_v${pkgVersion}*-${archRef[0]}.apk"  # for primeVideo, primeVideo version in APKMirror version page: 3.0.412 but primeVideo version in Variant list & dlPage: 3.0.412.2947. after primeVide downloaded complete it's match: 3.0.412* 
          local stock_apk_path=$(find "$Download" -type f -name "${fileNamePattern}" -print -quit)
          local stock_apk_path=("$stock_apk_path")  # convert into arrays
        fi
      elif [ -z "$pkgVersion" ] || [ "$pkgVersion" == "null" ]; then
        fileNamePattern="${appNameRef[0]}_v*-${archRef[0]}.apk"
        local stock_apk_path=$(find "$Download" -type f -name "${fileNamePattern}" -print -quit)
        local stock_apk_path=("$stock_apk_path")  # convert into arrays
      fi
    fi
    
  elif [ "$web" == "Uptodown" ]; then
    
    bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from Uptodown
    
    if [ "$Type" == "xapk" ]; then
      local stock_apk_path=("$Download/${appNameRef[0]}_v${pkgVersion}-$cpuAbi.apk")
    elif [ "$Type" == "apk" ]; then
      local stock_apk_path=("$Download/${appNameRef[0]}_v${pkgVersion}-${archRef[0]}.apk")
    fi
    
  fi
  
  local outputAPK="$SimplUsr/${appNameRef[0]}-RV_v${pkgVersion}-$cpuAbi.apk"
  local fileName=$(basename $outputAPK 2>/dev/null)
  sleep 0.5  # Wait 500 milliseconds
  second=1
  while true; do
    if [ -f "${stock_apk_path[0]}" ]; then
      break
    fi
    if [ $second -ge 30 ]; then
      echo -e "$notice Oops, ${appNameRef[0]} APK not found in $Download dir after waiting 30 seconds!"
      break
    fi
    second=$((second + 1))
    sleep 1  # Wait 1 seconds
  done
  if [ -f "${stock_apk_path[0]}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_path[0]}"
    patch_app "stock_apk_path" "$appPatchesArgs" "$outputAPK" "${appNameRef[0]}"
  fi
  
  if [ -f "$outputAPK" ]; then
    if [ "$pkgName" == "com.google.android.youtube" ] || [ "$pkgName" == "com.google.android.apps.photos" ] || [ "$pkgName" == "com.google.android.apps.recorder" ]; then
      if su -c "id" >/dev/null 2>&1; then
        
        if [ "$pkgName" == "com.google.android.youtube" ]; then
          echo -e "[?] ${Yellow}Please select installation type - 'M' for Mount or 'I' for SU-Install or 'N' for Installation cancel. [M/i/N]: ${Reset}\c" && read opt
          case $opt in
            I*|i*|"")
              checkCoreLSPosed  # Call the check core patch functions
              echo -e "$running Copy signature from ${appNameRef[0]}.."
              cs "${stock_apk_path[0]}" "$outputAPK" "$SimplUsr/${appNameRef[0]}-RV-CS_v${pkgVersion}-${archRef[0]}.apk"
              echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RV CS apk.."
              bash $Simplify/apkInstall.sh "$SimplUsr/${appNameRef[0]}-RV-CS_v${pkgVersion}-${archRef[0]}.apk" "$pkgName" ""
              ;;
            M*|m*)
              echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RV apk.."
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" &> /dev/null
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" | tee "$SimplUsr/${appNameRef[0]}-RV_mount-log.txt"
              rm $outputAPK
              ;;
            N*|n*) echo -e "$notice ${appNameRef[0]} RV Installaion skipped!" ;;
            *) echo -e "$info Invalid choice! ${appNameRef[0]} RV Installaion skipped." ;;
          esac
        elif [ "$pkgName" == "com.google.android.apps.photos" ] || [ "$pkgName" == "com.google.android.apps.recorder" ]; then
          echo -e "[?] ${Yellow}Do you want to Mount ${appNameRef[0]} RV app? [Y/n] ${Reset}\c" && read opt
          case $opt in
            y*|Y*|"")
              echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RV apk.."
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" &> /dev/null
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_path[0]}\" $outputAPK \"${appNameRef[0]}\" $pkgName $pkgVersion" | tee "$SimplUsr/${appNameRef[0]}-RV_mount-log.txt"
              rm $outputAPK
              ;;
            n*|N*) echo -e "$notice ${appNameRef[0]} RV Installaion skipped!" ;;
            *) echo -e "$info Invalid choice! ${appNameRef[0]} RV Installaion skipped." ;;
          esac
        fi
      
      else
        
        echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
        echo -e "[?] ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset} \c" && read opt
        case $opt in
          y*|Y*|"")
            echo -e "$running Please Wait !! Installing VancedMicroG apk.."
            bash $Simplify/apkInstall.sh "$VancedMicroG" "com.mgoogle.android.gms" "com.mgoogle.android.gms/org.microg.gms.ui.SettingsActivity"
            ;;
          n*|N*) echo -e "$notice VancedMicroG Installaion skipped!" ;;
          *) echo -e "$info Invalid choice! VancedMicroG Installaion skipped." ;;
        esac
        commonPrompt
        
      fi
    
    else
      commonPrompt
    fi
  fi
}

overwriteArch() {
  if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
    cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
    echo -e "$info Device architecture spoofed to $cpuAbi!"
  else
    echo -e "$info Device architecture not spoofed yet!"
  fi
    echo -e "0. Disabled spoofing\n8. arm64-v8a\n7. armeabi-v7a\n4. x86_64\n6. x86\n"
    read -r -p "Select: " arch
    case "$arch" in
      0)
        echo -e "$running Disabling device architecture spoofing.."
        jq -e 'del(.DeviceArch)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete DeviceArch key from simplify.json
        echo -e "$good ${Green}Device architecture spoofing disabled successfully!${Reset}"
        ;;
      8)
        echo -e "$running Spoofing device architecture to arm64-v8a.."
        jq ".DeviceArch = \"arm64-v8a\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
        echo -e "$good ${Green}Device architecture spoofed to arm64-v8a successfully!${Reset}"
        ;;
      7)
        echo -e "$running Spoofing device architecture to armeabi-v7a.."
        jq ".DeviceArch = \"armeabi-v7a\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
        echo -e "$good ${Green}Device architecture spoofed to armeabi-v7a successfully!${Reset}"
        ;;
      4)
        echo -e "$running Spoofing device architecture to x86_64.."
        jq ".DeviceArch = \"x86_64\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
        echo -e "$good ${Green}Device architecture spoofed to x86_64 successfully!${Reset}"
        ;;
      6)
        echo -e "$running Spoofing device architecture to x86.."
        jq ".DeviceArch = \"x86\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
        echo -e "$good ${Green}Device architecture spoofed to x86 successfully!${Reset}"
        ;;
      *) echo -e "$info Invalid input! Please enter 0, 8, 7, 4, 6." ;;
    esac
  if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
    cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
  else
    cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
  fi
}

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

listOfPatches() {
  local clean_idx=${idx%\?}
  case "${apps[$clean_idx]}" in
    Quit)
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
    Google\ Photos)
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
    Proton\ Mail)
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

# Define the array
if [ $Android -ge 12 ]; then
  apps=(
    Quit
    YouTube
    #Spotify
    TikTok
    Google\ Photos
    $googleRecorder
    $Instagram
    $Facebook
    ${fbMessenger}
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
    Proton\ Mail
    MyFitnessPal
    Crunchyroll
    Cricbuzz
  )
elif [ $Android -eq 11 ]; then
  apps=(
    Quit
    YouTube
    #Spotify
    TikTok
    Google\ Photos
    $googleRecorder
    $Instagram
    $Facebook
    ${fbMessenger}
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
    Proton\ Mail
    Crunchyroll
    Cricbuzz
  )
elif [ $Android -eq 10 ]; then
  apps=(
    Quit
    YouTube
    #Spotify
    TikTok
    Google\ Photos
    $googleRecorder
    $Instagram
    $Facebook
    ${fbMessenger}
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
    Proton\ Mail
    Crunchyroll
    Cricbuzz
  )
elif [ $Android -eq 9 ]; then
  apps=(
    Quit
    YouTube
    #Spotify
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    ${fbMessenger}
    Lightroom
    Photomath
    RAR
    ${amazonPrimeVideo}
    Twitch
    Tumblr
    $Threads
    Strava
    SoundCloud
    Proton\ Mail
    Crunchyroll
    Cricbuzz
  )
elif [ $Android -eq 8 ]; then
  apps=(
    Quit
    YouTube
    #Spotify
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    ${fbMessenger}
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
    Quit
    #Spotify
    TikTok
    Google\ Photos
    $Instagram
    ${fbMessenger}
    Photomath
    RAR
    ${amazonPrimeVideo}
    Twitch
    Tumblr
    Cricbuzz
  )
elif [ $Android -eq 6 ]; then
  apps=(
    Quit
    TikTok
    Google\ Photos
    ${fbMessenger}
    Photomath
    RAR
    ${amazonPrimeVideo}
    Twitch
    Cricbuzz
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    TikTok
    Google\ Photos
    ${fbMessenger}
    Photomath
    RAR
    ${amazonPrimeVideo}
    Twitch
    Cricbuzz
  )
elif [ $Android -eq 4 ]; then
  apps=(
    Quit
    RAR
  )
fi

while true; do
  # Display the list
  echo -e "$info Available apps:"
  echo -e "↵   . CHANGELOG"
  echo -e "Arch. Spoof Device Arch"
  echo -e "i?  . List of Patches (0?=universal-patches)"
  for i in "${!apps[@]}"; do
    if [ -n "${apps[$i]}" ] && [ "${apps[$i]}" != "null" ]; then
      if [ "$i" -le 9 ]; then
        printf "%d   . %s\n" "$i" "${apps[$i]}"
      else
        printf "%d  . %s\n" "$i" "${apps[$i]}"
      fi
    fi
  done

  # Ask for an index, showing the valid range
  max=$(( ${#apps[@]} - 1 ))  # highest legal index
  read -rp "Enter the index [0-${max}] of the apps you want to patch: " idx

  # Validate and respond
  if [ "$idx" == 0 ]; then
    break  # break the while loop
  elif [[ $idx =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice Selected: ${apps[$idx]}"
  elif [[ "$idx" =~ ^[0-9]+\?$ ]]; then
    listOfPatches  # Call the listOfPatches function
    continue
  elif [[ "$idx" =~ ^[aA][rR][cC][hH] ]]; then
    overwriteArch  # Call the overwriteArch function
    continue
  elif [ "$idx" == "" ] || [ -z "$idx" ]; then
    if [ $release == "latest" ]; then
      tag=$(curl -sL ${auth} "https://api.github.com/repos/ReVanced/revanced-patches/releases/latest" | jq -r '.tag_name')
    else
      tag=$(curl -sL ${auth} "https://api.github.com/repos/ReVanced/revanced-patches/releases" | jq -r '.[].tag_name | select(contains("dev"))' | head -n 1)
    fi
    curl -sL ${auth} "https://api.github.com/repos/ReVanced/revanced-patches/releases/tags/$tag" | jq -r .body | glow  # Display the release notes
  else
    echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
  fi

  case ${apps[$idx]} in
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
      pkgVersion="9.0.72.967"
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
      Type="APK"
      Arch=("arm64-v8a + armeabi-v7a")
      activityPatched="com.zhiliaoapp.musically/com.ss.android.ugc.aweme.splash.SplashActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "tiktok_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Google\ Photos)
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
      pkgVersion="394.0.0.46.81"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch=("$cpuAbi")
      activityPatched="com.instagram.android/.activity.MainTabActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "instagram_patches_args" "$pkgName" "$activityPatched" "" "" ""
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
      Arch=("$cpuAbi")
      if [ $cpuAbi == arm64-v8a ] && [ $Android -ge 11 ]; then
        Type="APK"
      elif [ $cpuAbi == armeabi-v7a ] && [ $Android -ge 11 ]; then
        Type="BUNDLE"
      fi
      Os=("Android 11+")
      Dpi="nodpi"
      Or=("Download APK")
      activityPatched="com.facebook.katana/.LoginActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "facebook_patches_args" "$pkgName" "$activityPatched" "${Os[0]}" "$Dpi" "${Or[0]}"
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
      Type="APK"
      Arch=("$cpuAbi")
      activityPatched="com.facebook.orca/.auth.StartScreenActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "fb_messenger_patches_args" "$pkgName" "$activityPatched" "" "" ""
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
      pkgVersion="5.158.4"
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
      appName=("Amazon Prime Video")
      pkgVersion="3.0.412"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      primeVideoFileName=$(basename "$(find "$Download" -type f -name "${appName[0]}_v*-$cpuAbi.apk" -print -quit)")
      activityPatched="com.amazon.avod.thirdpartyclient/.LauncherActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "prime_video_patches_args" "$pkgName" "$activityPatched" "" "" ""
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
      appName=("Tumblr")
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
      Type="BUNDLE"
      Arch=("$cpuAbi")
      activityPatched="com.instagram.barcelona/.mainactivity.BarcelonaActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "threads_patches_args" "$pkgName" "$activityPatched" "" "" ""
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
      pkgVersion="2025.05.27-release"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch=("universal")
      activityPatched="com.soundcloud.android/.launcher.LauncherActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "soundcloud_patches_args" "$pkgName" "$activityPatched" "" "" ""
      ;;
    Proton\ Mail)
      pkgName="ch.protonmail.android"
      appName=("Proton Mail")
      pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("universal")
      activityPatched="ch.protonmail.android/.MainActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "protonmail_patches_args" "$pkgName" "$activityPatched" "" "" ""
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
done
###########################################################################################################################################
