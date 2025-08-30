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
jdkVersion="21"
locale=$(getprop persist.sys.locale | cut -d'-' -f1)  # Get System Languages
if [ -z $locale ]; then
  locale=$(getprop ro.product.locale | cut -d'-' -f1)  # Get Languages
fi
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
Simplify="$HOME/Simplify"  # /data/data/com.termux/files/home/Simplify dir
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$SimplUsr"  # Create $Simplify and $SimplUsr dir if it does't exist
dataJson="$Simplify/data.json"  # Data file to store simplify dlPatchedApp data
  # Create empty json file if it doesn't exist
  if [ ! -f "$dataJson" ]; then
    jq -n '[]' > "$dataJson"
  fi
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
ChangeRVXSource="$(jq -r '.ChangeRVXSource' "$simplifyJson" 2>/dev/null)"
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
if [ $FetchPreRelease -eq 1 ]; then
  release="pre"
else
  release="latest"
fi

echo -e "$info ${Blue}Target device:${Reset} $Model"

# --- function to store app metadata to data.json file ---
data() {
  local assets="$1"
  local updated_at="$2"
  local version="$3"
  
  
  # Create empty json file if it doesn't exist
  if [ ! -f "$dataJson" ]; then
    jq -n '[]' > "$dataJson"
  fi
  
  # Check if asset exists in array
  if jq --arg assets "$assets" 'any(.[]; .assets == $assets)' "$dataJson" | grep -q true; then
    # Update existing entry
    jq --arg assets "$assets" --arg updated_at "$updated_at" --arg version "$version" 'map(if .assets == $assets then .updated_at = $updated_at | .version = $version else . end)' "$dataJson" > temp.json && mv temp.json "$dataJson"
  else
    # Add new entry
    jq --arg assets "$assets" --arg updated_at "$updated_at" --arg version "$version" '. += [{"assets": $assets, "updated_at": $updated_at, "version": $version}]' "$dataJson" > temp.json && mv temp.json "$dataJson"
  fi
}

# --- function to install app ---
appInstall() {
    echo -e "[?] ${Yellow}Do you want to install ${appName} $version app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
          echo -e "$running Please Wait !! Installing Patched ${appName} apk.."
        else
          echo -e "$running Please Wait !! Installing ${appName} apk.."
        fi
        if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ] || [ "$repo" == "spotube" ]; then
          bash $Simplify/apkInstall.sh "$apk_path" "$pkgPatched" "$activityPatched"
          data "$assets" "$updated_at" "$version"
        else
          bash $Simplify/apkInstall.sh "$apk_path" "$pkgApp" "$activityApp"
          if [ "$appName" == "CloudStream" ]; then
            if jq --arg appName "$appName" 'any(.[]; .assets == $appName)' "$dataJson" | grep -q false; then
              termux-open-url "https://rentry.co/cs3-repos"
            fi
          elif [ "$appName" == "YTPro" ] || [ "$appName" == "Nobook" ]; then
            termux-open-url "https://play.google.com/store/apps/details?id=com.google.android.webview"
          fi
          data "$appName" "$updated_at" "$tag"
        fi
        if su -c "id" >/dev/null 2>&1 || "$HOME/rish" -c "id" >/dev/null 2>&1; then
          rm -f "$apk_path"
        fi
        ;;
      n*|N*) echo -e "$notice ${appName} Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! ${appName} Installaion skipped." ;;
    esac
    
    echo -e "[?] ${Yellow}Do you want to Share ${appName} app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
          echo -e "$running Please Wait !! Sharing Patched ${appName} apk Link.."
        else
          echo -e "$running Please Wait !! Sharing ${appName} apk Link.."
        fi
        am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "$url" > /dev/null
        ;;
      n*|N*) echo -e "$notice ${appName} Sharing skipped!"
        ;;
      *) echo -e "$info Invalid choice! ${appName} Sharing skipped." ;;
    esac
}

# --- function to download app ---
dlApp() {
  local appName="${1}"
  local owner=$2
  local repo=$3
  local release=$4
  local regex="$5"
  local file_pattern="$6"
  local tag="$7"
  local assets="$8"
  local url="https://github.com/$owner/$repo/releases/download/$tag/$assets"
  local pkgApp="$9"
  local activityApp="$10"
  

  if [ "$tag" == "nightly" ] || [ "$tag" == "pre-release" ]; then
    updated_at=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/tags/$tag" | jq -r --arg assets "$assets" '.assets[] | select(.name == $assets) | .updated_at')
  else
    updated_at=
  fi
  app_updated_at=$(jq --arg appName "$appName" -r '.[] | select(.assets == $appName) | .updated_at' $dataJson)
  version=$(jq --arg appName "$appName" -r '.[] | select(.assets == $appName) | .version' $dataJson)
  if [ "$tag" == "$version" ] && [ "$app_updated_at" == "$updated_at" ]; then
    echo -e "$notice ${Yellow}$appName Already up to date!${Reset}"
  else
    echo -e "$running Downloading $appName from GitHub.."
    bash $Simplify/dlGitHub.sh "$owner" "$repo" "$release" ".apk" "$SimplUsr" "$regex"
    apk_path=$(find "$SimplUsr" -type f -name "$file_pattern" -print -quit)
    if [ -f "$apk_path" ]; then
      echo -e "$info ${Green}Downloaded $appName APK found:${Reset} $apk_path"
      version=$($HOME/aapt2 dump badging $apk_path 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
      appInstall
    fi
  fi
}

# --- function to download & install patched apps ---
dlPatchedApp() {
  local appName="${1}"
  local owner="$2"
  local repo="$3"
  local assets="$4"
  if [ "$repo" == "spotube" ]; then
    local url="https://github.com/KRTirtho/spotube/releases/download/nightly/Spotube-android-all-arch.apk"
    updated_at=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/tags/nightly" | jq -r --arg assets "$assets" '.assets[] | select(.name == $assets) | .updated_at')
    assets="Spotube-playstore-all-arch.apk"
  else
    local url="https://github.com/$owner/$repo/releases/download/all/$assets"
    updated_at=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg assets "$assets" '.assets[] | select(.name == $assets) | .updated_at')
  fi
  local pkgPatched="$5"
  local activityPatched="$6"
  
  
    # read the updated_at value for the specified asset
    app_updated_at=$(jq --arg assets "$assets" -r '.[] | select(.assets == $assets) | .updated_at' $dataJson)
    if [ "$app_updated_at" == "$updated_at" ]; then
      echo -e "$notice ${Yellow}$appName Already up to date!${Reset}"
    elif [ "$app_updated_at" != "$updated_at" ] || [ ! -f "$dataJson" ]; then
      if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
        echo -e "$running Downloading $appName from GitHub.."
        bash $Simplify/dlGitHub.sh "$owner" "$repo" "latest" ".apk" "$SimplUsr" "$assets"
        apk_path="$SimplUsr/$assets"
      else
        # Download .aab file
        dlUrl="https://github.com/KRTirtho/spotube/releases/download/nightly/Spotube-playstore-all-arch.aab"
        assets_name="Spotube-playstore-all-arch.aab"
        aab_path="$SimplUsr/$assets_name"
        echo -e "$running Downloading $appName.."
        while true; do
          aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$assets_name" -d "$SimplUsr" "$dlUrl"
          if [ $? -eq 0 ]; then
            echo  # White Space
            break
          fi
          echo -e "${bad} ${Red}Download failed! retrying in 5 seconds..${Reset}"
          sleep 5  # Wait 5 seconds
        done
        
        # Download bundletool
        bundletoolJar=$(find "$Simplify" -type f -name "bundletool-all-*.jar" -print -quit 2>/dev/null)
        if [ ! -f "$bundletoolJar" ]; then
          bash $Simplify/dlGitHub.sh "google" "bundletool" "latest" ".jar" "$Simplify"
          bundletoolJar=$(find "$Simplify" -type f -name "bundletool-all-*.jar" -print -quit)
        fi
        # Build apks from aab using bundletool
        apks_path="$SimplUsr/Spotube-playstore-all-arch.apks"
        echo -e "$running Build apks from aab.."
        $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $bundletoolJar build-apks --bundle=$aab_path --output=$apks_path --aapt2=~/aapt2 2>&1 | grep -v "WARNING: The APKs won't be signed"
        if [ $? -eq 0 ] || [ -f "$apks_path" ]; then
          echo "Success"
        fi
        rm -f "$aab_path"
        
        # Extract apks file
        if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
          cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
        else
          cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
        fi
        if [ "$cpuAbi" == "arm64-v8a" ]; then
          cpuAbi="arm64_v8a"
        elif [ "$cpuAbi" == "armeabi-v7a" ]; then
          cpuAbi="armeabi_v7a"
        fi
        mkdir -p "$SimplUsr/Spotube-playstore-all-arch"
        echo -e "$running Extracting apks.."
        pv "$apks_path" | bsdtar -xf - -C "$SimplUsr/Spotube-playstore-all-arch" --include "splits/base-master.apk" --include "splits/base-$cpuAbi.apk" --include "splits/base-${lcd_dpi}.apk" --include "splits/base-$locale.apk"
        cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
        rm -f "$apks_path"
        # Merge splits apks to standalone apk using APKEditor
        bash $Simplify/dlGitHub.sh "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
        APKEditor=$(find "$Simplify" -type f -name "APKEditor-*.jar" -print -quit)
        echo -e "$running Merge splits apks to standalone apk.."
        $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $APKEditor m -i "$SimplUsr/Spotube-playstore-all-arch/splits" -o "$SimplUsr/Spotube-playstore-all-arch.apk"
        rm -rf "$SimplUsr/Spotube-playstore-all-arch"
        # Sign apk
        apk_path="$SimplUsr/Spotube-playstore-all-arch-signed.apk"
        echo -e "$running Sign apk.."
        $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar sign --ks $Simplify/ks.keystore --ks-pass pass:123456 --ks-key-alias ReVancedKey --key-pass pass:123456 --out "$apk_path" "$SimplUsr/Spotube-playstore-all-arch.apk"
        $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -printcert -jarfile "${apk_path}" | grep -oP 'Owner: \K.*' 2>/dev/null
        if [ $? -eq 0 ]; then
          rm -f "$SimplUsr/Spotube-playstore-all-arch.apk" && rm -f "${apk_path}.idsig"
          mv "$SimplUsr/Spotube-playstore-all-arch-signed.apk" "$SimplUsr/Spotube-playstore-all-arch.apk"
        elif [ $? -ne 0 ]; then
          $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar verify --print-certs "${apk_path}" | grep -oP 'Signer #1 certificate DN: \K.*'
          if [ $? -eq 0 ]; then
            rm -f "$SimplUsr/Spotube-playstore-all-arch.apk" && rm -f "${apk_path}.idsig"
            mv "$SimplUsr/Spotube-playstore-all-arch-signed.apk" "$SimplUsr/Spotube-playstore-all-arch.apk"
          fi
        fi
        apk_path="$SimplUsr/Spotube-playstore-all-arch.apk"
        assets=$(basename "$apk_path")
      fi
      if [ -f "$apk_path" ]; then
        echo -e "$info ${Green}Downloaded $appName APK found:${Reset} $apk_path"
        version=$($HOME/aapt2 dump badging $apk_path 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
        appInstall
      fi
    fi
}

# --- Decisions block for app that required specific arch & android version ---
if  [[ $Android -ge 9  &&  ( "$cpuAbi" == "arm64-v8a" || "$cpuAbi" == "x86_64" ) ]]; then
  Instagram="Instagram"
  #Facebook="Facebook"
  fbMessenger="FacebookMessenger"
#elif [[ $Android -ge 8  &&  ( "$cpuAbi" == "armeabi-v7a" || "$cpuAbi" == "x86" ) ]]; then
  #Facebook="Facebook"
elif [[ $Android -ge 7  &&  ( "$cpuAbi" == "armeabi-v7a" || "$cpuAbi" == "x86" ) ]]; then
  Instagram="Instagram"
elif [[ $Android -ge 5  &&  ( "$cpuAbi" == "armeabi-v7a" || "$cpuAbi" == "x86" ) ]]; then
  fbMessenger="FacebookMessenger"
fi

if [ $cpuAbi == "arm64-v8a" ] || [ $cpuAbi == "armeabi-v7a" ]; then
  novaLauncher="NovaLauncher"
fi

if  [[ $Android -ge 11  &&  ( "$cpuAbi" == "arm64-v8a" || "$cpuAbi" == "armeabi-v7a" ) ]]; then
  Facebook="Facebook"
fi

# --- Arrays of apps list that required specific android version ---
if [ $Android -ge 10 ]; then
  apps=(
    Quit
    Vanced\ MicroG
    ReVanced\ GmsCore
    YouTube\ RV
    YouTube
    YTPro
    FreeTubeAndroid
    Tubular
    YouTube\ Music
    InnerTune
    Seal
    ytdlnis
    #Spotify
    spotube
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    Nobook
    ${fbMessenger}
    Nagram
    Nekogram
    Twitter
    piko\ Twitter
    Reddit
    Adobe\ Lightroom
    Photomath
    Duolingo
    RAR
    CloudStream
    Breezy\ Weather
    WeatherMaster
    Twitch
    Tumblr
    Strava
    SoundCloud
    ${novaLauncher}
    Lawnchair
    Tasker
  )
elif [ $Android -eq 9 ]; then
  apps=(
    Quit
    Vanced\ MicroG
    ReVanced\ GmsCore
    YouTube\ RV
    YouTube
    YTPro
    FreeTubeAndroid
    Tubular
    YouTube\ Music
    InnerTune
    Seal
    ytdlnis
    #Spotify
    spotube
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    Nobook
    ${fbMessenger}
    Nagram
    Nekogram
    Twitter
    piko\ Twitter
    Reddit
    Adobe\ Lightroom
    Photomath
    RAR
    CloudStream
    Breezy\ Weather
    WeatherMaster
    Twitch
    Tumblr
    Strava
    SoundCloud
    ${novaLauncher}
    Lawnchair
    Tasker
  )
elif [ $Android -eq 8 ]; then
  apps=(
    Quit
    Vanced\ MicroG
    ReVanced\ GmsCore
    YouTube\ RV
    YouTube
    YTPro
    FreeTubeAndroid
    Tubular
    YouTube\ Music
    InnerTune
    Seal
    ytdlnis
    #Spotify
    spotube
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    Nobook
    ${fbMessenger}
    Nagram
    Nekogram
    Twitter
    piko\ Twitter
    Adobe\ Lightroom
    Photomath
    RAR
    CloudStream
    Breezy\ Weather
    WeatherMaster
    Twitch
    Tumblr
    Strava
    SoundCloud
    ${novaLauncher}
    Lawnchair
    Tasker
  )
elif [ $Android -eq 7 ]; then
  apps=(
    Quit
    Vanced\ MicroG
    ReVanced\ GmsCore
    YouTube
    YTPro
    FreeTubeAndroid
    Tubular
    YouTube\ Music
    InnerTune
    Seal
    ytdlnis
    #Spotify
    spotube
    TikTok
    Google\ Photos
    $Instagram
    Nobook
    ${fbMessenger}
    Nagram
    Nekogram
    Photomath
    RAR
    CloudStream
    WeatherMaster
    Twitch
    Tumblr
    Tasker
  )
elif [ $Android -eq 6 ]; then
  apps=(
    Quit
    Vanced\ MicroG
    ReVanced\ GmsCore
    YouTube
    YTPro
    Tubular
    YouTube\ Music
    TikTok
    Google\ Photos
    Nobook
    ${fbMessenger}
    Nagram
    Nekogram
    Photomath
    RAR
    CloudStream
    WeatherMaster
    Twitch
    Tasker
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    YTPro
    Tubular
    Vanced\ MicroG
    ReVanced\ GmsCore
    YouTube\ Music
    TikTok
    Google\ Photos
    Nobook
    ${fbMessenger}
    Nagram
    Nekogram
    Photomath
    RAR
    CloudStream
    WeatherMaster
    Twitch
    Tasker
  )
elif [ $Android -eq 4 ]; then
  apps=(
    Quit
    ReVanced\ GmsCore
    RAR
  )
fi

while true; do
  # Display the apps list
  echo -e "$info Available apps:"
  for i in "${!apps[@]}"; do
    if [ -n "${apps[$i]}" ] && [ "${apps[$i]}" != "null" ]; then
      if [ "$i" -le 9 ]; then
        printf "%d . %s\n" "$i" "${apps[$i]}"
      else
        printf "%d. %s\n" "$i" "${apps[$i]}"
      fi
    fi
  done

  # Ask for an index, showing the valid range
  max=$(( ${#apps[@]} - 1 ))  # highest legal index
  read -rp "Enter the index [0-${max}] of the apps you want to download: " idx

  # Validate and respond
  if [ $idx == 0 ]; then
    break  # break the while loop
  elif [[ $idx =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice Selected: ${apps[$idx]}"
  else
    echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
  fi
  
  release=latest
  # main conditional control flow
  case ${apps[$idx]} in
    Vanced\ MicroG)
      appName="Vanced MicroG"
      repo="VancedMicroG"
      if [ $Android -eq 5 ]; then
        owner="TeamVanced"
        tag="v0.2.22.212658-212658001"
      elif [ "$Android" -ge "6" ]; then
        owner="inotia00"
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      fi
      file_pattern="microg-*.apk"
      assets="microg.apk"
      pkgApp="com.mgoogle.android.gms"
      activityApp="com.mgoogle.android.gms/org.microg.gms.ui.SettingsActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    ReVanced\ GmsCore)
      appName="ReVanced GmsCore"
      owner="YT-Advanced"
      repo="GmsCore"
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      file_pattern="app.revanced.android.gms-*.apk"
      regex="app.revanced.android.gms-.*.apk"
      assets=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name')
      pkgApp="app.revanced.android.gms"
      activityApp="app.revanced.android.gms/org.microg.gms.ui.SettingsActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    YouTube\ RV)
      appName="YouTube RV"
      owner="arghya339"
      repo="ReVancedApp-Actions"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="youtube-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="youtube-beta-$cpuAbi-revanced.apk"  # Use Beta release
      fi
      pkgPatched="app.revanced.android.youtube"
      activityPatched="com.google.android.youtube/.app.honeycomb.Shell\$HomeActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    YouTube)
      appName="YouTube"
      owner="arghya339"
      repo="ReVancedApp-Actions"
      if [ $Android -ge 8 ]; then
        if [ "$ChangeRVXSource" -eq 0 ]; then
          if [ "$FetchPreRelease" -eq 0 ]; then
            assets="youtube-$cpuAbi-revanced-extended.apk"  # Use Stable release
          else
            assets="youtube-beta-$cpuAbi-revanced-extended.apk"  # Use Beta release
          fi
        else
          if [ "$FetchPreRelease" -eq 0 ]; then
            assets="youtube-stable-$cpuAbi-anddea.apk"  # Use Stable release
          else
            assets="youtube-beta-$cpuAbi-anddea.apk"  # Use Beta release
          fi
        fi
      elif [ $Android -eq 7 ] || [ $Android -eq 6 ]; then
        if [ "$ChangeRVXSource" -eq 0 ]; then
          assets="youtube-$cpuAbi-revanced-extended-android-6-7.apk" # Use YT Android 6-7 by kitadai31
        else
          assets="youtube-$cpuAbi-revanced-extended-android-6-7-arghya339.apk" # Use YT Android 6-7 forked by arghya339
        fi
      fi
      pkgPatched="app.rvx.android.youtube"
      activityPatched="com.google.android.youtube/.app.honeycomb.Shell\$HomeActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    YTPro)
      appName="YTPro"
      owner="prateek-chaubey"
      repo="YTPro"
      file_pattern="YTPRO-*.apk"
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      assets="YTPRO.apk"
      pkgApp="com.google.android.youtube.pro"
      activityApp="com.google.android.youtube.pro/.MainActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    FreeTubeAndroid)
      appName="FreeTubeAndroid"
      owner="MarmadileManteater"
      repo="FreeTubeAndroid"
      file_pattern="freetube-*-Android.apk"
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      assets="freetube-$tag-Android.apk"
      pkgApp="io.freetubeapp.freetube"
      activityApp="io.freetubeapp.freetube/.MainActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    Tubular)
      appName="Tubular"
      owner="polymorphicshade"
      repo="Tubular"
      file_pattern="tubular_v*.apk"
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      assets="tubular_$tag.apk"
      pkgApp="org.polymorphicshade.tubular"
      activityApp="org.polymorphicshade.tubular/org.schabi.newpipe.MainActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    YouTube\ Music)
      appName="YouTube Music"
      owner="arghya339"
      repo="ReVancedApp-Actions"
      if [ $Android -ge 8 ]; then
        if [ "$ChangeRVXSource" -eq 0 ]; then
          if [ $FetchPreRelease -eq 0 ]; then
            assets="youtube-music-$cpuAbi-revanced-extended.apk"  # Use Stable release
          else
            assets="youtube-music-beta-$cpuAbi-revanced-extended.apk"  # Use Beta release
          fi
        else
          if [ $FetchPreRelease -eq 0 ]; then
            assets="youtube-music-stable-$cpuAbi-anddea.apk"  # Use Stable release
          else
            assets="youtube-music-beta-$cpuAbi-anddea.apk"  # Use Beta release
          fi
        fi
      elif [ $Android -eq 7 ]; then
        if [ $FetchPreRelease -eq 0 ]; then
          assets="youtube-music-android-7-$cpuAbi-revanced-extended.apk"  # Use Stable release
        else
          assets="youtube-music-beta-android-7-$cpuAbi-revanced-extended.apk"  # Use Beta release
        fi
      elif [ $Android -eq 6 ] || [ $Android -eq 5 ]; then
        if [ $FetchPreRelease -eq 0 ]; then
          assets="youtube-music-android-5-6-$cpuAbi-revanced-extended.apk"  # Use Stable release
        else
          assets="youtube-music-beta-android-5-6-$cpuAbi-revanced-extended.apk"  # Use Beta release
        fi
      fi
      pkgPatched="app.rvx.android.apps.youtube.music"
      activityPatched="com.google.android.apps.youtube.music/.activities.MusicActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    InnerTune)
      appName="InnerTune"
      owner="z-huang"
      repo="InnerTune"
      regex="InnerTune_v.*_full_$cpuAbi.apk"
      file_pattern="InnerTune_v*_full_$cpuAbi.apk"
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      assets="InnerTune_${tag}_full_$cpuAbi.apk"
      pkgApp="com.zionhuang.music"
      activityApp="com.zionhuang.music/.MainActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    Seal)
      appName="Seal"
      owner="JunkFood02"
      repo="Seal"
      if [ "$FetchPreRelease" -eq 0 ]; then
        regex="Seal-.*-$cpuAbi-release.apk"
        file_pattern="Seal-*-$cpuAbi-release.apk"
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name | sub("^v"; "")' 2>/dev/null)  # 1.13.1
        assets="Seal-$tag-$cpuAbi-release.apk"
        pkgApp="com.junkfood.seal"
        activityApp="com.junkfood.seal/.MainActivity"
      else
        release=alpha
        regex="Seal-.*-githubPreview-$cpuAbi-release.apk"
        file_pattern="Seal-*-githubPreview-$cpuAbi-release.apk"
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r '.[].tag_name | sub("^v"; "") | select(contains("alpha"))' | head -n 1 2>/dev/null)  # 2.0.0-alpha.5
        assets="Seal-$tag-githubPreview-$cpuAbi-release.apk"
        pkgApp="com.junkfood.seal.preview"
        activityApp="com.junkfood.seal.preview/.MainActivity"
      fi
      dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    ytdlnis)
      appName="ytdlnis"
      owner="deniscerri"
      repo="ytdlnis"
      if [ "$FetchPreRelease" -eq 0 ]; then
        regex="YTDLnis-.*-$cpuAbi-release.apk"
        file_pattern="YTDLnis-*-$cpuAbi-release.apk"
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name | sub("^v"; "")' 2>/dev/null)  # 1.13.1
      else
        release=beta
        regex="YTDLnis-.*-beta-$cpuAbi-release.apk"
        file_pattern="YTDLnis-*-beta-$cpuAbi-release.apk"
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r '.[].tag_name | sub("^v"; "") | select(contains("beta"))' | head -n 1 2>/dev/null)  # 2.0.0-beta
      fi
      assets="YTDLnis-$tag-$cpuAbi-release.apk"
      pkgApp="com.deniscerri.ytdl"
      activityApp="com.deniscerri.ytdl/.Default"
      dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    Spotify)
      appName="Spotify"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="spotjfy-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="spotjfy-beta-$cpuAbi-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.spotify.music"
      activityPatched="com.spotify.music/.MainActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    spotube)
      appName="spotube"
      owner="KRTirtho"
      repo="spotube"
      assets="Spotube-playstore-all-arch.aab"
      pkgPatched="oss.krtirtho.spotube.nightly"
      activityPatched="oss.krtirtho.spotube.nightly/com.ryanheise.audioservice.AudioServiceActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    TikTok)
      appName="TikTok"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="tiktok-revanced.apk"  # Use Stable release
      else
        assets="tiktok-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.zhiliaoapp.musically"
      activityPatched="com.zhiliaoapp.musically/com.ss.android.ugc.aweme.splash.SplashActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Google\ Photos)
      appName="Google Photos"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="gg-photos-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="gg-photos-$cpuAbi-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.google.android.apps.photos"
      activityPatched="com.google.android.apps.photos/.home.HomeActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Instagram)
      appName="Instagram"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="instagram-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="instagram-$cpuAbi-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.instagram.android"
      activityPatched="com.instagram.android/.activity.MainTabActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Facebook)
      appName="Facebook"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="facebook-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="facebook-$cpuAbi-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.facebook.katana"
      activityPatched="com.facebook.katana/.LoginActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Nobook)
      appName="Nobook"
      owner="ycngmn"
      repo="Nobook"
      file_pattern="Nobook_v*.apk"
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      assets="Nobook_$tag.apk"
      pkgApp="com.ycngmn.nobook"
      activityApp="com.ycngmn.nobook/.MainActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    FacebookMessenger)
      appName="Facebook Messenger"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="messenger-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="messenger-$cpuAbi-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.facebook.orca"
      activityPatched="com.facebook.orca/.auth.StartScreenActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Nagram)
      appName="Nagram"
      owner="NextAlone"
      repo="Nagram"
      name=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.name')
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      #regex="Nagram-v${name}-${cpuAbi}.apk"
      regex="Nagram-v.*.${tag}-$cpuAbi.apk"
      file_pattern="Nagram-v*-${cpuAbi}.apk"
      #assets="$regex"
      assets=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name')
      pkgApp="xyz.nextalone.nagram"
      activityApp="xyz.nextalone.nagram/org.telegram.messenger.DefaultIcon"
      dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    Nekogram)
      appName="Nekogram"
      owner="Nekogram"
      repo="Nekogram"
      regex="Nekogram-.*-.*-$cpuAbi.apk"
      file_pattern="Nekogram-*-*-$cpuAbi.apk"
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      assets=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name')
      pkgApp="tw.nekomimi.nekogram"
      activityApp="tw.nekomimi.nekogram/org.telegram.messenger.DefaultIcon"
      dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    Twitter)
      appName="Twitter"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="twitter-$cpuAbi-stable-piko.apk"  # Use Stable release
      else
        assets="twitter-$cpuAbi-beta-piko.apk"  # Use Beta release
      fi
      pkgPatched="com.twitter.android"
      activityPatched="com.twitter.android/.StartActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    piko\ Twitter)
      appName="piko Twitter"
      owner="crimera"
      repo="twitter-apk"
      regex="twitter-piko-material-you-v.*.apk"
      file_pattern="twitter-piko-material-you-v*.apk"
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      assets="twitter-piko-material-you-v$tag.apk"
      pkgApp="com.twitter.android"
      activityApp="com.twitter.android/.StartActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    Reddit)
      appName="Reddit"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="reddit-$cpuAbi-revanced-extended.apk"  # Use Stable release
      else
        assets="reddit-$cpuAbi-beta-revanced-extended.apk"  # Use Beta release
      fi
      pkgPatched="com.reddit.frontpage"
      activityPatched="com.reddit.frontpage/launcher.default"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Adobe\ Lightroom)
      appName="Adobe Lightroom"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="lightroom-revanced.apk"  # Use Stable release
      else
        assets="lightroom-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.adobe.lrmobile"
      activityPatched="com.adobe.lrmobile/.StorageCheckActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Photomath)
      appName="Photomath"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="photomath-revanced.apk"  # Use Stable release
      else
        assets="photomath-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.microblink.photomath"
      activityPatched="com.microblink.photomath/.main.activity.LauncherActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Duolingo)
      appName="Duolingo"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="duolingo-revanced.apk"  # Use Stable release
      else
        assets="duolingo-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.duolingo"
      activityPatched="com.duolingo/.app.LoginActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    RAR)
      appName="RAR"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="rar-revanced.apk"  # Use Stable release
      else
        assets="rar-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.rarlab.rar"
      activityPatched="com.rarlab.rar/.MainActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    CloudStream)
      appName="CloudStream"
      owner="recloudstream"
      repo="cloudstream"
      if [ "$FetchPreRelease" -eq 0 ]; then
        file_pattern="cloudstream-*.apk"
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
        assets=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.assets[] | .name')
        pkgApp="com.lagradost.cloudstream3"
        activityApp="com.lagradost.cloudstream3/.ui.account.AccountSelectActivity"
      else
        release="pre-release"
        file_pattern="app-prerelease-release.apk"
        tag="$release"
        assets="$file_pattern"
        pkgApp="com.lagradost.cloudstream3.prerelease"
        activityApp="com.lagradost.cloudstream3.prerelease/com.lagradost.cloudstream3.ui.account.AccountSelectActivity"
      fi
      dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    WeatherMaster)
      appName="WeatherMaster"
      owner="PranshulGG"
      repo="WeatherMaster"
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      regex="WeatherMaster.$tag.$cpuAbi.apk"
      file_pattern="$regex"
      assets="$regex"
      pkgApp="com.pranshulgg.weather_master_app"
      activityApp="com.pranshulgg.weather_master_app/.MainActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    Breezy\ Weather)
      appName="Breezy Weather"
      owner="breezy-weather"
      repo="$owner"
      if [ "$FetchPreRelease" -eq 0 ]; then
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
        regex="breezy-weather-$cpuAbi-${tag}_standard.apk"
        file_pattern="$regex"
        assets="$regex"
      else
        release=alpha
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r --arg release "$release" '.[].tag_name | select(contains($release))' | head -n 1)
        regex="breezy-weather-$cpuAbi-${tag}_standard.apk"
        file_pattern="$regex"
        assets="$regex"
      fi
      pkgApp="org.breezyweather"
      activityApp="org.breezyweather/.ui.main.MainActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    Twitch)
      appName="Twitch"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="twitch-revanced.apk"  # Use Stable release
      else
        assets="twitch-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="tv.twitch.android.app"
      activityPatched="tv.twitch.android.app/.core.LandingActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Tumblr)
      appName="Tumblr"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="tumblr-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="tumblr-$cpuAbi-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.tumblr"
      activityPatched="com.tumblr/.ui.activity.JumpoffActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Strava)
      appName="Strava"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="strava-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="strava-beta-$cpuAbi-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.strava"
      activityPatched="com.strava/.SplashActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    SoundCloud)
      appName="SoundCloud"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ "$FetchPreRelease" -eq 0 ]; then
        assets="soundcloud-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="soundcloud-$cpuAbi-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.soundcloud.android"
      activityPatched="com.soundcloud.android/.launcher.LauncherActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    NovaLauncher)
      appName="Nova Launcher"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      assets="nova-launcher-indrastorms.apk"
      pkgPatched="com.teslacoilsw.launcher"
      activityPatched="com.teslacoilsw.launcher/.NovaShortcutHandler"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Lawnchair)
      owner="LawnchairLauncher"
      appName="Lawnchair"
      repo="lawnchair"
      if [ "$FetchPreRelease" -eq 0 ]; then
        file_pattern="Lawnchair-*.apk"
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
        assets="Lawnchair-$tag.apk"
        pkgApp="ch.deletescape.lawnchair"
        activityApp="ch.deletescape.lawnchair/.Launcher"
      else
        release=nightly
        file_pattern="Lawnchair.Debug.*-dev.Nightly-CI_*.apk"
        tag="nightly"
        assets=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r --arg tag "$tag" '.[] | select(.tag_name == $tag) | .assets[] | .name')
        pkgApp="app.lawnchair.nightly"
        activityApp="app.lawnchair.nightly/app.lawnchair.LawnchairLauncher"
      fi
      dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      
      appName="Lawnicons"
      repo="lawnicons"
      if [ "$FetchPreRelease" -eq 0 ]; then
        file_pattern="Lawnicons.*.apk"
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
        assets=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.assets[] | .name')
      else
        release=nightly
        file_pattern="Lawnicons.Nightly.*.apk"
        tag="nightly"
        assets=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r --arg tag "$tag" '.[] | select(.tag_name == $tag) | .assets[] | .name')
      fi
      pkgApp="app.lawnchair.lawnicons"
      activityApp="app.lawnchair.lawnicons/.MainActivity"
      dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      
      appName="Lawnfeed"
      repo="lawnfeed"
      release=latest
      file_pattern="Lawnfeed.*.apk"
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
      assets=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.assets[] | .name')
      pkgApp="app.lawnchair.lawnfeed"
      activityApp=
      dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    Tasker)
      appName="Tasker"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      assets="tasker-indrastorms.apk"
      pkgPatched="net.dinglisch.android.taskerm"
      activityPatched="net.dinglisch.android.taskerm/.Tasker"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
  esac
done
###########################################################################################
