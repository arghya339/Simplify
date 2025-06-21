#!/usr/bin/bash

# --- Global Variables ---
Android=$(getprop ro.build.version.release)  # Get Android version
arch=$(getprop ro.product.cpu.abi)  # Get Android arch
model=$(getprop ro.product.model)  # Get Device Model
Simplify="$HOME/Simplify"  # /data/data/com.termux/files/home/Simplify dir
RVX="$Simplify/RVX"
SimplUsr="/sdcard/Simplify"  # /storage/emulated/0/Simplify dir
mkdir -p "$Simplify" "$RVX" "$SimplUsr"  # Create $Simplify, $RVX and $SimplUsr dir if it does't exist
Download="/sdcard/Download"  # Download dir

echo -e "$info ${Blue}Target device:${Reset} $model"

bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar"

#bash $Simplify/dlGitHub.sh "inotia00" "revanced-patches" "latest" ".rvp" "$RVX"
bash $Simplify/dlGitHub.sh "anddea" "revanced-patches" "pre" ".rvp" "$RVX"
PatchesRvp=$(find "$RVX" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

if [ "$Android" -ge "6" ]; then
  bash $Simplify/dlGitHub.sh "inotia00" "VancedMicroG" "latest" ".apk" "$SimplUsr"
  VancedMicroG=$(find "$SimplUsr" -type f -name "microg-*.apk" -print -quit)
  VancedMicroGBaseName=$(basename "$VancedMicroG")
  echo -e "$info ${Blue}VancedMicroG:${Reset} $VancedMicroG"
fi

# --- Architecture Detection ---
all_arch="arm64-v8a armeabi-v7a x86_64 x86"  # Space-separated list instead of array
# Generate ripLib arguments for all ABIs EXCEPT the detected one
ripLib=""
for current_arch in $all_arch; do
  if [ "$current_arch" != "$arch" ]; then
    if [ -z "$ripLib" ]; then
      ripLib="--rip-lib=$current_arch"  # No leading space for first item
    else
      ripLib="$ripLib --rip-lib=$current_arch"  # Add space for subsequent items
    fi
  fi
done
# Display the final ripLib arguments
echo -e "$info ${Blue}arch:${Reset} $arch"
echo -e "$info ${Blue}ripLib:${Reset} $ripLib"

# --- Generate patches.json file --- 
if [ $Android -ge 8 ]; then
  if [ -f "$RVX/patches.json" ]; then
    rm $RVX/patches.json
  fi
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patches -p "$RVX/patches.json" $PatchesRvp
  if [ $? == 0 ] && [ -f "$RVX/patches.json" ]; then
    echo -e "$info patches.json generated successfully."
    jq -r '.[] | .compatiblePackages // empty | .[] | {name: .name, version: .versions[-1]} | "\(.name) \(.version)"' $RVX/patches.json | sort -u | awk '{a[$1]=$2} END{for (i in a) printf "\"%s\" \"%s\"\n", i, a[i]}'
  else
    echo -e "$bad patches.json was not generated!"
  fi
fi

# Get compatiblePackages version from json
getVersion() {
  local pkgName="$1"
  local json="$RVX/patches.json"
  
  # Get all versions for the package and sort them, then take the highest version
  pkgVersion=$(jq -r --arg pkg "$pkgName" '[.[] | .compatiblePackages // empty | .[] | select(.name == $pkg and .versions != null) | .versions[]] | sort | last' $json 2>/dev/null)
}

<<comment
# --- Download revanced-extended-options.json ---
if [ ! -f "$RVX/rvx-options.json" ]; then
  echo -e "$running Downloading revanced-extended-options.json from GitHub.."
  curl -sL "https://github.com/arghya339/Simplify/releases/download/all/rvx-options.json" --progress-bar -o "$RVX/rvx-options.json"
  # Supported app icon: google_family, pink, revancify_blue, vanced_light
fi
comment

#  --- Patch YouTube ---
patch_yt() {
  local outputAPK=$1
  local log="$SimplUsr/yt-rvx-patch_log.txt"
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" $youtube_apk_path \
    -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
    -e "Custom Shorts action buttons" -OiconType="round" \
    -e "Custom branding icon for YouTube" -OappIcon="$SimplUsr/branding/youtube/launcher/google_family" \
    -e "Custom header for YouTube" -OcustomHeader="$SimplUsr/branding/youtube/header/google_family" \
    -e "Custom branding name for YouTube" -OappName="YouTube RVX" \
    -e "Hide shortcuts" -Oshorts=false \
    -e "Overlay buttons" -OiconType=thin \
    -e "Custom header for YouTube" -e "Force hide player buttons background" -e=MaterialYou \
    -e="Return YouTube Username" --custom-aapt2-binary="$HOME/aapt2" \
    --purge $ripLib -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f $youtube_apk_path ]; then
    echo -e "$bad Oops, YouTube Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    if [ $Android -eq 6 ] || [ $Android -eq 7 ]; then
      termux-open-url "https://github.com/kitadai31/revanced-patches-android6-7/issues/new?template=bug_report.yml"
    else
      termux-open-url "https://github.com/inotia00/ReVanced_Extended/issues/new?template=bug-report.yml"
    fi
    termux-open --send "$log"
  fi
}

# ---- Patch YouTube Music ---
patch_yt_music() {
  local outputAPK=$1
  local log="$SimplUsr/yt-music-rvx-patch_log.txt"
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "$yt_music_apk_path" \
    -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
    -e "Custom branding icon for YouTube Music" -OappIcon="$SimplUsr/branding/music/launcher/google_family" \
    -e "Custom header for YouTube Music" -OcustomHeader="$SimplUsr/branding/music/header/google_family" \
    -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" \
    -e "Dark theme" -OmaterialYou=true \
    -e "Custom header for YouTube Music" -e="Return YouTube Username" --custom-aapt2-binary="$HOME/aapt2" \
    --purge -f | tee "$log"
  
  if [ ! -f "$outputAPK" ] && [ -f $yt_music_apk_path ]; then
    echo -e "$bad Oops, YouTube Music Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/inotia00/ReVanced_Extended/issues/new?template=bug-report.yml"
    termux-open --send "$log"
  fi
}

# ---- Patch Reddit ---
patch_reddit() {
  local outputAPK=$1
  local log="$SimplUsr/reddit-rvx-patch_log.txt"
  
  $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
    -o "$outputAPK" "$reddit_apk_path" \
    --custom-aapt2-binary="$HOME/aapt2" \
    --purge $ripLib -f | tee "$log"
    # --legacy-options "$RVX/rvx-options.json" \
  
  if [ ! -f "$outputAPK" ] && [ -f $reddit_apk_path ]; then
    echo -e "$bad Oops, Reddit Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "https://github.com/inotia00/ReVanced_Extended/issues/new?template=bug-report.yml"
    termux-open --send "$log"
  fi
}

if [ $Android -ge 8 ]; then
  # --- YouTube ---
  getVersion "com.google.android.youtube"
  #pkgVersion="$pkgVersion"
  pkgVersion="20.21.37"
  bash $Simplify/APKMdl.sh "com.google.android.youtube" "$pkgVersion" "BUNDLE" "universal"  # Download stock YouTube apk from APKMirror
  youtube_apk_path="$Download/YouTube_v${pkgVersion}-universal.apk"
  if [ -f "$youtube_apk_path" ]; then
    echo -e "$good ${Green}Downloaded YouTube APK found:${Reset} $youtube_apk_path"
    echo -e "$running Patching YouTube RVX.."
    patch_yt "$SimplUsr/youtube-rvx_v${pkgVersion}-$arch.apk"
  fi
  if [ -f "$SimplUsr/youtube-rvx_v${pkgVersion}-$arch.apk" ]; then
    echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
    echo -e "[?] ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset} \c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing VancedMicroG apk.."
        bash $Simplify/apkInstall.sh "$VancedMicroG" "$VancedMicroGBaseName" "com.mgoogle.android.gms" "org.microg.gms.ui.SettingsActivity"
        ;;
      n*|N*) echo -e "$notice VancedMicroG Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! VancedMicroG Installaion skipped." ;;
    esac
    echo -e "[?] ${Yellow}Do you want to install YouTube RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched YouTube RVX apk.."
        bash $Simplify/apkInstall.sh "$SimplUsr/youtube-rvx_v${pkgVersion}-$arch.apk" "youtube-rvx_v${pkgVersion}-$arch.apk" "app.rvx.android.youtube" "com.google.android.apps.youtube.app.watchwhile.MainActivity"
        ;;
      n*|N*) echo -e "$notice YouTube RVX Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! YouTube RVX Installaion skipped." ;;
    esac
    echo -e "[?] ${Yellow}Do you want to Share YouTube RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo - e"$running Please Wait !! Sharing Patched YouTube RVX apk.."
        termux-open --send "$SimplUsr/youtube-rvx_v${pkgVersion}-$arch.apk"
        ;;
      n*|N*) echo -e "$notice YouTube RVX Sharing skipped!"
        echo -e "$info Locate 'youtube-rvx_v${pkgVersion}-$arch.apk' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
        ;;
        *) echo -e "$info Invalid choice! YouTube RVX Sharing skipped." ;;
    esac
  fi
  
  # --- YouTube Music ---
  getVersion "com.google.android.apps.youtube.music"
  #pkgVersion="$pkgVersion"
  pkgVersion="8.18.51"
  bash $Simplify/APKMdl.sh "com.google.android.apps.youtube.music" "$pkgVersion" "APK" "$arch"  # Download stock YT Music apk from APKMirror
  yt_music_apk_path="$Download/YouTube Music_v${pkgVersion}-$arch.apk"
  if [ -f "$yt_music_apk_path" ]; then
    echo -e "$good ${Green}Downloaded YouTube Music APK found:${Reset} $yt_music_apk_path"
    echo -e "$running Patching YouTube Music RVX.."
    patch_yt_music "$SimplUsr/yt-music-rvx_v${pkgVersion}-$arch.apk"
  fi
  if [ -f "$SimplUsr/yt-music-rvx_v${pkgVersion}-$arch.apk" ]; then
    echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
    echo -e "[?] ${Yellow}Do you want to install VancedMicroG app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing VancedMicroG apk.."
        bash $Simplify/apkInstall.sh "$VancedMicroG" "$VancedMicroGBaseName" "com.mgoogle.android.gms" "org.microg.gms.ui.SettingsActivity"
        ;;
      n*|N*) echo -e "$notice VancedMicroG Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! VancedMicroG Installaion skipped." ;;
    esac
    echo -e "[?] ${Yellow}Do you want to install YT Music RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched YT Music RVX apk.."
        bash $Simplify/apkInstall.sh "$SimplUsr/yt-music-rvx_v${pkgVersion}-$arch.apk" "yt-music-rvx_v${pkgVersion}-$arch.apk" "app.rvx.android.apps.youtube.music" "com.google.android.apps.youtube.music.activities.MusicActivity"
        ;;
      n*|N*) echo -e "$notice YT Music RVX Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! YT Music RVX Installaion skipped." ;;
    esac
    echo -e "[?] ${Yellow}Do you want to Share YouTube Music RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Sharing Patched YouTube Music RVX apk.."
        termux-open --send "$SimplUsr/yt-music-rvx_v${pkgVersion}-$arch.apk"
        ;;
      n*|N*) echo -e "$notice YouTube Music RVX Sharing skipped!"
        echo -e "$info Locate 'yt-music-rvx_v${pkgVersion}-$arch.apk' in '/sdcard/Simplify/' dir, Share it with your Friends and Family ;)"
        ;;
        *) echo -e "$info Invalid choice! YouTube Music RVX Sharing skipped." ;;
    esac
  fi
if

# --- Reddit ---
if [ $Android -ge 9 ]; then
  getVersion "com.reddit.frontpage"
  pkgVersion="$pkgVersion"
  #pkgVersion="2025.12.1"
  bash $Simplify/APKMdl.sh "com.reddit.frontpage" "$pkgVersion" "BUNDLE" "universal"  # Download stock Reddit apk from APKMirror
  reddit_apk_path="$Download/Reddit_v${pkgVersion}-universal.apk"
  if [ -f "$reddit_apk_path" ]; then
    echo -e "$good ${Green}Downloaded Reddit APK found:${Reset} $reddit_apk_path"
    echo -e "$running Patching Reddit RVX.."
    patch_reddit "$SimplUsr/reddit-rvx_v${pkgVersion}-$arch.apk"
  fi
  if [ -f "$SimplUsr/reddit-rvx_v${pkgVersion}-$arch.apk" ]; then
    echo -e "[?] ${Yellow}Do you want to install Reddit RVX app? [Y/n]${Reset} \c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched Reddit RVX apk.."
        bash $Simplify/apkInstall.sh "$SimplUsr/reddit-rvx_v${pkgVersion}-$arch.apk" "reddit-rvx_v${pkgVersion}-$arch.apk" "com.reddit.frontpage" "com.reddit.launch.main.MainActivity"
        ;;
      n*|N*) echo -e "$notice Reddit RVX Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! Reddit RVX Installaion skipped." ;;
    esac
  fi
fi

# --- YouTube Music RVX Android 7 ---
if [ $Android -eq 7 ]; then
  # --- Download TY Music_6.42.55.apk from GitHub ---
  if { [ ! -f "$Download/YouTube Music_v6.42.55-$arch.apk" ] || [ ! -f "$Download/YouTube Music_v6.42.52-$arch.apk" ]; } && { [ "$arch" == "arm64-v8a" ] || [ "$arch" == "armeabi-v7a" ]; }; then
    bash $Simplify/APKMdl.sh "com.google.android.apps.youtube.music" "6.42.55" "APK" "$arch"  # Download stock YT Music 6.42.55 apk from APKMirror
  else
    echo -e "$running Downloading YT Music 6.42.55 apk from github.."
    #bash $Simplify/APKMdl.sh "com.google.android.apps.youtube.music" "6.42.52" "APK" "$arch"  # Download stock YT Music 6.42.52 apk from APKMirror
    curl -sL "https://github.com/arghya339/Simplify/releases/download/all/com.google.android.apps.youtube.music_6.42.55-$arch.apk" --progress-bar -C - -o "$Download/YouTube Music_v6.42.55-$arch.apk"
  fi
  fi
  if [ -f "$Download/YouTube Music_v6.42.55-$arch.apk" ]; then
    echo -e "$good ${Green}Downloaded YT Music 6.42.55 found:${Reset} $Download/YouTube\ Music_v6.42.55-$arch.apk"
    echo -e "$running Patching YT Music 6.42.55.."
    patch_yt_music "$SimplUsr/yt-music-rvx_v6.42.55-$arch.apk"
  fi
  if [ -f "$Download/YouTube Music_v6.42.52-$arch.apk" ]; then
    echo -e "$good ${Green}Downloaded YT Music 6.42.52 found:${Reset} $Download/YouTube\ Music_v6.42.52-$arch.apk"
    echo -e "$running Patching YT Music 6.42.52.."
    patch_yt_music "$SimplUsr/yt-music-rvx_v6.42.52-$arch.apk"
  fi
  if [ -f "$SimplUsr/yt-music-rvx_v6.42.55-$arch.apk" ] || [ -f "$SimplUsr/yt-music-rvx_v6.42.52-$arch.apk" ]; then
    echo "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
    echo -e "[?] ${Yellow}Do you want to install VancedMicroG app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing VancedMicroG apk.."
        bash $Simplify/apkInstall.sh "$VancedMicroG" "$VancedMicroGBaseName" "com.mgoogle.android.gms" "org.microg.gms.ui.SettingsActivity"
        ;;
      n*|N*) echo -e "$notice VancedMicroG Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! VancedMicroG Installaion skipped." ;;
    esac
    echo -e "[?] ${Yellow}Do you want to install YT Music RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched YT Music RVX apk.."
        if [ -f "$SimplUsr/yt-music-rvx_v6.42.55-$arch.apk" ]; then
          bash $Simplify/apkInstall.sh "$SimplUsr/yt-music-rvx_v6.42.55-$arch.apk" "yt-music-rvx_v6.42.55-$arch.apk" "app.rvx.android.apps.youtube.music" "com.google.android.apps.youtube.music.activities.MusicActivity"
        fi
        if [ -f "$SimplUsr/yt-music-rvx_v6.42.52-$arch.apk" ]; then
          bash $Simplify/apkInstall.sh "$SimplUsr/yt-music-rvx_v6.42.52-$arch.apk" "yt-music-rvx_v6.42.52-$arch.apk" "app.rvx.android.apps.youtube.music" "com.google.android.apps.youtube.music.activities.MusicActivity"
        fi
        ;;
      n*|N*) echo -e "$notice YT Music RVX Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! YT Music RVX Installaion skipped." ;;
    esac
  fi
fi

# --- YouTube Music RVX Android 5 and 6 ---
if [ $Android -eq 5 ] || [ $Android -eq 6 ]; then
  # --- Download TY Music_6.20.51.apk from APKMirror ---
  if [ ! -f "$Download/YouTube Music_v6.20.51-$arch.apk" ]; then
    echo -e "$running Download YT Music 6.20.51 apk from APKMirror.."
    bash $Simplify/APKMdl.sh "com.google.android.apps.youtube.music" "6.20.51" "APK" "$arch"  # Download stock YT Music 6.20.51 apk from APKMirror
  fi
  if [ -f "$Download/YouTube Music_v6.20.51-$arch.apk" ]; then
    echo -e "$good ${Green}YT Music 6.20.51 found:${Reset} $Download/YouTube\ Music_v6.20.51-$arch.apk."
    echo -e "$running Patching YT Music RVX 6.20.51.."
    patch_yt_music "$SimplUsr/yt-music-rvx_v6.20.51-$arch.apk"
  fi
  if [ -f "$SimplUsr/yt-music-rvx_v6.20.51-$arch.apk" ]; then
    echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
    echo -e "[?] ${Yellow}Do you want to install VancedMicroG app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing VancedMicroG apk.."
        if [ $Android -eq 5]; then
          if [ ! -f "$SimplUsr/VancedMicroG-0.2.22.212658.apk" ]; then
            curl -sL "https://github.com/TeamVanced/VancedMicroG/releases/download/v0.2.22.212658-212658001/microg.apk" --progress-bar -C - -o "$SimplUsr/VancedMicroG-0.2.22.212658.apk"
          fi
          if [ -f "$SimplUsr/VancedMicroG-0.2.22.212658.apk" ]; then
            bash $Simplify/apkInstall.sh "$$SimplUsr/VancedMicroG-0.2.22.212658.apk" "VancedMicroG-0.2.22.212658.apk" "com.mgoogle.android.gms" "org.microg.gms.ui.SettingsActivity"
          fi
        else
          bash $Simplify/apkInstall.sh "$VancedMicroG" "$VancedMicroGBaseName" "com.mgoogle.android.gms" "org.microg.gms.ui.SettingsActivity"
        fi
        ;;
      n*|N*) echo -e "$notice VancedMicroG Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! VancedMicroG Installaion skipped." ;;
    esac
    echo -e "[?] ${Yellow}Do you want to install YT Music RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched YT Music RVX apk.."
        bash $Simplify/apkInstall.sh "$SimplUsr/yt-music-rvx_v6.20.51-$arch.apk" "yt-music-rvx_v6.20.51-$arch.apk" "app.rvx.android.apps.youtube.music" "com.google.android.apps.youtube.music.activities.MusicActivity"
        ;;
      n*|N*) echo -e "$notice YT Music RVX Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! YT Music RVX Installaion skipped." ;;
    esac
  fi
fi

# --- RVX Android 6-7 ---
if [ $Android -eq 6 ] || [ $Android -eq 7 ]; then
  PatchesRvp=$(find "$RVX" -type f -name "patches-*.rvp" -print -quit)
  rm $PatchesRvp
  bash $Simplify/dlGitHub.sh "kitadai31" "revanced-patches-android6-7" "latest" ".rvp" "$RVX"
  PatchesRvp=$findFile
  
  bash $Simplify/APKMdl.sh "com.google.android.youtube" "17.34.36" "BUNDLE" "universal"  # Download stock YouTube 17.34.36 apk from APKMirror
  youtube_apk_path="$Download/YouTube_v17.34.36-universal.apk"
  if [ -f "$youtube_apk_path" ]; then
    echo -e "$good ${Green}Downloaded YouTube APK found:${Reset} $youtube_apk_path"
    echo -e "$running Patching YouTube RVX.."
    patch_yt "$SimplUsr/youtube-rvx_v17.34.36-$arch.apk"
  fi
  if [ -f "$SimplUsr/youtube-rvx_v17.34.36-$arch.apk" ]; then
    echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
    echo -e "[?] ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset} \c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing VancedMicroG apk.."
        bash $Simplify/apkInstall.sh "$VancedMicroG" "$VancedMicroGBaseName" "com.mgoogle.android.gms" "org.microg.gms.ui.SettingsActivity"
        ;;
      n*|N*) echo -e "$notice VancedMicroG Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! VancedMicroG Installaion skipped." ;;
    esac
    echo -e "[?] ${Yellow}Do you want to install YouTube RVX app? [Y/n] ${Reset}\c" && read opt
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched YouTube RVX apk.."
        bash $Simplify/apkInstall.sh "$SimplUsr/youtube-rvx_v17.34.36-$arch.apk" "youtube-rvx_v17.34.36-$arch.apk" "app.rvx.android.youtube" "com.google.android.apps.youtube.app.watchwhile.MainActivity"
        ;;
      n*|N*) echo -e "$notice YouTube RVX Installaion skipped!" ;;
      *) echo -e "$info Invalid choice! YouTube RVX Installaion skipped." ;;
    esac
  fi
fi
############################################################################