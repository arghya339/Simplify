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
RV="$Simplify/RV"
RVX="$Simplify/RVX"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$RV" "$RVX" "$SimplUsr"  # Create $Simplify, $RV, $RVX and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir

# --- Checking Android Version ---
if [ $Android -le 3 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by ReVanced Patches.${Reset}"
  return 1
fi

echo -e "$info ${Blue}Target device:${Reset} $Model"

bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

#bash $Simplify/dlGitHub.sh "ReVanced" "revanced-patches" "latest" ".rvp" "$RV"
bash $Simplify/dlGitHub.sh "ReVanced" "revanced-patches" "pre" ".rvp" "$RV"
PatchesRvp=$(find "$RV" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

if [ "$Android" -ge "6" ]; then
  bash $Simplify/dlGitHub.sh "inotia00" "VancedMicroG" "latest" ".apk" "$SimplUsr"
  VancedMicroG=$(find "$SimplUsr" -type f -name "microg-*.apk" -print -quit)
  echo -e "$info ${Blue}VancedMicroG:${Reset} $VancedMicroG"
fi

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

# --- Generate patches.json file --- 
if [ $Android -ge 8 ]; then
  if [ -f "$RV/patches.json" ]; then
    rm $RV/patches.json
  fi
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patches -p "$RV/patches.json" $PatchesRvp
  if [ $? == 0 ] && [ -f "$RV/patches.json" ]; then
    echo -e "$info patches.json generated successfully."
    jq -r '.[] | .compatiblePackages // empty | .[] | {name: .name, version: .versions[-1]} | "\(.name) \(.version)"' $RV/patches.json | sort -u | awk '{a[$1]=$2} END{for (i in a) printf "\"%s\" \"%s\"\n", i, a[i]}'
  else
    echo -e "$bad patches.json was not generated!"
  fi
fi

# Get compatiblePackages version from json
getVersion() {
  local pkgName="$1"
  local json="$RV/patches.json"
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$(jq -r --arg pkg "$pkgName" '[.[] | .compatiblePackages // empty | .[] | select(.name == $pkg and .versions != null) | .versions[]] | sort | last' $json 2>/dev/null)
}

#  --- Patch Apps ---
patch_app() {
  local -n stock_apk_ref=$1
  local -n patches=$2  # nameref (-n) accept an array name as parameter
  local outputAPK=$3
  local log=$4
  local appName=$5
  
  if [ "$appname" != "Instagram" ] || [ "$appname" != "Facebook" ] || [ "$appname" != "Facebook Messenger" ]; then
    universalPatches=(
      -e "Change version code" -OversionCode="2147483647" 
      -e "Disable Pairip license check" 
      -e "Predictive back gesture" 
      -e "Remove share targets"
      -e "Remove screen capture restriction"
      -e "Remove screenshot restriction"
    )
  else
    universalPatches=()
  fi
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "${stock_apk_ref[0]}" \
    "${patches[@]}" \
    "${universalPatches[@]}" \
    --custom-aapt2-binary="$HOME/aapt2" \
    --purge $ripLib -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/ReVanced/revanced-patches/issues/new?template=bug_report.yml"
    termux-open --send "$log"
  fi
}

# --- Collect the enable/disable patches name with options in arrays ---
yt_patches_args=(
  # enable patches with their options
  -e "GmsCore support" -O gmsCoreVendorGroupId="com.mgoogle"
  -e "Custom branding" -O appName="YouTube RV" -O iconPath="$SimplUsr/branding/youtube/launcher/google_family"
  -e "Change header" -O header="$SimplUsr/branding/youtube/header/google_family"
  -e "Change package name" -O packageName="app.revanced.android.youtube"
  
  # disable patches
  -d "Announcements"
)

spotify_patches_args=(
  -e "Change lyrics provider"
  -e "Custom theme"
  -e "Change package name" -OpackageName="com.spotify.music"
  
  -d "Hide Create button"
)

tiktok_patches_args=(
  -e "SIM spoof"
  -e "Change package name" -OackageName="com.zhiliaoapp.musically"
)

photos_patches_args=(
  -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle"
  -e "Change package name" -OackageName="app.revanced.android.apps.photos"
)

instagram_patches_args=()

facebook_patches_args=()

fb_messenger_patches_args=()

lightroom_patches_args=(
  -e "Change package name" -OackageName="com.adobe.lrmobile"
)

photomath_patches_args=(
  -e "Change package name" -OackageName="com.microblink.photomath"
)

duolingo_patches_args=(
  -e "Change package name" -OackageName="com.duolingo"
)

rar_patches_args=(
  -e "Change package name" -OackageName="com.rarlab.rar"
)

prime_video_patches_args=(
  -e "Rename shared permissions"
  -e "Change package name" -OackageName="com.amazon.avod.thirdpartyclient"
)

twitch_patches_args=(
  -e "Change package name" -OackageName="tv.twitch.android.app"
)

tumblr_patches_args=(
  -e "Fix old versions"
  -e "Change package name" -OackageName="com.tumblr"
)

# --- Build App ---
build_app() {
  # local variables
  local pkgName=$1
  local -n appNameRef=$2
  local pkgVersion=$3
  local Type=$4
  local -n archRef=$5
  local web=$6
  local -n stock_apk_path=$7
  local appPatchesArgs=$8
  local outputAPK=$9
  local fileName=$(basename $outputAPK)
  local log=$10
  local pkgPatches=$11
  local activityPatches=$12
  

  if [ "$web" == "APKMirror" ]; then
    bash $Simplify/APKMdl.sh "$pkgName" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from APKMirror
  else
    bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${archRef[0]}"  # Download stock apk from Uptodown
  fi
  
  if [ -f "${stock_apk_path[0]}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_path[0]}"
    echo -e "$running Patching ${appNameRef[0]} RV.."
    patch_app "stock_apk_path" "$appPatchesArgs" "$outputAPK" "$log" "${appNameRef[0]}"
  fi
  
  if [ -f "$outputAPK" ]; then
    
    if [ $pkgName == "com.google.android.youtube" ] || [ $pkgName == "com.google.android.apps.youtube.music" ] || [ $pkgName == "com.google.android.apps.photos" ]; then
      echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
      echo -e "[?] ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset} \c" && read opt
      case $opt in
        y*|Y*|"")
          echo -e "$running Please Wait !! Installing VancedMicroG apk.."
          bash $Simplify/apkInstall.sh "$VancedMicroG" "com.mgoogle.android.gms" "org.microg.gms.ui.SettingsActivity"
          ;;
        n*|N*) echo -e "$notice VancedMicroG Installaion skipped!" ;;
        *) echo -e "$info Invalid choice! VancedMicroG Installaion skipped." ;;
      esac
    fi

    echo -e "[?] ${Yellow}Do you want to install ${appNameRef[0]} RV app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        if [ $pkgName == "com.instagram.android" ] || [ $pkgName == "com.facebook.katana" ] || [ $pkgName == "com.facebook.orca" ]; then
          echo -e "$notice Warning! Disable auto updates for the patched app to avoid unexpected issues."
        fi
        echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RV apk.."
        bash $Simplify/apkInstall.sh "$outputAPK" "$pkgPatches" "$activityPatches"
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
        echo -e "$info Locate '$fileName' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
        ;;
        *) echo -e "$info Invalid choice! ${appNameRef[0]} RV Sharing skipped." ;;
    esac
  
  fi
}

# Req
<<comment
  YouTube 8.0+
  Spotify 7.0+
  TikTok 5.0+
  Google Photos 5.0+
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
comment

if  [[ $Android -ge 9  &&  ( "$cpuAbi" == "arm64-v8a" || "$cpuAbi" == "x86_64" ) ]]; then
  Instagram="Instagram"
  Facebook="Facebook"
  fbMessenger=("Facebook Messenger")
elif [[ $Android -ge 8  &&  ( "$cpuAbi" == "armeabi-v7a" || "$cpuAbi" == "x86" ) ]]; then
  Facebook="Facebook"
elif [[ $Android -ge 7  &&  ( "$cpuAbi" == "armeabi-v7a" || "$cpuAbi" == "x86" ) ]]; then
  Instagram="Instagram"
elif [[ $Android -ge 5  &&  ( "$cpuAbi" == "armeabi-v7a" || "$cpuAbi" == "x86" ) ]]; then
  fbMessenger=("Facebook Messenger")
fi

if [ $cpuAbi == "arm64-v8a" ] || [ $cpuAbi == "armeabi-v7a" ]; then
  amazonPrimeVideo=("Amazon Prime Video")
fi

# Define the array
if [ $Android -ge 10 ]; then
  apps=(
    Quit
    YouTube
    Spotify
    TikTok
    Google\ Photos
    "$Instagram"
    "$Facebook"
    "${fbMessenger[0]}"
    Lightroom
    Photomath
    Duolingo
    RAR
    "$amazonPrimeVideo"
    Twitch
    Tumblr
  )
elif [ $Android -eq 9 ]; then
  apps=(
    Quit
    YouTube
    Spotify
    TikTok
    Google\ Photos
    "$Instagram"
    "$Facebook"
    "${fbMessenger[0]}"
    Lightroom
    Photomath
    RAR
    "$amazonPrimeVideo"
    Twitch
    Tumblr
  )
elif [ $Android -eq 8 ]; then
  apps=(
    Quit
    YouTube
    Spotify
    TikTok
    Google\ Photos
    "$Instagram"
    "$Facebook"
    "${fbMessenger[0]}"
    Lightroom
    Photomath
    RAR
    "$amazonPrimeVideo"
    Twitch
    Tumblr
  )
elif [ $Android -eq 7 ]; then
  apps=(
    Quit
    Spotify
    TikTok
    Google\ Photos
    "$Instagram"
    "${fbMessenger[0]}"
    Photomath
    RAR
    "$amazonPrimeVideo"
    Twitch
    Tumblr
  )
elif [ $Android -eq 6 ]; then
  apps=(
    Quit
    TikTok
    Google\ Photos
    "${fbMessenger[0]}"
    Photomath
    RAR
    "$amazonPrimeVideo"
    Twitch
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    TikTok
    Google\ Photos
    "${fbMessenger[0]}"
    Photomath
    RAR
    "$amazonPrimeVideo"
    Twitch
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
  for i in "${!apps[@]}"; do
    printf "%d. %s\n" "$i" "${apps[$i]}"
  done

  # Ask for an index, showing the valid range
  max=$(( ${#apps[@]} - 1 ))  # highest legal index
  read -rp "Enter the index [0-${max}] of the apps you want to patch: " idx

  # Validate and respond
  if [ $idx == 0 ]; then
    break  # break the while loop
  elif [[ $idx =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice You chose: ${apps[$idx]}"
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
      Type="BUNDLE"
      Arch=("universal")
      youtube_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/youtube-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/yt-rv-patch_log.txt"
      pkgPatches="app.revanced.android.youtube"
      activityPatches="com.google.android.youtube/.app.honeycomb.Shell\$HomeActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "youtube_apk_path" "yt_patches_args" "$outputAPK" "$log" "$pkgPatches" "$activityPatches"
      ;;
    Spotify)
      pkgName="com.spotify.music"
      appName=("Spotify")
      #pkgVersion="9.0.28.630"
      pkgVersion="8.6.98.900"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="apk"
      Arch=("armeabi-v7a, x86, arm64-v8a, x86_64")
      spotify_apk_path=("$Download/${appName[0]}_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/spotify-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/spotify-rv-patch_log.txt"
      activityPatches="com.spotify.music/.MainActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "Uptodown" "spotify_apk_path" "spotify_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
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
      tiktok_apk_path=("$Download/${appName[0]}_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/tiktok-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/tiktok-rv-patch_log.txt"
      activityPatches="com.zhiliaoapp.musically/com.ss.android.ugc.aweme.splash.SplashActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "tiktok_apk_path" "tiktok_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
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
      photos_apk_path=("$Download/${appName[0]}_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/google-photos-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/google-photos-rv-patch_log.txt"
      pkgPatches="app.revanced.android.apps.photos"
      activityPatches="com.google.android.apps.photos/.home.HomeActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "photos_apk_path" "photos_patches_args" "$outputAPK" "$log" "$pkgPatches" "$activityPatches"
      ;;
    Instagram)
      pkgName="com.instagram.android"
      appName=("Instagram")
      pkgVersion="378.0.0.52.68"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      instagram_apk_path=("$Download/${appName[0]}_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/instagram-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/instagram-rv-patch_log.txt"
      activityPatches="com.instagram.android/.activity.MainTabActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "instagram_apk_path" "instagram_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
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
      Type="APK"
      Arch=("$cpuAbi")
      facebook_apk_path=("$Download/${appName[0]}_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/facebook-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/facebook-rv-patch_log.txt"
      activityPatches="com.facebook.katana/.LoginActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "facebook_apk_path" "facebook_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
      ;;
    Facebook\ Messenger)
      pkgName="com.facebook.orca"
      appName=("Facebook Messenger")
      pkgVersion="512.1.0.67.109"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      fb_messenger_apk_path=("$Download/${appName[0]}_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/fb-messenger-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/fb-messenger-rv-patch_log.txt"
      activityPatches="com.facebook.orca/.auth.StartScreenActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "fb_messenger_apk_path" "fb_messenger_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
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
      lightroom_apk_path=("$Download/${appName[0]}_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/lightroom-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/lightroom-rv-patch_log.txt"
      activityPatches="com.adobe.lrmobile/.StorageCheckActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "Uptodown" "lightroom_apk_path" "lightroom_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"  # F*** Cloudflare DDoS Protection on APKMirror Lightroom Page
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
      photomath_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/photomath-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/photomath-rv-patch_log.txt"
      activityPatches="com.microblink.photomath/.main.activity.LauncherActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "photomath_apk_path" "photomath_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
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
      duolingo_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/duolingo-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/duolingo-rv-patch_log.txt"
      activityPatches="com.duolingo/.app.LoginActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "duolingo_apk_path" "duolingo_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
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
      rar_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/rar-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/rar-rv-patch_log.txt"
      activityPatches="com.rarlab.rar/.MainActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "rar_apk_path" "rar_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
      ;;
    Amazon\ Prime\ Video)
      pkgName="com.amazon.avod.thirdpartyclient"
      appName=("Amazon Prime Video")
      pkgVersion="3.0.403"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="APK"
      Arch=("$cpuAbi")
      primeVideoFileName=$(basename "$(find "$Download" -type f -name "${appName[0]}_v*-$cpuAbi.apk" -print -quit)")
      prime_video_apk_path=("$Download/$primeVideoFileName")
      outputAPK="$SimplUsr/prime-video-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/prime-video-rv-patch_log.txt"
      activityPatches="com.amazon.avod.thirdpartyclient/.LauncherActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "prime_video_apk_path" "prime_video_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
      ;;
    Twitch)
      pkgName="tv.twitch.android.app"
      appName=("Twitch")
      pkgVersion="16.9.1"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
      fi
      Type="BUNDLE"
      Arch=("universal")
      twitch_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/twitch-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/twitch-rv-patch_log.txt"
      activityPatches="tv.twitch.android.app/.core.LandingActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "twitch_apk_path" "twitch_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
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
      tumblr_apk_path=("$Download/${appName[0]}_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/tumblr-rv_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/tumblr-rv-patch_log.txt"
      activityPatches="com.tumblr/.ui.activity.JumpoffActivity"
      build_app "$pkgName" "appName" "$pkgVersion" "$Type" "Arch" "APKMirror" "tumblr_apk_path" "tumblr_patches_args" "$outputAPK" "$log" "$pkgName" "$activityPatches"
      ;;
  esac  
done
###########################################################################################################################################################################
