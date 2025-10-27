#!/usr/bin/bash

echo -e "$info ${Blue}Target device:${Reset} $Model"

cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
locale=$(getprop persist.sys.locale | cut -d'-' -f1)  # Get System Languages
[ -z $locale ] && locale=$(getprop ro.product.locale | cut -d'-' -f1)  # Get Languages
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
dataJson="$Simplify/data.json"  # Data file to store simplify dlPatchedApp data
  # Create empty json file if it doesn't exist
  [ ! -f "$dataJson" ] && jq -n '[]' > "$dataJson"
[ $FetchPreRelease -eq 1 ] && release="pre" || release="latest"

# --- function to store app metadata to data.json file ---
data() {
  local assets="$1"
  local updated_at="$2"
  local version="$3"
  
  
  # Create empty json file if it doesn't exist
  [ ! -f "$dataJson" ] && jq -n '[]' > "$dataJson"
  
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
    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install ${appName} $version app?" "buttons" && opt=Yes || opt=No
    case $opt in
      y*|Y*|"")
        if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
          echo -e "$running Please Wait !! Installing Patched ${appName} apk.."
        else
          echo -e "$running Please Wait !! Installing ${appName} apk.."
        fi
        if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ] || { [ "$repo" == "spotube" ] && [ -n "$updated_at" ]; }; then
          bash $Simplify/apkInstall.sh "$apk_path" "$activityPatched"
          data "$assets" "$updated_at" "$version"
        else
          bash $Simplify/apkInstall.sh "$apk_path" "$activityApp"
          if [ "$appName" == "CloudStream" ]; then
            if jq --arg appName "$appName" 'any(.[]; .assets == $appName)' "$dataJson" | grep -q false; then
              termux-open-url "https://rentry.co/cs3-repos"
            fi
          elif [ "$appName" == "YTPro" ] || [ "$appName" == "Nobook" ]; then
            termux-open-url "https://play.google.com/store/apps/details?id=com.google.android.webview"
          fi
          data "$appName" "$updated_at" "$tag"
        fi
        if [ $su -eq 1 ] || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
          rm -f "$apk_path"
        fi
        ;;
      n*|N*) echo -e "$notice ${appName} Installaion skipped!" ;;
    esac
    
    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share ${appName} app?" "buttons" "1" && opt=Yes || opt=No
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
    esac
}

dlGitLab() {
  local owner=$1
  local repo=$2
  local ext=$3
  local dir=$4
  local regex=$5

  if [ -n "$regex" ]; then
    assets="$regex"
  elif [ -n "$ext" ] && [ -z "$assets" ]; then
    assets=".*${ext}$"  # Simplified assets pattern
  fi
  
  dl() {
    local dlUtility=$1
    local url=$2
    local output=$3
    
    assets_name=$(basename "$output")
    echo -e "$running Downloading $assets_name.."
    
    while true; do
      if [ "$dlUtility" == "curl" ]; then
        curl -L -C - --progress-bar -o "$output" "$url"
        exit_status=$?
      elif [ "$dlUtility" == "aria2" ]; then
        aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$(basename "$output")" -d "$(dirname "$output")" "$url"
        exit_status=$?
        echo  # White Space
      fi
      if [ $exit_status -eq 0 ]; then
        break  # Exit loop on success
      else
        echo -e "${bad} ${Red}Download failed! retrying in 5 seconds..${Reset}"
        sleep 5  # Wait 5 seconds
      fi
    done
  }
  
  glApiResponseJson=$(curl -sL "https://gitlab.com/api/v4/projects/${owner}%2F${repo}/releases")
  release_title=$(jq -r '.[0].name' <<< "$glApiResponseJson"); echo -e "$info release_title: $release_title"
  tag=$(jq -r '.[0].tag_name' <<< "$glApiResponseJson"); echo -e "$info tag: $tag"
  #assets_name=$(jq -r '.[0].assets.links[].name' <<< "$glApiResponseJson"); echo "assets_name: $assets_name"
  #assets_url=$(jq -r '.[0].assets.links[].url' <<< "$glApiResponseJson"); echo "assets_url: $assets_url"
  
  assets_name=$(jq -r --arg assets "$assets" '.[]?.assets.links[]?.name | select(test($assets))' <<< "$glApiResponseJson" | head -1)
  assets_url=$(jq -r --arg assets "$assets" '.[]?.assets.links[]?.url | select(test($assets))' <<< "$glApiResponseJson" | head -1)
  assets_url_basename=$(basename "$assets_url" 2>/dev/null)
  [ "$assets_name" != "$assets_url_basename" ] && assets_name="$assets_url_basename"
  echo -e "assets_name: $assets_name\n$info assets_url: $assets_url"
  
  assets_name_pattern=$(echo "$assets_name" | sed "s/$tag/*/g"); echo -e "$info assets_name_pattern: $assets_name_pattern"
  findFile=$(find "$dir" -type f -name "$assets_name_pattern" -print -quit)
  [ -f "$findFile" ] && file_basename=$(basename "$findFile" 2>/dev/null)
  if [ -n "$file_basename" ]; then
    [ "$assets_name" != "$file_basename" ] && { echo -e "$notice diffs: $assets_name ~ $file_basename"; rm -f "$findFile"; }
  fi
  
  [ "$repo" == "AuroraStore" ] && dl "curl" "$assets_url" "$dir/$assets_name"
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
  if [ "$repo" == "spotube" ]; then
    local url="https://github.com/$owner/$repo/releases/download/$tag/Spotube-android-all-arch.apk"
    assets="$file_pattern"
  elif [ "$repo" == "AuroraStore" ]; then
    url="$assets_url"
  else
    local url="https://github.com/$owner/$repo/releases/download/$tag/$assets"
  fi
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
    if [ "$repo" == "spotube" ]; then
      # Download spotube .aab file
      echo -e "$running Downloading $appName.."
      bash $Simplify/dlGitHub.sh "$owner" "$repo" "latest" ".aab" "$SimplUsr" "$regex"
      aab_path="$SimplUsr/$regex"
      apk_path="$SimplUsr/$file_pattern"
      termux-wake-lock
      build_apks "$aab_path"  # build apk from aab by calling build_apks function
      termux-wake-unlock
    elif [ "$repo" == "AuroraStore" ]; then
      echo -e "$running Downloading $appName from GitLab.."
      dlGitLab "$owner" "$repo" ".apk" "$SimplUsr" "$regex"
      apk_path=$(find "$SimplUsr" -type f -name "$file_pattern" -print -quit)
    else
      echo -e "$running Downloading $appName from GitHub.."
      bash $Simplify/dlGitHub.sh "$owner" "$repo" "$release" ".apk" "$SimplUsr" "$regex"
      apk_path=$(find "$SimplUsr" -type f -name "$file_pattern" -print -quit)
    fi
    if [ -f "$apk_path" ]; then
      echo -e "$info ${Green}Downloaded $appName APK found:${Reset} $apk_path"
      version=$($HOME/aapt2 dump badging $apk_path 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
      appInstall
    fi
  fi
}

build_apks() {
  aab_path=$1  # aab file path
  filename_wo_ext="${aab_path%.*}"  # remove .* from file | aab filename w/o extension (.aab)
  apks_path="$filename_wo_ext.apks"
  apk_path="$filename_wo_ext.apk"
  singed_apk_path="$filename_wo_ext-signed.apk"
  if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
    cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
  fi


  # Download bundletool
  bash $Simplify/dlGitHub.sh "google" "bundletool" "latest" ".jar" "$Simplify"
  bundletoolJar=$(find "$Simplify" -type f -name "bundletool-all-*.jar" -print -quit)

  # Build apks from aab using bundletool
  echo -e "$running Build apks from aab.."
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $bundletoolJar build-apks --bundle=$aab_path --output=$apks_path --aapt2=~/aapt2 2>&1 | grep -v "WARNING: The APKs won't be signed"
  if [ $? -eq 0 ] || [ -f "$apks_path" ]; then
    echo "Success"
    rm -f "$aab_path"  # remove aab file
  fi

  if [ "$cpuAbi" == "arm64-v8a" ]; then
    cpuAbi="arm64_v8a"
  elif [ "$cpuAbi" == "armeabi-v7a" ]; then
    cpuAbi="armeabi_v7a"
  fi
  # Extract apks file
  mkdir -p "$filename_wo_ext"
  echo -e "$running Extracting apks.."
  pv "$apks_path" | bsdtar -xf - -C "$filename_wo_ext" --include "splits/base-master.apk" --include "splits/base-$cpuAbi.apk" --include "splits/base-${lcd_dpi}.apk" --include "splits/base-$locale.apk"
  if [ $? -eq 0 ]; then
    rm -f "$apks_path"  # rm apks file
  fi
  cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch

  # Download APKEditor
  bash $Simplify/dlGitHub.sh "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
  APKEditor=$(find "$Simplify" -type f -name "APKEditor-*.jar" -print -quit)
  
  # Merge splits apks to standalone apk using APKEditor
  echo -e "$running Merge splits apks to standalone apk.."
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $APKEditor m -i "$filename_wo_ext/splits" -o "$apk_path"
  rm -rf "$filename_wo_ext"

  # Signing apk
  echo -e "$running Signing apk.."
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar sign --ks $Simplify/ks.keystore --ks-pass pass:123456 --ks-key-alias ReVancedKey --key-pass pass:123456 --out "$singed_apk_path" "$apk_path"
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -printcert -jarfile "${singed_apk_path}" | grep -oP 'Owner: \K.*' 2>/dev/null
  if [ $? -ne 0 ]; then
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar verify --print-certs "${signed_apk_path}" | grep -oP 'Signer #1 certificate DN: \K.*'
  fi
  
  # Rename file using move command
  if [ -f "$singed_apk_path" ]; then
    rm -f "$apk_path" && rm -f "${singed_apk_path}.idsig"  # remove file
    mv "$singed_apk_path" "$apk_path"
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
        # Download spotube .aab file
        echo -e "$running Downloading $appName.."
        bash $Simplify/dlGitHub.sh "$owner" "$repo" "nightly" ".aab" "$SimplUsr" "Spotube-playstore-all-arch.aab"
        assets_name="Spotube-playstore-all-arch.aab"
        aab_path="$SimplUsr/$assets_name"
        filename_wo_ext="${aab_path%.*}"
        apk_path="$filename_wo_ext.apk"
        assets=$(basename "$apk_path")
        termux-wake-lock
        build_apks "$aab_path"  # build apk from aab by calling build_apks function
        termux-wake-unlock
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
  amazonPrimeVideo="AmazonPrimeVideo"
fi

[[ $Android -ge 11  &&  ( "$cpuAbi" == "arm64-v8a" || "$cpuAbi" == "armeabi-v7a" ) ]] && Facebook="Facebook"

# --- Arrays of apps list that required specific android version ---
if [ $Android -ge 10 ]; then
  apps=(
    deGoogle
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
    YTDLnis
    RetroMusicPlayer
    #Spotify
    Spotube
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    Nobook
    ${fbMessenger}
    Threads
    Nagram
    Nekogram
    Twitter
    piko\ Twitter
    Reddit
    Adobe\ Lightroom
    Photomath
    Duolingo
    RAR
    ${amazonPrimeVideo}
    CloudStream
    Breezy\ Weather
    WeatherMaster
    Twitch
    Tumblr
    Strava
    SoundCloud
    ${novaLauncher}
    Lawnchair
    Solid\ Explorer
    Proton\ Mail
    Crunchyroll
    Tasker
  )
elif [ $Android -eq 9 ]; then
  apps=(
    deGoogle
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
    YTDLnis
    RetroMusicPlayer
    #Spotify
    Spotube
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    Nobook
    ${fbMessenger}
    Threads
    Nagram
    Nekogram
    Twitter
    piko\ Twitter
    Reddit
    Adobe\ Lightroom
    Photomath
    RAR
    ${amazonPrimeVideo}
    CloudStream
    Breezy\ Weather
    WeatherMaster
    Twitch
    Tumblr
    Strava
    SoundCloud
    ${novaLauncher}
    Lawnchair
    Solid\ Explorer
    Proton\ Mail
    Crunchyroll
    Tasker
  )
elif [ $Android -eq 8 ]; then
  apps=(
    deGoogle
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
    YTDLnis
    RetroMusicPlayer
    #Spotify
    Spotube
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    Nobook
    ${fbMessenger}
    Threads
    Nagram
    Nekogram
    Twitter
    piko\ Twitter
    Adobe\ Lightroom
    Photomath
    RAR
    ${amazonPrimeVideo}
    CloudStream
    Breezy\ Weather
    WeatherMaster
    Twitch
    Tumblr
    Strava
    SoundCloud
    ${novaLauncher}
    Lawnchair
    Solid\ Explorer
    Crunchyroll
    Tasker
  )
elif [ $Android -eq 7 ]; then
  apps=(
    deGoogle
    Vanced\ MicroG
    ReVanced\ GmsCore
    YouTube
    YTPro
    FreeTubeAndroid
    Tubular
    YouTube\ Music
    InnerTune
    Seal
    YTDLnis
    RetroMusicPlayer
    #Spotify
    Spotube
    TikTok
    Google\ Photos
    $Instagram
    Nobook
    ${fbMessenger}
    Nagram
    Nekogram
    Photomath
    RAR
    ${amazonPrimeVideo}
    CloudStream
    WeatherMaster
    Twitch
    Tumblr
    Solid\ Explorer
    Tasker
  )
elif [ $Android -eq 6 ]; then
  apps=(
    deGoogle
    Vanced\ MicroG
    ReVanced\ GmsCore
    YouTube
    YTPro
    Tubular
    YouTube\ Music
    RetroMusicPlayer
    TikTok
    Google\ Photos
    Nobook
    ${fbMessenger}
    Nagram
    Nekogram
    Photomath
    RAR
    ${amazonPrimeVideo}
    CloudStream
    WeatherMaster
    Twitch
    Solid\ Explorer
    Tasker
  )
elif [ $Android -eq 5 ]; then
  apps=(
    deGoogle
    YTPro
    Tubular
    Vanced\ MicroG
    ReVanced\ GmsCore
    YouTube\ Music
    RetroMusicPlayer
    TikTok
    Google\ Photos
    Nobook
    ${fbMessenger}
    Nagram
    Nekogram
    Photomath
    RAR
    ${amazonPrimeVideo}
    CloudStream
    WeatherMaster
    Twitch
    Solid\ Explorer
    Tasker
  )
elif [ $Android -eq 4 ]; then
  apps=(
    deGoogle
    ReVanced\ GmsCore
    RAR
    Solid\ Explorer
  )
fi

while true; do
  buttons=("<Select>" "<Back>"); if menu "apps" "buttons" "22"; then selected="${apps[$selected]}"; else break; fi
  
  release=latest
  # main conditional control flow
  case "$selected" in
    deGoogle)
      apps_list=(
        Play\ Store\ →\ AuroraStore
        Play\ Store\ →\ Droid-ify
        Play\ Store\ →\ Obtainium
        Google\ →\ DuckDuckGo
        Gemini\ →\ RikkaHub
        Google\ Photos\ →\ Ente\ Photos
        Google\ Photos\ →\ VLC
        Snapseed\ →\ Image\ Toolbox
        YouTube\ →\ FreeTube
        Google\ Meet\ →\ Jitsi\ Meet
        Google\ Home\ →\ Home\ Assistant
        Google\ Gallery\ →\ Gallery
        Chrome\ →\ Chromium
        Chrome\ →\ Firefox
        Google\ Authenticator\ →\ Ente\ Auth
        Google\ Calculator\ →\ Multi-Calculator
        Google\ Drive\ →\ Nextcloud
        Google\ Drive\ →\ Microsoft\ OneDrive
        Google\ Drive\ →\ Proton\ Drive
        Google\ Keep\ →\ Notesnook
        Google\ Maps\ →\ OsmAnd
        Google\ TV\ →\ CloudStream
        Gboard\ →\ FlorisBoard
        Google\ Chat\ →\ Telegram
        Google\ Chat\ →\ Session
        Google\ Password\ Manager\ →\ Bitwarden
        Google\ Tasks\ →\ Microsoft\ To\ Do
        Google\ News\ →\ Feeder
        Google\ Wallpapers\ →\ Starth\ Bing\ Wallpaper
        Gmail\ →\ Proton\ Mail
        Gmail\ →\ Thunderbird
        YouTube\ Music\ →\ Metrolist
        YouTube\ Music\ →\ PixelPlay
        Pixel\ Screenshots\ →\ Shots\ Studio
        Google\ Weather\ →\ Breezy\ Weather
        VPN\ by\ Google\ One\ →\ 1.1.1.1\ +\ WARP
        VPN\ by\ Google\ One\ →\ WireGuard\ +\ WireGuard\ config\ by\ Proton\ VPN
        VPN\ by\ Google\ One\ →\ Tor\ VPN
      )
      while true; do
        buttons=("<Select>" "<Back>"); if menu "apps_list" "buttons" "22"; then selected="${apps_list[$selected]}"; else break; fi
        case "$selected" in
          Play\ Store\ →\ AuroraStore)
            appName="AuroraStore"
            owner="AuroraOSS"
            repo="AuroraStore"
            regex="AuroraStore-[\d\.]+"
            file_pattern="AuroraStore-*.apk"
            glApiResponseJson=$(curl -sL "https://gitlab.com/api/v4/projects/${owner}%2F${repo}/releases")
            assets_url=$(jq -r --arg regex "$regex" '.[]?.assets.links[]?.url | select(test($regex))' <<< "$glApiResponseJson" | head -1)
            tag=$(jq -r '.[0].tag_name' <<< "$glApiResponseJson")
            assets="AuroraStore-$tag.apk"
            pkgApp="com.aurora.store"
            activityApp="com.aurora.store/.MainActivity"
            dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
            ;;
          Play\ Store\ →\ Droid-ify)
            appName="Droid-ify"
            owner="$appName"
            repo="client"
            file_pattern="$owner-*.apk"
            tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
            assets="app-release.apk"
            pkgApp="com.looker.droidify"
            activityApp="com.looker.droidify/.MainActivity"
            dlApp "${appName}" "$owner" "$repo" "$release" "" "$file_pattern" "$tag" "$assets" "$pkgApp" "$activityApp"
            ;;
          Play\ Store\ →\ Obtainium)
            appName="Obtainium"
            owner="ImranR98"
            repo="$appName"
            regex="app-$cpuAbi-release.apk"
            file_pattern="$repo-*-$cpuAbi.apk"
            tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
            pkgApp="dev.imranr.obtainium"
            activityApp="dev.imranr.obtainium/.MainActivity"
            dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$regex" "$pkgApp" "$activityApp"
            ;;
          Google\ →\ DuckDuckGo) termux-open-url "https://play.google.com/store/apps/details?id=com.duckduckgo.mobile.android" ;;
          Gemini\ →\ RikkaHub) termux-open-url "https://play.google.com/store/apps/details?id=me.rerere.rikkahub" ;;
          Google\ Photos\ →\ Ente\ Photos) termux-open-url "https://play.google.com/store/apps/details?id=io.ente.photos" ;;
          Google\ Photos\ →\ VLC) termux-open-url "https://play.google.com/store/apps/details?id=org.videolan.vlc" ;;
          Snapseed\ →\ Image\ Toolbox) termux-open-url "https://play.google.com/store/apps/details?id=ru.tech.imageresizershrinker" ;;
          YouTube\ →\ FreeTube)
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
          Google\ Meet\ →\ Jitsi\ Meet) termux-open-url "https://play.google.com/store/apps/details?id=org.jitsi.meet" ;;
          Google\ Home\ →\ Home\ Assistant) termux-open-url "https://play.google.com/store/apps/details?id=io.homeassistant.companion.android" ;;
          Google\ Gallery\ →\ Gallery)
            appName="Gallery"
            owner="IacobIonut01"
            repo="$appName"
            file_pattern="Gallery-*-*-$cpuAbi.apk"
            ghApiResponseJson=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest")
            tag=$(jq -r '.tag_name' <<< "$ghApiResponseJson")
            name=$(jq -r '.name' <<< "$ghApiResponseJson" | sed 's/ Release$//')
            regex="$repo-$name-$cpuAbi.apk"
            pkgApp="com.dot.gallery"
            activityApp="com.dot.gallery/.feature_node.presentation.main.MainActivity"
            dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "$tag" "$regex" "$pkgApp" "$activityApp"
            ;;
          Chrome\ →\ Chromium) termux-open-url "https://github.com/arghya339/crdl" ;;
          Chrome\ →\ Firefox) termux-open-url "https://play.google.com/store/apps/details?id=org.mozilla.firefox" ;;
          Google\ Authenticator\ →\ Ente\ Auth) termux-open-url "https://play.google.com/store/apps/details?id=io.ente.auth" ;;
          Google\ Calculator\ →\ Multi-Calculator) termux-open-url "https://play.google.com/store/apps/details?id=com.yangdai.calc" ;;
          Google\ Drive\ →\ Nextcloud) termux-open-url "https://play.google.com/store/apps/details?id=com.nextcloud.client" ;;
          Google\ Drive\ →\ Microsoft\ OneDrive) termux-open-url "https://play.google.com/store/apps/details?id=com.microsoft.skydrive" ;;
          Google\ Drive\ →\ Proton\ Drive) termux-open-url "https://play.google.com/store/apps/details?id=me.proton.android.drive" ;;
          Google\ Keep\ →\ Notesnook) termux-open-url "https://play.google.com/store/apps/details?id=com.streetwriters.notesnook" ;;
          Google\ Maps\ →\ OsmAnd) termux-open-url "https://play.google.com/store/apps/details?id=net.osmand" ;;
          Google\ TV\ →\ CloudStream)
            appName="CloudStream"
            owner="recloudstream"
            repo="cloudstream"
            if [ $FetchPreRelease -eq 0 ]; then
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
          Gboard\ →\ FlorisBoard) termux-open-url "https://github.com/florisboard/florisboard/releases" ;;  # Implement later
          Google\ Chat\ →\ Telegram) termux-open-url "https://play.google.com/store/apps/details?id=org.telegram.messenger" ;;
          Google\ Chat\ →\ Session) termux-open-url "https://play.google.com/store/apps/details?id=network.loki.messenger" ;;
          Google\ Password\ Manager\ →\ Bitwarden) termux-open-url "https://play.google.com/store/apps/details?id=com.x8bit.bitwarden" ;;
          Google\ Tasks\ →\ Microsoft\ To\ Do) termux-open-url "https://play.google.com/store/apps/details?id=com.microsoft.todos" ;;
          Google\ News\ →\ Feeder) termux-open-url "https://play.google.com/store/apps/details?id=com.nononsenseapps.feeder.play" ;;
          Google\ Wallpapers\ →\ Starth\ Bing\ Wallpaper) termux-open-url "https://play.google.com/store/apps/details?id=me.liaoheng.wallpaper" ;;
          Gmail\ →\ Proton\ Mail) termux-open-url "https://play.google.com/store/apps/details?id=ch.protonmail.android" ;;
          Gmail\ →\ Thunderbird) termux-open-url "https://play.google.com/store/apps/details?id=net.thunderbird.android" ;;
          YouTube\ Music\ →\ Metrolist) termux-open-url "https://github.com/mostafaalagamy/Metrolist/releases" ;;  # Implement later
          YouTube\ Music\ →\ PixelPlay) termux-open-url "https://github.com/theovilardo/PixelPlay/releases" ;;  # Implement later
          Pixel\ Screenshots\ →\ Shots\ Studio) termux-open-url "https://github.com/AnsahMohammad/shots-studio/releases" ;;  # Implement later
          Google\ Weather\ →\ Breezy\ Weather)
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
          VPN\ by\ Google\ One\ →\ 1.1.1.1\ +\ WARP) termux-open-url "https://play.google.com/store/apps/details?id=com.cloudflare.onedotonedotonedotone" ;;
          VPN\ by\ Google\ One\ →\ WireGuard\ +\ WireGuard\ config\ by\ Proton\ VPN) termux-open-url "https://play.google.com/store/apps/details?id=com.wireguard.android" && sleep 0.5 && termux-open-url "https://account.protonvpn.com/downloads" ;;
          VPN\ by\ Google\ One\ →\ Tor\ VPN) termux-open-url "https://play.google.com/store/apps/details?id=org.torproject.vpn" ;;
        esac
      done
      ;;
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
      if [ $FetchPreRelease -eq 0 ]; then
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
          if [ $FetchPreRelease -eq 0 ]; then
            assets="youtube-$cpuAbi-revanced-extended.apk"  # Use Stable release
          else
            assets="youtube-beta-$cpuAbi-revanced-extended.apk"  # Use Beta release
          fi
        else
          if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "v$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    YTDLnis)
      appName="YTDLnis"
      owner="deniscerri"
      repo="ytdlnis"
      if [ $FetchPreRelease -eq 0 ]; then
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
      dlApp "${appName}" "$owner" "$repo" "$release" "$regex" "$file_pattern" "v$tag" "$assets" "$pkgApp" "$activityApp"
      ;;
    RetroMusicPlayer) termux-open-url "https://play.google.com/store/apps/details?id=code.name.monkey.retromusic" ;;
    Spotify)
      appName="Spotify"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ $FetchPreRelease -eq 0 ]; then
        assets="spotjfy-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="spotjfy-beta-$cpuAbi-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.spotify.music"
      activityPatched="com.spotify.music/.MainActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Spotube)
      appName="Spotube"
      owner="KRTirtho"
      repo="spotube"
      assets="Spotube-playstore-all-arch.aab"
      if [ $FetchPreRelease -eq 0 ]; then
        regex="Spotube-playstore-all-arch.aab"
        file_pattern="Spotube-playstore-all-arch.apk"
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name | sub("^v"; "")' 2>/dev/null)  # 5.0.0
        pkgApp="oss.krtirtho.spotube"
        activityApp="$pkgApp/com.ryanheise.audioservice.AudioServiceActivity"
        dlApp "${appName}" "$owner" "$repo" "" "$regex" "$file_pattern" "v$tag" "$regex" "$pkgApp" "$activityApp"
      else
        pkgPatched="oss.krtirtho.spotube.nightly"
        activityPatched="$pkgPatched/com.ryanheise.audioservice.AudioServiceActivity"
        dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      fi
      ;;
    TikTok)
      appName="TikTok"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
        assets="messenger-$cpuAbi-revanced.apk"  # Use Stable release
      else
        assets="messenger-$cpuAbi-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.facebook.orca"
      activityPatched="com.facebook.orca/.auth.StartScreenActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Threads)
      appName="Threads"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      [ "$FetchPreRelease" -eq 0 ] && assets="threads-$cpuAbi-revanced.apk" || assets="threads-beta-$cpuAbi-revanced.apk"
      pkgPatched="com.instagram.barcelona"
      activityPatched="com.instagram.barcelona/.mainactivity.BarcelonaActivity"
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
        assets="rar-revanced.apk"  # Use Stable release
      else
        assets="rar-beta-revanced.apk"  # Use Beta release
      fi
      pkgPatched="com.rarlab.rar"
      activityPatched="com.rarlab.rar/.MainActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    AmazonPrimeVideo)
      appName="Amazon Prime Video"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      [ $FetchPreRelease -eq 0 ] && assets="prime-video-$cpuAbi-revanced.apk" || assets="prime-video-beta-$cpuAbi-revanced.apk"
      pkgPatched="com.amazon.avod.thirdpartyclient"
      activityPatched="com.amazon.avod.thirdpartyclient/.LauncherActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    CloudStream)
      appName="CloudStream"
      owner="recloudstream"
      repo="cloudstream"
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
      if [ $FetchPreRelease -eq 0 ]; then
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
    Solid\ Explorer)
      appName="Solid Explorer"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      assets="solid-explorer-$cpuAbi-scrazzz.apk"
      pkgPatched="pl.solidexplorer2"
      activityPatched="pl.solidexplorer2/pl.solidexplorer.SolidExplorer"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Proton\ Mail)
      appName="Proton Mail"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      [ "$FetchPreRelease" -eq 0 ] && assets="protonmail-revanced.apk" || assets="protonmail-beta-revanced.apk"
      pkgPatched="ch.protonmail.android"
      activityPatched="ch.protonmail.android/.MainActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
      ;;
    Crunchyroll)
      appName="Crunchyroll"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      [ "$FetchPreRelease" -eq 0 ] && assets="crunchyroll-revanced.apk" || assets="crunchyroll-beta-revanced.apk"
      pkgPatched="com.crunchyroll.crunchyroid"
      activityPatched="com.crunchyroll.crunchyroid/com.ellation.crunchyroll.presentation.startup.StartupActivity"
      dlPatchedApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatched" "$activityPatched"
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
