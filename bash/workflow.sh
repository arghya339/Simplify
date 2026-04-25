#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

patchingWorkflow() {
    hasBeenAntisplit=false
    unset filePath
    pButtons=("<APKMirror>" "<Storage>"); confirmPrompt "Select APK source" "pButtons" && response="APKMirror" || response="Storage"
    case "$response" in
      APKMirror)
        mapfile -t versions < <(jq -r --arg pkg "$package" '.[] | select(.package == $pkg) | .versions[]?' $sourceDir/apps.json)
        if [ ${#versions[@]} -gt 1 ]; then
          if menu versions cButtons; then
            version="${versions[selected]}"
          else
            version="${versions[0]}"
          fi
        else
          version="${versions[0]}"
        fi
        pButtons=("<Auto>" "<Manual>"); confirmPrompt "Select versionURL fetching method" "pButtons" && response="Auto" || response="Manual"
        if [ -z "$version" ]; then
          if [ "$response" == "Auto" ]; then
            fetchReleaseURL
          else
            scrapeVersionsList
          fi
        else
          if [ "$response" == "Auto" ]; then
            fetchVersionURL
          else
            scrapeVersionsList
          fi
        fi
        versionCode="$vcode"
        ;;
      Storage)
        fileSelector
        package="$pkgName"; version="$versionName"; appName="$appLabel"
      ;;
    esac
    [ -n "$filePath" ] && stockAPK="$filePath"
  if [ -f "$stockAPK" ]; then
    patchedAppsFilenameFormat="$appName-${source}_v$version-$patchesVersion"
    patchedAPK="$SimplUsr/$patchedAppsFilenameFormat.apk"
    patchedLOG="$SimplUsr/$patchedAppsFilenameFormat.txt"
    managePatches
    if [ $? -eq 0 ]; then
      assetsInfo() {
        echo "CLI Source          : $cli"
        echo "Patches Source      : $patches"
        [ $cliv -lt 5 ] && echo "Integrations Source : $integrations"
        echo "CLI Version         : $cliVersion"
        echo "Patches Version     : $patchesVersion"
        [ $cliv -lt 5 ] && echo "Integrations Version: $integrationsVersion"
        echo "App Name            : $appName"
        echo "Package Name        : $package"
        echo "App Version         : $version($versionCode)"
        echo "hasBeenAntisplit    : $hasBeenAntisplit"
      }
      echo "-----------------Tool Info-----------------" > "$patchedLOG"
      toolInfo >> "$patchedLOG"
      echo "----------------System Info----------------" >> "$patchedLOG"
      systemInfo >> "$patchedLOG"
      if [ $isAndroid == true ]; then
        echo "----------------Device Info----------------" >> "$patchedLOG"
        deviceInfo >> "$patchedLOG"
      else
        echo "-----------------Host Info-----------------" >> "$patchedLOG"
        hostInfo >> "$patchedLOG"
      fi
      echo "-------------------Assets------------------" >> "$patchedLOG"
      assetsInfo >> "$patchedLOG"
      echo "-----------------Patch Args----------------" >> "$patchedLOG"
      for Cmd in "${patchCmd[@]}"; do
        [[ $Cmd == *" "* ]] && echo -n "\"$Cmd\" " >> "$patchedLOG" || echo -n "$Cmd " >> "$patchedLOG"
      done
      echo >> "$patchedLOG"
      echo -e "$running Patching $appName.."
      [ $isAndroid == true ] && termux-wake-lock
      echo "-----------------Patch Log-----------------" >> "$patchedLOG"
      if [ $EnableOptionalFeatures == true ]; then
        if [ "$cli" == "MorpheApp/morphe-cli" ]; then
          tasks=("Deleting existing temporary files directory" "Decoding all resources" "Executing patches" "Compiling patched dex files" "Compiling modified resources" "Aligning APK" "Signing APK" "Purging temporary files" "Purged resource cache directory")
        else
          tasks=("Deleting existing temporary files directory" "Decoding manifest" "Decoding resources" "Compiling patched dex files" "Compiling patched resources" "Aligning APK" "Signing APK" "Purging temporary files" "Purged resource cache directory")
        fi
        status=(false false false false false false false false false)
        while true; do
          unset task
          for ((i=0; i<${#tasks[@]}; i++)); do
            ( grep -q "${tasks[i]}" "$patchedLOG" && [ ${status[i]} == false ] ) && { task="${tasks[i]}"; status[i]=true; break; }
          done
          if [ -n "$task" ]; then
            if [ "$task" != "Purged resource cache directory" ]; then
              if [ $isAndroid == true ] && [ $foundTermuxAPI == true ]; then
                termux-notification --title "SimplifyNext" --content "Patcher: $task" --id "patching_task" --ongoing
              elif [ $isMacOS == true ]; then
                osascript -e "display notification \"Patcher: $task\" with title \"SimplifyNext\""
              elif [ $isAndroid == false ]; then
                notify-send "SimplifyNext" "Patcher: $task"
              fi
            else
              ([ $isAndroid == true ] && [ $foundTermuxAPI == true ]) && termux-notification-remove "patching_task"
              break
            fi
          fi
        sleep 0.5
        done &
      fi
      time_now=$(date +%s)
      "${patchCmd[@]}" 2>&1 | tee -a "$patchedLOG"
      time_diff=$(($(date +%s) - time_now))
      if [ $time_diff -ge 60 ]; then
        time_taken=$((time_diff / 60))
        unit=minute
      else
        time_taken=$time_diff
        unit=second
      fi
      [ $time_taken -ne 1 ] && unit="${unit}s"
      echo "Patching takes about $time_taken $unit"
      echo "~~~~~~~~~~~~~~~~~~~~END~~~~~~~~~~~~~~~~~~~~" >> "$patchedLOG"
      [ $isAndroid == true ] && termux-wake-unlock
      [ "$source" == "RVX-ARSCLib" ] && { mv $SimplUsr/base.apk $patchedAPK; rm -f $SimplUsr/revanced.keystore; }
      rm -f "$SimplUsr/$patchedAppsFilenameFormat.keystore"
      rm -f "$SimplUsr/$patchedAppsFilenameFormat-options.json"
      if [ -f "$patchedAPK" ]; then
        if [ $EnableOptionalFeatures == true ]; then
          if [ $isAndroid == true ] && [ $foundTermuxAPI == true ]; then
            termux-media-player play "$simplifyNext/done.mp3" >/dev/null
          elif [ $isMacOS == true ]; then
            afplay "$simplifyNext/done.mp3"
          elif mpv -V &>/dev/null; then
            mpv "$simplifyNext/done.mp3" >/dev/null
          fi
        fi
        isPatchingSucceeded=true
        [ "$rmStockApk" == true ] && { rm -f "$stockAPK"; stock=null; } || stock="$stockAPK"
        stockPKG="$package"
        patchedPKG=$($aapt2 dump badging "$patchedAPK" | awk -F"'" '/package/ {print $2}' | head -1)
        installed=false
        mount=false
        if [ $isAndroid == true ] || [ -n "$serial" ]; then
          pButtons=("<Install>" "<Cancel>"); confirmPrompt "Do you want to install patched $appName APK?" "pButtons" && response="Install" || response="Cancel"
          if [ "$response" == "Install" ]; then
            installed=true
            if [ $su == true ]; then
              pButtons=("<Install>" "<Mount>"); confirmPrompt "Select installation type" "pButtons" && response="Install" || response="Mount"
            fi
            if [ "$response" == "Install" ]; then
              [ $isAndroid == true ] && apkInstall "$patchedAPK"
              [ $isAndroid == false ] && adbInstall "$patchedAPK"
            else
              mount=true
              echo "-----------------Tool Info-----------------" > "$SimplUsr/mountLog.txt"
              toolInfo >> "$SimplUsr/mountLog.txt"
              echo "----------------System Info----------------" >> "$SimplUsr/mountLog.txt"
              systemInfo >> "$SimplUsr/mountLog.txt"
              [ $isAndroid == false ] && { echo "-----------------Host Info-----------------" >> "$SimplUsr/mountLog.txt"; hostInfo >> "$SimplUsr/mountLog.txt"; }
              echo "----------------Device Info----------------" >> "$SimplUsr/mountLog.txt"
              deviceInfo >> "$SimplUsr/mountLog.txt"
              echo "-------------------Assets------------------" >> "$SimplUsr/mountLog.txt"
              assetsInfo >> "$SimplUsr/mountLog.txt"
              echo "-----------------Mount Log-----------------" >> "$SimplUsr/mountLog.txt"
              if [ $isAndroid == true ]; then
                su -mm -c "/system/bin/sh $simplifyNext/apkMount.sh \"$stockAPK\" \"$patchedAPK\"" | tee -a "$SimplUsr/mountLog.txt"
              else
                [ ! -f "$simplifyNext/aapt2_$cpuAbi" ] && curl -L --progress-bar -o "$simplifyNext/aapt2_$cpuAbi" "https://github.com/arghya339/aapt2/releases/download/all/aapt2_$cpuAbi"
                adb -s "$serial" shell "[ ! -f '/data/local/tmp/aapt2' ]" && { adb -s "$serial" push "$simplifyNext/aapt2_$cpuAbi" /data/local/tmp/aapt2 >/dev/null 2>&1 && adb -s "$serial" shell "chmod +x /data/local/tmp/aapt2"; }
                adb -s "$serial" push "$simplifyNext/apkMount.sh" /data/local/tmp/apkMount.sh >/dev/null 2>&1 && adb -s "$serial" shell "chmod +x /data/local/tmp/apkMount.sh"
              
                stockFileName=$(basename "$stockAPK" 2>/dev/null)
                patchedFileName=$(basename "$patchedAPK" 2>/dev/null)
                adb -s $serial push "$stockAPK" "/data/local/tmp"
                adb -s $serial push "$patchedAPK" "/data/local/tmp"
                adb -s $serial exec-out su -mm -c "/system/bin/sh /data/local/tmp/apkMount.sh \"/data/local/tmp/$stockFileName\" \"/data/local/tmp/$patchedFileName\"" | tee -a "$SimplUsr/mountLog.txt"
                adb -s $serial shell "rm -f \"/data/local/tmp/$stockFileName\" \"/data/local/tmp/$patchedFileName\""
              fi
              echo "~~~~~~~~~~~~~~~~~~~~END~~~~~~~~~~~~~~~~~~~~" >> "$SimplUsr/mountLog.txt"
            fi
          fi
        fi
      else
        if [ $EnableOptionalFeatures == true ]; then
          if [ $isAndroid == true ] && [ $foundTermuxAPI == true ]; then
            termux-media-player play "$simplifyNext/error.mp3" >/dev/null
            termux-clipboard-set < "$patchedLOG"
          elif [ $isMacOS == true ]; then
            afplay "$simplifyNext/error.mp3"
            pbcopy < "$patchedLOG"
          else
            mpv -V &>/dev/null && mpv "$simplifyNext/error.mp3" >/dev/null
            wl-copy -v &>/dev/null && wl-copy < "$patchedLOG"
          fi
        fi
        isPatchingSucceeded=false
        if grep -q "OutOfMemory" "$patchedLOG"; then
          echo -e "$bad ${Red}OutOfMemoryError${Reset}: ${Yellow}Device RAM overloaded!${Reset}\n ${Blue}Solutions${Reset}:\n   1. ${Yellow}Close background apps.${Reset}\n   2. ${Yellow}Use device with >${memSize}GB RAM for patching apk.${Reset}"
        else
          bugReportURL="https://github.com/$patches/issues"
          curl -fsL "$bugReportURL" &>/dev/null || bugReportURL="https://gitlab.com/$patches/-/work_items"
          if [ $isAndroid == true ]; then termux-open-url "$bugReportURL"; elif [ $isMacOS == true ]; then open "$bugReportURL"; else xdg-open "$bugReportURL" &>/dev/null; fi
        fi
        rm -rf "$SimplUsr/$patchedAppsFilenameFormat-temporary-files"
      fi
      echo; read -p "Press Enter to continue..."
      [ "$rmPatchedApk" == "true" ] && { rm -f "$patchedAPK"; patched=null; } || patched="$patchedAPK"
      [ $isPatchingSucceeded == true ] && patchedAppsJson
    fi
  fi
}