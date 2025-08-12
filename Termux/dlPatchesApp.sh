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
locale=$(getprop persist.sys.locale | cut -d'-' -f2 | cut -d']' -f1 | tr '[:upper:]' '[:lower:]')  # Get System Languages
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
dataJson="$Simplify/data.json"  # Data file to store simplify dlPatchesApp data
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

# --- Checking Android Version ---
if [ $Android -le 3 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by dlPatchesApp.${Reset}"
  return 1
fi

echo -e "$info ${Blue}Target device:${Reset} $Model"

# --- data function: store app data to data.json file ---
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

# --- dlPatchesApp function: download & install patched apps ---
dlPatchesApp() {
  local appName="${1}"
  local owner="$2"
  local repo="$3"
  local assets="$4"
  local apk_path="$SimplUsr/$assets"
  if [ "$repo" == "VancedMicroG" ]; then
    if [ $Android -eq 5 ]; then
      tag="v0.2.22.212658-212658001"
    elif [ "$Android" -ge "6" ]; then
      tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
    fi
    local url="https://github.com/$owner/$repo/releases/download/$tag/microg.apk"
  elif [ "$repo" == "Nobook" ] || [ "$repo" == "YTPro" ] || [ "$repo" == "FreeTubeAndroid" ] || [ "$repo" == "Tubular" ] || [ "$repo" == "InnerTune" ] || [ "$repo" == "Seal" ] || [ "$repo" == "ytdlnis" ]; then
    tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
    if [ "$repo" == "Nobook" ]; then
      assets="Nobook_$tag.apk"
    elif [ "$repo" == "YTPro" ]; then
      assets="YTPRO.apk"
    elif [ "$repo" == "FreeTubeAndroid" ]; then
      assets="freetube-$tag-Android.apk"
    elif [ "$repo" == "Tubular" ]; then
      assets="tubular_$tag.apk"
    elif [ "$repo" == "InnerTune" ]; then
      assets="InnerTune_${tag}_full_$cpuAbi.apk"
    elif [ "$repo" == "Seal" ] || [ "$repo" == "ytdlnis" ]; then
      if [ "$release" == "latest" ]; then
        tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name | sub("^v"; "")' 2>/dev/null)  # 1.13.1
        if [ "$repo" == "Seal" ]; then
          assets="Seal-$tag-$cpuAbi-release.apk"
        else
          assets="YTDLnis-$tag-$cpuAbi-release.apk"
        fi
      else
        if [ "$repo" == "Seal" ]; then
          tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r '.[].tag_name | sub("^v"; "") | select(contains("alpha"))' | head -n 1 2>/dev/null)  # 2.0.0-alpha.5
          assets="Seal-$tag-githubPreview-$cpuAbi-release.apk"
        else
          tag=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r '.[].tag_name | sub("^v"; "") | select(contains("beta"))' | head -n 1 2>/dev/null)  # 2.0.0-alpha.5
          assets="YTDLnis-$tag-$cpuAbi-release.apk"
        fi
      fi
    fi
    local url="https://github.com/$owner/$repo/releases/download/$tag/$assets"
  elif [ "$repo" == "spotube" ]; then
    local url="https://github.com/KRTirtho/spotube/releases/download/nightly/Spotube-android-all-arch.apk"
  else
    local url="https://github.com/$owner/$repo/releases/download/all/$assets"
  fi
  local pkgPatches="$5"
  local activityPatches="$6"
  
  
  # read the updated_at value for the specified asset
  if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
    app_updated_at=$(jq --arg assets "$assets" -r '.[] | select(.assets == $assets) | .updated_at' $dataJson)
    updated_at=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg assets "$assets" '.assets[] | select(.name == $assets) | .updated_at')
    if [ "$app_updated_at" == "$updated_at" ]; then
      echo -e "$notice ${Yellow}$appName Already up to date!${Reset}"
      dlIs="0"
    elif [ "$app_updated_at" != "$updated_at" ] || [ ! -f "$dataJson" ]; then
      dlIs="1"
      echo -e "$running Downloading $appName from GitHub.."
      bash $Simplify/dlGitHub.sh "$owner" "$repo" "latest" ".apk" "$SimplUsr" "$assets"
      echo -e "$info ${Green}Downloaded $appName APK found:${Reset} $apk_path"
    fi
  fi
  if [ $dlIs -eq 1 ] || [ "$repo" == "VancedMicroG" ] || [ "$repo" == "Nobook" ] || [ "$repo" == "YTPro" ] || [ "$repo" == "FreeTubeAndroid" ] || [ "$repo" == "Tubular" ] || [ "$repo" == "InnerTune" ] || [ "$repo" == "Seal" ] || [ "$repo" == "ytdlnis" ] || [ "$repo" == "spotube" ]; then
    version=$($HOME/aapt2 dump badging $apk_path 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
    echo -e "[?] ${Yellow}Do you want to install ${appName} $version app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched ${appName} apk.."
        bash $Simplify/apkInstall.sh "$apk_path" "$pkgPatches" "$activityPatches"
        data "$assets" "$updated_at" "$version"
        ;;
      n*|N*) echo -e "$notice ${appName} Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! ${appName} Installaion skipped." ;;
    esac
    
    echo -e "[?] ${Yellow}Do you want to Share ${appName} app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Sharing Patched ${appName} apk Link.."
        am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "$url" > /dev/null
        ;;
      n*|N*) echo -e "$notice ${appName} Sharing skipped!"
        ;;
      *) echo -e "$info Invalid choice! ${appName} Sharing skipped." ;;
    esac
  fi
}

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

if [ $Android -ge 10 ]; then
  apps=(
    Quit
    Vanced\ MicroG
    YouTube\ RV
    YouTube
    YTPro
    FreeTubeAndroid
    Tubular
    YouTube\ Music
    InnerTune
    Seal
    ytdlnis
    Spotify
    spotube
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    Nobook
    ${fbMessenger}
    Twitter
    Reddit
    Adobe\ Lightroom
    Photomath
    Duolingo
    RAR
    Twitch
    Tumblr
    Strava
    SoundCloud
    ${novaLauncher}
    Tasker
  )
elif [ $Android -eq 9 ]; then
  apps=(
    Quit
    Vanced\ MicroG
    YouTube\ RV
    YouTube
    YTPro
    FreeTubeAndroid
    Tubular
    YouTube\ Music
    InnerTune
    Seal
    ytdlnis
    Spotify
    spotube
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    Nobook
    ${fbMessenger}
    Twitter
    Reddit
    Adobe\ Lightroom
    Photomath
    RAR
    Twitch
    Tumblr
    Strava
    SoundCloud
    ${novaLauncher}
    Tasker
  )
elif [ $Android -eq 8 ]; then
  apps=(
    Quit
    Vanced\ MicroG
    YouTube\ RV
    YouTube
    YTPro
    FreeTubeAndroid
    Tubular
    YouTube\ Music
    InnerTune
    Seal
    ytdlnis
    Spotify
    spotube
    TikTok
    Google\ Photos
    $Instagram
    $Facebook
    Nobook
    ${fbMessenger}
    Twitter
    Adobe\ Lightroom
    Photomath
    RAR
    Twitch
    Tumblr
    Strava
    SoundCloud
    ${novaLauncher}
    Tasker
  )
elif [ $Android -eq 7 ]; then
  apps=(
    Quit
    Vanced\ MicroG
    YouTube
    YTPro
    FreeTubeAndroid
    Tubular
    YouTube\ Music
    InnerTune
    Seal
    ytdlnis
    Spotify
    spotube
    TikTok
    Google\ Photos
    $Instagram
    Nobook
    ${fbMessenger}
    Photomath
    RAR
    Twitch
    Tumblr
    Tasker
  )
elif [ $Android -eq 6 ]; then
  apps=(
    Quit
    Vanced\ MicroG
    YouTube
    YTPro
    Tubular
    YouTube\ Music
    TikTok
    Google\ Photos
    Nobook
    ${fbMessenger}
    Photomath
    RAR
    Twitch
    Tasker
  )
elif [ $Android -eq 5 ]; then
  apps=(
    Quit
    YTPro
    Tubular
    Vanced\ MicroG
    YouTube\ Music
    TikTok
    Google\ Photos
    Nobook
    ${fbMessenger}
    Photomath
    RAR
    Twitch
    Tasker
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
    if [ -n "${apps[$i]}" ] && [ "${apps[$i]}" != "null" ]; then
      printf "%d. %s\n" "$i" "${apps[$i]}"
    fi
  done

  # Ask for an index, showing the valid range
  max=$(( ${#apps[@]} - 1 ))  # highest legal index
  read -rp "Enter the index [0-${max}] of the apps you want to download: " idx

  # Validate and respond
  if [ $idx == 0 ]; then
    break  # break the while loop
  elif [[ $idx =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
    echo -e "$notice You chose: ${apps[$idx]}"
  else
    echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
  fi
  
  case ${apps[$idx]} in
    Vanced\ MicroG)
      appName="Vanced MicroG"
      repo="VancedMicroG"
      if [ $Android -eq 5 ]; then
        owner="TeamVanced"
        apk_path="$SimplUsr/microg-0.2.22.212658.apk"
        if [ ! -f "$apk_path" ]; then
          curl -sL "https://github.com/$owner/$repo/releases/download/v0.2.22.212658-212658001/microg.apk" --progress-bar -C - -o "$apk_path"
        fi
      elif [ "$Android" -ge "6" ]; then
        owner="inotia00"
        bash $Simplify/dlGitHub.sh "$owner" "$repo" "latest" ".apk" "$SimplUsr"
        apk_path=$(find "$SimplUsr" -type f -name "microg-*.apk" -print -quit)
      fi
      echo -e "$info ${Blue}VancedMicroG:${Reset} $apk_path"
      assets=$(basename "$apk_path")
      pkgPatches="com.mgoogle.android.gms"
      activityPatches="org.microg.gms.ui.SettingsActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="app.revanced.android.youtube"
      activityPatches="com.google.android.youtube/.app.honeycomb.Shell\$HomeActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
        assets="youtube-$cpuAbi-revanced-extended-android-6-7.apk" # Use YT Android 6-7 by kitadai31
      fi
      pkgPatches="app.rvx.android.youtube"
      activityPatches="com.google.android.youtube/.app.honeycomb.Shell\$HomeActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
    YTPro)
      appName="YTPro"
      owner="prateek-chaubey"
      repo="YTPro"
      bash $Simplify/dlGitHub.sh "$owner" "$repo" "latest" ".apk" "$SimplUsr"
      apk_path=$(find "$SimplUsr" -type f -name "YTPRO-*.apk" -print -quit)
      assets=$(basename "$apk_path")
      pkgPatches="com.google.android.youtube.pro"
      activityPatches="com.google.android.youtube.pro/.MainActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
    FreeTubeAndroid)
      appName="FreeTubeAndroid"
      owner="MarmadileManteater"
      repo="FreeTubeAndroid"
      bash $Simplify/dlGitHub.sh "$owner" "$repo" "latest" ".apk" "$SimplUsr"
      apk_path=$(find "$SimplUsr" -type f -name "freetube-*-Android.apk" -print -quit)
      assets=$(basename "$apk_path")
      pkgPatches="io.freetubeapp.freetube"
      activityPatches="io.freetubeapp.freetube/.MainActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
    Tubular)
      appName="Tubular"
      owner="polymorphicshade"
      repo="Tubular"
      bash $Simplify/dlGitHub.sh "$owner" "$repo" "latest" ".apk" "$SimplUsr"
      apk_path=$(find "$SimplUsr" -type f -name "tubular_v*.apk" -print -quit)
      assets=$(basename "$apk_path")
      pkgPatches="org.polymorphicshade.tubular"
      activityPatches="org.polymorphicshade.tubular/org.schabi.newpipe.MainActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="app.rvx.android.apps.youtube.music"
      activityPatches="com.google.android.apps.youtube.music/.activities.MusicActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
    InnerTune)
      appName="InnerTune"
      owner="z-huang"
      repo="InnerTune"
      regex="InnerTune_v.*_full_$cpuAbi.apk"
      bash $Simplify/dlGitHub.sh "$owner" "$repo" "latest" ".apk" "$SimplUsr" "$regex"
      apk_path=$(find "$SimplUsr" -type f -name "InnerTune_v*_full_$cpuAbi.apk" -print -quit)
      assets=$(basename "$apk_path")
      pkgPatches="com.zionhuang.music"
      activityPatches="com.zionhuang.music/.MainActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
    Seal)
      appName="Seal"
      owner="JunkFood02"
      repo="Seal"
      if [ "$release" == "latest" ]; then
        regex="Seal-.*-$cpuAbi-release.apk"
        bash $Simplify/dlGitHub.sh "$owner" "$repo" "$release" ".apk" "$SimplUsr" "$regex"
        apk_path=$(find "$SimplUsr" -type f -name "Seal-*-$cpuAbi-release.apk" -print -quit)
      else
        regex="Seal-.*-githubPreview-$cpuAbi-release.apk"
        bash $Simplify/dlGitHub.sh "$owner" "$repo" "$release" ".apk" "$SimplUsr" "$regex"
        apk_path=$(find "$SimplUsr" -type f -name "Seal-*-githubPreview-$cpuAbi-release.apk" -print -quit)
      fi
      assets=$(basename "$apk_path")
      pkgPatches="com.junkfood.seal"
      activityPatches="com.junkfood.seal/.MainActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
    ytdlnis)
      appName="ytdlnis"
      owner="deniscerri"
      repo="ytdlnis"
      if [ "$release" == "latest" ]; then
        regex="YTDLnis-.*-$cpuAbi-release.apk"
        bash $Simplify/dlGitHub.sh "$owner" "$repo" "$release" ".apk" "$SimplUsr" "$regex"
        apk_path=$(find "$SimplUsr" -type f -name "YTDLnis-*-$cpuAbi-release.apk" -print -quit)
      else
        regex="YTDLnis-.*-beta-$cpuAbi-release.apk"
        bash $Simplify/dlGitHub.sh "$owner" "$repo" "$release" ".apk" "$SimplUsr" "$regex"
        apk_path=$(find "$SimplUsr" -type f -name "YTDLnis-*-beta-$cpuAbi-release.apk" -print -quit)
      fi
      assets=$(basename "$apk_path")
      pkgPatches="com.deniscerri.ytdl"
      activityPatches="com.deniscerri.ytdl/.Default"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.spotify.music"
      activityPatches="com.spotify.music/.MainActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
    spotube)
      appName="spotube"
      owner="KRTirtho"
      repo="spotube"
      url="https://github.com/KRTirtho/spotube/releases/download/nightly/Spotube-playstore-all-arch.aab"
      assets_name="Spotube-playstore-all-arch.aab"
      aab_path="$SimplUsr/$assets_name"
      aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$assets_name" -d "$SimplUsr" "$url"
      bundletoolJar=$(find "$Simplify" -type f -name "bundletool-all-*.jar" -print -quit 2>/dev/null)
      if [ ! -f "$bundletoolJar" ]; then
        bash $Simplify/dlGitHub.sh "google" "bundletool" "latest" ".jar" "$Simplify"
        bundletoolJar=$(find "$Simplify" -type f -name "bundletool-all-*.jar" -print -quit)
      fi
      apks_path="$SimplUsr/Spotube-playstore-all-arch.apks"
      $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $bundletoolJar build-apks --bundle=$aab_path --output=$apks_path --aapt2=~/aapt2
      rm "$aab_path"
      if [ $cpuAbi == arm64-v8a ]; then
        cpuAbi=arm64_v8a
      elif [ $cpuAbi == armeabi-v7a ]; then
        cpuAbi=armeabi_v7a
      fi
      mkdir -p "$SimplUsr/Spotube-playstore-all-arch"
      pv "$apks_path" | bsdtar -xf - -C "$SimplUsr/Spotube-playstore-all-arch" --include "splits/base-$locale.apk" "splits/base-$cpuAbi.apk" "splits/base-$lcd_dpi.apk"
      cpuAbi=$(getprop ro.product.cpu.abi)
      rm "$apks_path"
      bash $Simplify/dlGitHub.sh "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
      APKEditor=$(find "$Simplify" -type f -name "APKEditor-*.jar" -print -quit)
      $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $APKEditor m -i "$SimplUsr/Spotube-playstore-all-arch" -o "$SimplUsr/Spotube-playstore-all-arch.apk"
      rm -rf "$SimplUsr/Spotube-playstore-all-arch"
      apk_path="$SimplUsr/Spotube-playstore-all-arch-signed.apk"
      $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar sign --ks $Simplify/ks.keystore --ks-pass pass:123456 --ks-key-alias ReVancedKey --key-pass pass:123456 --out "$apk_path" "$SimplUsr/Spotube-playstore-all-arch.apk"
      rm "$SimplUsr/Spotube-playstore-all-arch.apk" && rm rm "$SimplUsr/Spotube-playstore-all-arch.apk.idsig"
      assets=$(basename "$apk_path")
      pkgPatches="oss.krtirtho.spotube.nightly"
      activityPatches="oss.krtirtho.spotube.nightly/com.ryanheise.audioservice.AudioServiceActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.zhiliaoapp.musically"
      activityPatches="com.zhiliaoapp.musically/com.ss.android.ugc.aweme.splash.SplashActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.google.android.apps.photos"
      activityPatches="com.google.android.apps.photos/.home.HomeActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.instagram.android"
      activityPatches="com.instagram.android/.activity.MainTabActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.facebook.katana"
      activityPatches="com.facebook.katana/.LoginActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
    Nobook)
      appName="Nobook"
      owner="ycngmn"
      repo="Nobook"
      bash $Simplify/dlGitHub.sh "$owner" "$repo" "latest" ".apk" "$SimplUsr"
      apk_path=$(find "$SimplUsr" -type f -name "Nobook_v*.apk" -print -quit)
      assets=$(basename "$apk_path")
      pkgPatches="com.ycngmn.nobook"
      activityPatches="com.ycngmn.nobook/.MainActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.facebook.orca"
      activityPatches="com.facebook.orca/.auth.StartScreenActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.twitter.android"
      activityPatches="com.twitter.android/.StartActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.reddit.frontpage"
      activityPatches="com.reddit.frontpage/launcher.default"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.adobe.lrmobile"
      activityPatches="com.adobe.lrmobile/.StorageCheckActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.microblink.photomath"
      activityPatches="com.microblink.photomath/.main.activity.LauncherActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.duolingo"
      activityPatches="com.duolingo/.app.LoginActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.rarlab.rar"
      activityPatches="com.rarlab.rar/.MainActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="tv.twitch.android.app"
      activityPatches="tv.twitch.android.app/.core.LandingActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.tumblr"
      activityPatches="com.tumblr/.ui.activity.JumpoffActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.strava"
      activityPatches="com.strava/.SplashActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
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
      pkgPatches="com.soundcloud.android"
      activityPatches="com.soundcloud.android/.launcher.LauncherActivity"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
    NovaLauncher)
      appName="Nova Launcher"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      assets="nova-launcher-indrastorms.apk"
      pkgPatches="com.teslacoilsw.launcher"
      activityPatches="com.teslacoilsw.launcher/.NovaShortcutHandler"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
    Tasker)
      appName="Tasker"
      owner="FiorenMas"
      repo="Revanced-And-Revanced-Extended-Non-Root"
      assets="tasker-indrastorms.apk"
      pkgPatches="net.dinglisch.android.taskerm"
      activityPatches="net.dinglisch.android.taskerm/.Tasker"
      dlPatchesApp "${appName}" "$owner" "$repo" "$assets" "$pkgPatches" "$activityPatches"
      ;;
  esac
done
###########################################################################################
