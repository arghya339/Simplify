#!/usr/bin/bash

[ $su -eq 1 ] && echo -e "$info ${Blue}Target device:${Reset} $Model ($Serial)" || echo -e "$info ${Blue}Target device:${Reset} $Model"

[ $ChangeRVXSource -eq 0 ] && BugReportUrl="https://github.com/inotia00/ReVanced_Extended/issues/new?template=bug-report.yml" || BugReportUrl="https://github.com/anddea/revanced-patches/issues/new?template=bug-report.yml"

branding  # Call branding function

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
if [ "$ChangeRVXSource" -eq 0 ]; then
  owner="inotia00"  # Use inotia00 as owner
else
  owner="anddea"  # Use anddea as owner
fi
bash $Simplify/dlGitHub.sh "$owner" "revanced-patches" "$release" ".rvp" "$RVX"
PatchesRvp=$(find "$RVX" -type f -name "patches-*.rvp" -print -quit)
echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"

# --- Download Vanced MicroG ---
if [ $su -eq 0 ]; then
  if [ $Android -eq 5 ]; then
    VancedMicroG="$SimplUsr/microg-0.2.22.212658.apk"
    [ ! -f "$VancedMicroG" ] && curl -sL "https://github.com/TeamVanced/VancedMicroG/releases/download/v0.2.22.212658-212658001/microg.apk" --progress-bar -C - -o "$VancedMicroG"
  elif [ "$Android" -ge "6" ]; then
    bash $Simplify/dlGitHub.sh "inotia00" "VancedMicroG" "latest" ".apk" "$SimplUsr"
    VancedMicroG=$(find "$SimplUsr" -type f -name "microg-*.apk" -print -quit)
  fi
  echo -e "$info ${Blue}VancedMicroG:${Reset} $VancedMicroG"
fi

if [ $RipLib -eq 1 ]; then
  # Display the final ripLib arguments
  echo -e "$info ${Blue}cpuAbi:${Reset} $cpuAbi"
  echo -e "$info ${Blue}ripLib:${Reset} $ripLib"
else
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

# --- Download ReVanced CLI v3 ---
dl_rv_cli_v3() {
  ReVancedCLIv4="$RV4/revanced-cli-3.1.4-all.jar"
  if [ ! -f "$ReVancedCLIv4" ]; then
    echo -e "$running Downloading revanced-cli-3.1.4-all.jar.."
    url="https://github.com/inotia00/revanced-cli/releases/download/v3.1.4/revanced-cli-3.1.4-all.jar"
    while true; do
      #curl -L --progress-bar -C - -o "$ReVancedCLIv4" "$url"
      aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$(basename "$ReVancedCLIv4")" -d "$(dirname "$ReVancedCLIv4")" "$url"
      if [ $? -eq 0 ]; then
        echo  # White Space
        break
      fi
      echo -e "${bad} ${Red}Download failed! retrying in 5 seconds..${Reset}"
      sleep 5  # Wait 5 seconds
    done
  fi
  echo -e "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIv4"
}

#  --- Patching Apps Method ---
patch_app() {
  local stock_apk_path=$1
  local -n patches=$2  # nameref (-n) accept an array name as parameter
  local outputAPK=$3
  without_ext="${outputAPK%.*}"  # remove file extension (.apk)
  local log=$4
  local appName="$5"
  local Url=$6
  
  ReVancedCLIJar=$(find "$RVX" -type f -name "revanced-cli-*-all.jar" -print -quit)
  if [[ ( $Android -eq 7 || $Android -eq 6 ) && ( "$appName" == "YouTube" ) && ( $ChangeRVXSource -eq 0 ) ]]; then
    bash $Simplify/dlGitHub.sh "kitadai31" "revanced-patches-android6-7" "$release" ".rvp" "$RVX6_7"
    PatchesRvp=$(find "$RVX6_7" -type f -name "patches-*.rvp" -print -quit)
    echo -e "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp"
  elif [[ ( $Android -eq 7 || $Android -eq 6 ) && ( "$appName" == "YouTube" ) && ( $ChangeRVXSource -eq 1 ) ]]; then
    dl_rv_cli_v3
    bash $Simplify/dlGitHub.sh "arghya339" "revanced-patches-android6-7" "latest" ".jar" "$RV4"
    PatchesJar=$(find "$RV4" -type f -name "revanced-patches-*.jar" -print -quit)
    echo -e "$info ${Blue}PatchesJar:${Reset} $PatchesJar"
    bash $Simplify/dlGitHub.sh "arghya339" "revanced-integrations" "latest" ".apk" "$RV4"
    IntegrationsApk=$(find "$RV4" -type f -name "revanced-integrations-*.apk" -print -quit)
    echo -e "$info ${Blue}IntegrationsApk:${Reset} $IntegrationsApk"
    #curl -sL -C - -o $SimplUsr/options.json https://raw.githubusercontent.com/arghya339/ReVancedApp-Actions/refs/heads/main/src/options/revanced-extended-android-6-7-arghya339.json
  elif [ $Android -eq 5 ] && [ "$appName" == "YouTube" ]; then
    dl_rv_cli_v3
    bash $Simplify/dlGitHub.sh "d4n3436" "revanced-patches-android5" "latest" ".jar" "$RV4"
    PatchesJar=$(find "$RV4" -type f -name "revanced-patches-*.jar" -print -quit)
    echo -e "$info ${Blue}PatchesJar:${Reset} $PatchesJar"
    bash $Simplify/dlGitHub.sh "d4n3436" "revanced-integrations" "latest" ".apk" "$RV4"
    IntegrationsApk=$(find "$RV4" -type f -name "revanced-integrations-*.apk" -print -quit)
    echo -e "$info ${Blue}IntegrationsApk:${Reset} $IntegrationsApk"
    curl -sL -C - -o $SimplUsr/options.json https://raw.githubusercontent.com/arghya339/ReVancedApp-Actions/refs/heads/main/src/options/revanced-extended-android-5.json
  fi
  if [ $ChangeRVXSource -eq 0 ] && [ "$appName" == "Reddit" ] && [ "$ARSCLib" == "true" ]; then
    mkdir -p "$RVX/ARSCLib"
    bash $Simplify/dlGitHub.sh "inotia00" "revanced-cli-arsclib" "latest" ".jar" "$RVX/ARSCLib"
    rvCli=$(find "$RVX/ARSCLib" -type f -name "revanced-cli-*-all.jar" -print -quit)
    bash $Simplify/dlGitHub.sh "$owner" "revanced-patches-arsclib" "latest" ".jar" "$RVX/ARSCLib"
    rvPatches=$(find "$RVX/ARSCLib" -type f -name "revanced-patches-*.jar" -print -quit)
    bash $Simplify/dlGitHub.sh "$owner" "revanced-integrations" "latest" ".apk" "$RVX/ARSCLib"
    rvIntegrations=$(find "$RVX/ARSCLib" -type f -name "revanced-integrations-*.apk" -print -quit)
  fi
  
  echo -e "$running Patching ${appName} RVX.."
  if [[ ( $Android -eq 7 || $Android -eq 6 ) && ( "$appName" == "YouTube" ) && ( $ChangeRVXSource -eq 1 ) ]]; then
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIv4 patch $stock_apk_path -o $outputAPK -m $IntegrationsApk -b $PatchesJar \
      -i "materialyou" -i "spoof-streaming-data" -e "hide-autoplay-button" -e "hide-cast-button"  -e "hide-create-button" -e "hide-endscreen-overlay" -e "hide-next-prev-button" \
      -e "hide-player-captions-button" -e "hide-player-overlay-filter" -e "hide-shorts-button" -e "switch-create-notification" \
      --custom-aapt2-binary="$HOME/aapt2" --purge | tee "$log"  # --options $SimplUsr/options.json $ripLib 
      [ -f $HOME/options.json ] && rm -f ~/options.json
  elif [ $Android -eq 5 ] && [ "$appName" == "YouTube" ]; then
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIv4 patch $stock_apk_path -o $outputAPK -m $IntegrationsApk --options $SimplUsr/options.json -b $PatchesJar \
      -i patch-options -i custom-branding-icon-afn-blue -i custom-branding-icon-revancify -i materialyou -i spoof-app-version \
      -e custom-branding-icon-afn-red -e hide-autoplay-button -e hide-cast-buttom -e hide-create-button -e hide-endscreen-overlay -e hide-next-prev-button -e hide-player-captions-button -e hide-player-overlay-filter -e hide-shorts-button -e hide-snackbar -e switch-create-notification \
      --custom-aapt2-binary="$HOME/aapt2" --purge $ripLib | tee "$log"
  elif [ $ChangeRVXSource -eq 0 ] && [ "$appName" == "Reddit" ] && [ "$ARSCLib" == "true" ]; then
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $rvCli options -b $rvPatches  # Genarate patches options.json
    jq '(.[] | select(.patchName == "Change version code").options[] | select(.key == "ChangeVersionCode").value) |= true' options.json > temp.json && mv temp.json options.json  # modifiy ChangeVersionCode key value = true
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar "$rvCli" -a "$stock_apk_path" -o "$SimplUsr" -m "$rvIntegrations" --options options.json -b "$rvPatches" -i "Change version code" -e "Custom branding name for Reddit" -c  # Patch
    rm -f options.json; rm -f $SimplUsr/revanced.keystore  # remove files
    mv "$SimplUsr/base.apk" "$outputAPK"  # rename output patched apk using mv
  else
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar patch -p $PatchesRvp \
      -o "$outputAPK" "$stock_apk_path" \
      "${patches[@]}" \
      -e "Change version code" -OversionCode="2147483647" \
      --custom-aapt2-binary="$HOME/aapt2" \
      --purge $ripLib -f | tee "$log"
  fi

  if [ ! -f "$outputAPK" ] && [ -f "$stock_apk_path" ]; then
    echo -e "$bad Oops, $appName Patching failed !! Logs saved to "$log". Share the Patchlog to developer."
    termux-open-url "$Url"
    termux-open --send "$log"
    rm -rf "$without_ext-temporary-files"  # Remove temporary files directory
  else
    [[ -f "$without_ext.keystore" ]] && rm -f "$without_ext.keystore"
  fi
}

# --- Collect the enable/disable patches name with options in arrays ---
yt_patches_args=(
  # enable patches with their options
  -e "Custom Shorts action buttons" -OiconType="round"
  -e "Custom branding icon for YouTube" -OappIcon="$SimplUsr/.branding/youtube/launcher/$Branding" -OchangeSplashIcon=true -OrestoreOldSplashAnimation=false
  -e "Custom header for YouTube" -OcustomHeader="$SimplUsr/.branding/youtube/header/$Branding"
  -e "Hide shortcuts" -Oshorts=false
  -e "Visual preferences icons for YouTube" -OsettingsMenuIcon="extension"
  -e "Overlay buttons" -OiconType=thin
  -e "Spoof streaming data" -OuseMobileWebClient=true
  -e "Settings for YouTube" -OinsertPosition="@string/about_key" -OrvxSettingsLabel=RVX
  -e "Force hide player buttons background"
  -e=MaterialYou -e Theme
  -e="Return YouTube Username"
)

if [ $su -eq 1 ]; then
  yt_patches_args+=(
    -d "GmsCore support"
    -e "Custom branding name for YouTube" -OappName=YouTube
  )
else
  if [ $Android -eq 7 ] || [ $Android -eq 6 ]; then
    yt_patches_args+=(-e "GmsCore support" -OgmsCoreVendorGroupId="app.revanced" -OcheckGmsCore=true -OpackageNameYouTube="app.rvx.android.youtube")
  else
    yt_patches_args+=(-e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true -OpackageNameYouTube="app.rvx.android.youtube")
  fi
  yt_patches_args+=(-e "Custom branding name for YouTube" -OappName="YouTube RVX")
fi

yt_music_patches_args=(
  -e "Custom branding icon for YouTube Music" -OappIcon="$SimplUsr/.branding/music/launcher/$Branding"
  -e "Custom header for YouTube Music" -OcustomHeader="$SimplUsr/.branding/music/header/$Branding"
  -e "Dark theme" -OmaterialYou=true
  -e "Visual preferences icons for YouTube Music" -OsettingsMenuIcon="extension"
  -e "Settings for YouTube Music" -OinsertPosition="settings_header_about_youtube_music" -OrvxSettingsLabel="RVX"
  -e "Hide ads" -OhideFullscreenAds=true
  -e="Return YouTube Username" -e "Disable music video in album"
)

if [ $su -eq 1 ]; then
  yt_music_patches_args+=(
    -d "GmsCore support"
    -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music" -OappNameLauncher="YT Music"
  )
else
  yt_music_patches_args+=(
    -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true -OpackageNameYouTubeMusic="app.rvx.android.apps.youtube.music"
    -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX"
  )
fi

spotify_patches_args=(
  -e "Change lyrics provider"
  -e "Custom theme"
  -d "Hide Create button"
)

reddit_patches_args=()

netwall_patches_args=()

if [ "$ReadPatchesFile" -eq 1 ]; then
  
  # Default content for new files
  default_content=(
    # [0] YouTube
    '-e "Custom Shorts action buttons" -OiconType="round"
-e "Custom branding icon for YouTube" -OappIcon="/sdcard/Simplify/.branding/youtube/launcher/google_family" -OchangeSplashIcon=true -OrestoreOldSplashAnimation=false
-e "Custom header for YouTube" -OcustomHeader="/sdcard/Simplify/.branding/youtube/header/google_family"
-e "Hide shortcuts" -Oshorts=false
-e "Visual preferences icons for YouTube" -OsettingsMenuIcon="extension"
-e "Overlay buttons" -OiconType=thin
-e "Spoof streaming data" -OuseIOSClient
-e "Settings for YouTube" -OinsertPosition="@string/about_key" -OrvxSettingsLabel=RVX
-e "Force hide player buttons background"
-e=MaterialYou -e Theme
-e="Return YouTube Username"'

    # [1] YT Music
    '-e "Custom branding icon for YouTube Music" -OappIcon="/sdcard/Simplify/.branding/music/launcher/google_family"
-e "Custom header for YouTube Music" -OcustomHeader="/sdcard/Simplify/.branding/music/header/google_family"
-e "Dark theme" -OmaterialYou=true
-e "Visual preferences icons for YouTube Music" -OsettingsMenuIcon="extension"
-e "Settings for YouTube Music" -OinsertPosition="settings_header_about_youtube_music" -OrvxSettingsLabel="RVX"
-e "Custom header for YouTube Music"
-e="Return YouTube Username" -e "Disable music video in album"'

    # [2] Spotify
    '-e "Change lyrics provider"
-e "Custom theme"
-d "Hide Create button"'

    # [3] Reddit, [4] NetWall | No default patches
    '' ''
  )

  # Array to stores arrays-names
  arraynames=(
    yt_patches_args
    yt_music_patches_args
    spotify_patches_args
    reddit_patches_args
    netwall_patches_args
  )

  # Create Empty Files if it doesn’t exist
  for ((i=0; i<${#arraynames[@]}; i++)); do
    if [ ! -e "$SimplUsr/${arraynames[$i]}.txt" ]; then
      #touch "$SimplUsr/${arraynames[$i]}.txt"
      printf "%s\n" "${default_content[i]}" > "$SimplUsr/${arraynames[$i]}.txt"
      if [ "${arraynames[$i]}" == "yt_patches_args" ] || [ "${arraynames[$i]}" == "yt_music_patches_args" ]; then
        if [ $su -eq 1 ]; then
          echo "-d \"GmsCore support\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          if [ "${arraynames[$i]}" == "yt_patches_args" ]; then
            echo "-e \"Custom branding name for YouTube\" -OappName=YouTube" >> "$SimplUsr/${arraynames[$i]}.txt"
          else
            echo "-e \"Custom branding name for YouTube Music\" -OappNameNotification=\"YouTube Music\" -OappNameLauncher=\"YT Music\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          fi
        else
          if [ "${arraynames[$i]}" == "yt_patches_args" ]; then
            if [[ ( $Android -eq 7 || $Android -eq 6 ) && "${arraynames[$i]}" == "yt_patches_args" ]]; then
              echo "-e \"GmsCore support\" -O gmsCoreVendorGroupId=\"app.revanced\" -OcheckGmsCore=true -OpackageNameYouTube=\"app.rvx.android.youtube\"" >> "$SimplUsr/${arraynames[$i]}.txt"
            else
              echo "-e \"GmsCore support\" -O gmsCoreVendorGroupId=\"com.mgoogle\" -OcheckGmsCore=true -OpackageNameYouTube=\"app.rvx.android.youtube\"" >> "$SimplUsr/${arraynames[$i]}.txt"
            fi
            echo "-e \"Custom branding name for YouTube\" -OappName=\"YouTube RVX\"" >> "$SimplUsr/${arraynames[$i]}.txt"
          else
            echo "-e \"GmsCore support\" -O gmsCoreVendorGroupId=\"com.mgoogle\" -OcheckGmsCore=true -OpackageNameYouTubeMusic=\"app.rvx.android.apps.youtube.music\"" >> "$SimplUsr/${arraynames[$i]}.txt"
            echo "-e \"Custom branding name for YouTube Music\" -OappNameNotification=\"YouTube Music RVX\" -OappNameLauncher=\"YT Music RVX\"" >> "$SimplUsr/${arraynames[$i]}.txt"
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

# --- function for common app installation prompt ---
commonPrompt() {
    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install ${appNameRef[0]} RVX app?" "buttons" && opt=Yes || opt=No
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RVX apk.."
        apkInstall "$outputAPK" "$activityPatched"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} RVX Installaion skipped!" ;;
    esac
    
    buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Share ${appNameRef[0]} RVX app?" "buttons" "1" && opt=Yes || opt=No
    case $opt in
      y*|Y*|"")
        echo -e "$running Please Wait !! Sharing Patched ${appNameRef[0]} RVX apk.."
        termux-open --send "$outputAPK"
        ;;
      n*|N*) echo -e "$notice ${appNameRef[0]} RVX Sharing skipped!"
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
  local pkgVersion=$2
  local Type=$3
  local Arch=$4
  local web=$5
  local -n stock_apk_ref=$6
  local appPatchesArgs=$7
  local outputAPK=$8
  local fileName=$(basename $outputAPK)
  local log=$9
  local -n appNameRef=${10}
  local bugReportUrl=$11
  local pkgPatched=$12
  local activityPatched=$13
  
  
  if [ "$web" == "APKMirror" ]; then
    APKMdl "$pkgName" "" "$pkgVersion" "$Type" "$Arch"  # Download stock apk from APKMirror
  elif [ "$web" == "Uptodown" ]; then
    bash $Simplify/dlUptodown.sh "${appNameRef[0]}" "$pkgVersion" "$Type" "${Arch}"  # Download stock apk from Uptodown
  elif [ "$web" == "APKPure" ]; then
    bash $Simplify/dlAPKPure.sh "${appNameRef[0]}" "$pkgName" "$pkgVersion" "$Arch"  # Download stock apk from APKPure
  fi
  
  if [ -f "${stock_apk_ref[0]}" ]; then
    echo -e "$good ${Green}Downloaded ${appNameRef[0]} APK found:${Reset} ${stock_apk_ref[0]}"
    termux-wake-lock
    patch_app "${stock_apk_ref[0]}" "$appPatchesArgs" "$outputAPK" "$log" "${appNameRef[0]}" "$bugReportUrl"
    termux-wake-unlock
  fi
  
  if [ -f "$outputAPK" ]; then
    
    if [ $pkgName == "com.google.android.youtube" ] || [ $pkgName == "com.google.android.apps.youtube.music" ] || [ "$pkgName" == "com.spotify.music" ]; then
      if [ $su -eq 1 ]; then
        if [ "$pkgName" == "com.google.android.youtube" ]; then
          buttons=("<Install>" "<Mount>" "<Cancel>")
          confirmPrompt "Select ${appNameRef[0]} RVX installation operation" "buttons" "1"
          exit_status=$?
          if [ $exit_status -eq 0 ]; then opt=Install; elif [ $exit_status -eq 1 ]; then opt=Mount; elif [ $exit_status -eq 2 ]; then opt=Cancel; fi
          case $opt in
            I*|i*|"")
              if [ $su -eq 1 ]; then
                pkgInstall "python"  # python install/update
                ! pip list 2>/dev/null | grep -q "apksigcopier" && pip install apksigcopier > /dev/null 2>&1  # install apksigcopier using pip
              fi
              checkCoreLSPosed  # Call the check core patch functions
              echo -e "$running Copy signature from ${appNameRef[0]}.."
              termux-wake-lock
              cs "${stock_apk_ref[0]}" "$outputAPK" "$SimplUsr/${appNameRef[0]}-RVX-CS_v${pkgVersion}-$Arch.apk"
              termux-wake-unlock
              echo -e "$running Please Wait !! Installing Patched ${appNameRef[0]} RVX CS apk.."
              apkInstall "$SimplUsr/${appNameRef[0]}-RVX-CS_v${pkgVersion}-$Arch.apk" ""
              ;;
            M*|m*)
              echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RVX apk.."
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK" &> /dev/null
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK" | tee "$SimplUsr/${appNameRef[0]}-RVX_mount_log.txt"
              rm $outputAPK
              ;;
            C*|c*) echo -e "$notice ${appNameRef[0]} RVX Installaion skipped!" ;;
          esac
        else
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to Mount ${appNameRef[0]} RVX app?" "buttons" && opt=Yes || opt=No
          case $opt in
            y*|Y*|"")
              echo -e "$running Please Wait !! Mounting Patched ${appNameRef[0]} RVX apk.."
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK" &> /dev/null
              su -mm -c "/system/bin/sh $Simplify/apkMount.sh \"${stock_apk_ref[0]}\" $outputAPK" | tee "$SimplUsr/${appNameRef[0]}-RVX_mount_log.txt"
              rm $outputAPK
              ;;
            n*|N*) echo -e "$notice ${appNameRef[0]} RVX Installaion skipped!" ;;
          esac
        fi
      else
        echo -e "$info VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
        buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install VancedMicroG app?" "buttons" && opt=Yes || opt=No
        case $opt in
          y*|Y*|"")
            echo -e "$running Please Wait !! Installing VancedMicroG apk.."
            apkInstall "$VancedMicroG" "com.mgoogle.android.gms/org.microg.gms.ui.SettingsActivity"
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
  local pkgName=$1
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-patches -d=true -f=$pkgName -i=true -o=true -p=false -u -v=false $PatchesRvp
  if [ "$ReadPatchesFile" -eq 1 ]; then
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $ReVancedCLIJar list-patches -d=true -f=$pkgName -i=true -o=true -p=false -u -v=false $PatchesRvp > "$SimplUsr/${pkgName}_list-patches.txt"
  fi
}

if [ $ChangeRVXSource -eq 1 ]; then
  [ $su -eq 1 ] && Spotify="Spotify"
  [ "$cpuAbi" == "arm64-v8a" ] && NetWall="NetWall"
fi

# --- Arrays of apps list that required specific android version ---
if [ $Android -ge 13 ]; then
  apps=(
    CHANGELOG
    Spoof\ Device\ Arch
    List\ of\ Patches
    YouTube
    YT\ Music
    $Spotify
    Reddit
    $NetWall
  )
elif [ $Android -eq 9 ] || [ $Android -eq 10 ] || [ $Android -eq 11 ] || [ $Android -eq 12 ]; then
  apps=(
    CHANGELOG
    Spoof\ Device\ Arch
    List\ of\ Patches
    YouTube
    YT\ Music
    $Spotify
    Reddit
  )
elif [ $Android -eq 8 ] || [ $Android -eq 7 ]; then
  apps=(
    CHANGELOG
    Spoof\ Device\ Arch
    List\ of\ Patches
    YouTube
    YT\ Music
    $Spotify
  )
elif [ $Android -eq 6 ]; then
  apps=(
    CHANGELOG
    Spoof\ Device\ Arch
    List\ of\ Patches
    YouTube
    YT\ Music
  )
elif [ $Android -eq 5 ]; then
  apps=(
    CHANGELOG
    Spoof\ Device\ Arch
    List\ of\ Patches
    YouTube
    "YT Music"
  )
fi

while true; do
  buttons=("<Select>" "<Back>"); if menu apps buttons; then selected="${apps[$selected]}"; else break; fi

  # main conditional control flow
  case "$selected" in
    CHANGELOG)
      [ $release == "latest" ] && tag=$(curl -sL ${auth} "https://api.github.com/repos/$owner/revanced-patches/releases/latest" | jq -r '.tag_name') || tag=$(curl -sL ${auth} "https://api.github.com/repos/$owner/revanced-patches/releases" | jq -r '.[].tag_name | select(contains("dev"))' | head -n 1)
      curl -sL ${auth} "https://api.github.com/repos/$owner/revanced-patches/releases/tags/$tag" | jq -r .body | glow  # Display release notes
      ;;
    Spoof\ Device\ Arch) overwriteArch ;;
    List\ of\ Patches)
      apps_list=("${apps[@]}")
      unset apps_list[0] apps_list[1] apps_list[2]; apps_list=("${apps_list[@]}")  # Remove element at index 0,1,2 and reindex
      buttons=("<Select>" "<Back>"); if menu apps_list buttons; then selected="${apps_list[$selected]}"; fi
      if [ -n "$selected" ]; then
        case "$selected" in
          YouTube)
            pkgName="com.google.android.youtube"
            getListOfPatches "$pkgName"
            ;;
          YT\ Music)
            pkgName="com.google.android.apps.youtube.music"
            getListOfPatches "$pkgName"
            ;;
          Spotify)
            pkgName="com.spotify.music"
            getListOfPatches "$pkgName"
            ;;
          Reddit)
            pkgName="com.reddit.frontpage"
            getListOfPatches "$pkgName"
            ;;
          NetWall)
            pkgName="com.ysy.app.firewall"
            getListOfPatches "$pkgName"
            ;;
        esac
      fi
      ;;
    YouTube)
      pkgName="com.google.android.youtube"
      Arch="universal"
      [ $su -eq 1 ] && Type="APK" || Type="BUNDLE"
      if [ $Android -ge 8 ]; then
        if [ $ChangeRVXSource -eq 0 ]; then
          pkgVersion="20.12.46"
          Type="APK"
        else
          pkgVersion="20.21.37"
          Type="APK"
        fi
        if [ -z "$pkgVersion" ]; then
          getVersion "$pkgName"
          pkgVersion="$pkgVersion"
        fi
      elif [ $Android -eq 7 ] || [ $Android -eq 6 ]; then
        Type="APK"
        pkgVersion="17.34.36"
        BugReportUrl="https://github.com/kitadai31/revanced-patches-android6-7/issues/new?template=bug_report.yml"
      elif [ $Android -eq 5 ]; then
        pkgVersion="16.40.36"
        BugReportUrl="https://github.com/d4n3436/revanced-patches-android5/issues/new?template=bug-issue.yml"
      fi
      [ "$Type" == "APK" ] && stock_apk_path=("$Download/YouTube_v${pkgVersion}-$Arch.apk") || stock_apk_path=("$Download/YouTube_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/YouTube-RVX_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/YouTube-RVX_patch-log.txt"
      appName=("YouTube")
      pkgPatched="app.rvx.android.youtube"
      activityPatched="com.google.android.youtube/.app.honeycomb.Shell\$HomeActivity"
      build_app "$pkgName" "$pkgVersion" "$Type" "$Arch" "APKMirror" "stock_apk_path" "yt_patches_args" "$outputAPK" "$log" "appName" "$BugReportUrl" "$pkgPatched" "$activityPatched"
      ;;
    YT\ Music)
      pkgName="com.google.android.apps.youtube.music"
      if [ $Android -ge 8 ]; then
        if [ $ChangeRVXSource -eq 0 ]; then
          #pkgVersion="8.30.54"
          pkgVersion=
        else
          pkgVersion=""
        fi
        if [ -z "$pkgVersion" ]; then
          getVersion "$pkgName"
          pkgVersion="$pkgVersion"
        fi
      elif [ $Android -eq 7 ]; then
        pkgVersion="6.42.55"
      elif [ $Android -eq 6 ] || [ $Android -eq 5 ]; then
        pkgVersion="6.20.51"
      fi
      Type="APK"
      stock_apk_path=("${Download}/YouTube Music_v${pkgVersion}-${cpuAbi}.apk")
      outputAPK="$SimplUsr/YT-Music-RVX_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/YT-Music-RVX_patch-log.txt"
      appName=("YouTube Music")
      pkgPatched="app.rvx.android.apps.youtube.music"
      activityPatched="com.google.android.apps.youtube.music/.activities.MusicActivity"
      build_app "$pkgName" "$pkgVersion" "$Type" "$cpuAbi" "APKMirror" "stock_apk_path" "yt_music_patches_args" "$outputAPK" "$log" "appName" "$BugReportUrl" "$pkgPatched" "$activityPatched"
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
      Arch="armeabi-v7a, x86, arm64-v8a, x86_64"
      stock_apk_path=("$Download/Spotify_v${pkgVersion}-${Arch[0]}.apk")
      outputAPK="$SimplUsr/Spotify-RVX_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/Spotify-RVX_patch-log.txt"
      activityPatched="com.spotify.music/.MainActivity"
      build_app "$pkgName" "$pkgVersion" "$Type" "$Arch" "Uptodown" "stock_apk_path" "spotify_patches_args" "$outputAPK" "$log" "appName" "$BugReportUrl" "$pkgName" "$activityPatched"
      ;;
    Reddit)
      pkgName="com.reddit.frontpage"
      pkgVersion="2025.52.0"; ARSCLib="true"
      #pkgVersion=""
      if [ -z "$pkgVersion" ]; then
        getVersion "$pkgName"
        pkgVersion="$pkgVersion"
        ARSCLib="false"
      fi
      Type="BUNDLE"
      Arch="universal"
      stock_apk_path=("$Download/Reddit_v${pkgVersion}-$cpuAbi.apk")
      outputAPK="$SimplUsr/Reddit-RVX_v${pkgVersion}-$cpuAbi.apk"
      log="$SimplUsr/Reddit-RVX_patch-log.txt"
      appName=("Reddit")
      activityPatched="com.reddit.frontpage/launcher.default"
      build_app "$pkgName" "$pkgVersion" "$Type" "$Arch" "APKMirror" "stock_apk_path" "reddit_patches_args" "$outputAPK" "$log" "appName" "$BugReportUrl" "$pkgName" "$activityPatched"
      ;;
    NetWall)
      appName=("NetWall N")
      pkgName="com.ysy.app.firewall"
      pkgVersion="1.2.10"
      Type="XAPK"
      Arch="17"
      stock_apk_path=("$Download/NetWall N_v${pkgVersion}-$Arch.apk")
      outputAPK="$SimplUsr/NetWall-RVX_v${pkgVersion}-arm64-v8a.apk"
      log="$SimplUsr/NetWall-RVX_patch-log.txt"
      activityPatched="com.ysy.app.firewall/b.B"
      build_app "$pkgName" "$pkgVersion" "$Type" "$Arch" "APKPure" "stock_apk_path" "netwall_patches_args" "$outputAPK" "$log" "appName" "$BugReportUrl" "$pkgName" "$activityPatched"
      ;;
  esac
  echo; read -p "Press Enter to continue..."
done
######################################################################################################################################################################################
