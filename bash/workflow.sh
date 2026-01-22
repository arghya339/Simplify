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
        echo "App Version         : $version"
        echo "hasBeenAntisplit    : $hasBeenAntisplit"
      }
      echo "--------------------Tool Info--------------------" > "$patchedLOG"
      toolInfo >> "$patchedLOG"
      echo "------------------System Info------------------" >> "$patchedLOG"
      systemInfo >> "$patchedLOG"
      if [ $isAndroid == true ]; then
        echo "------------------Device Info-------------------" >> "$patchedLOG"
        deviceInfo >> "$patchedLOG"
      else
        echo "-------------------Host Info--------------------" >> "$patchedLOG"
        hostInfo >> "$patchedLOG"
      fi
      echo "---------------------Assets---------------------" >> "$patchedLOG"
      assetsInfo >> "$patchedLOG"
      echo "-------------------Patch Args------------------" >> "$patchedLOG"
      echo "${patchCmd[*]}" >> "$patchedLOG"
      echo -e "$running Patching $appName.."
      [ $isAndroid == true ] && termux-wake-lock
      echo "-------------------Patch Log-------------------" >> "$patchedLOG"
      "${patchCmd[@]}" 2>&1 | tee -a "$patchedLOG"
      echo "~~~~~~~~~~~~~~~END~~~~~~~~~~~~~~~" >> "$patchedLOG"
      [ $isAndroid == true ] && termux-wake-unlock
      [ "$source" == "RVX-ARSCLib" ] && { mv $SimplUsr/base.apk $patchedAPK; rm -f $SimplUsr/revanced.keystore; }
      rm -f "$SimplUsr/$patchedAppsFilenameFormat.keystore"
      rm -f "$SimplUsr/$patchedAppsFilenameFormat-options.json"
      if [ -f "$patchedAPK" ]; then
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
              echo "--------------------Tool Info--------------------" > "$SimplUsr/mountLog.txt"
              toolInfo >> "$SimplUsr/mountLog.txt"
              echo "------------------System Info------------------" >> "$SimplUsr/mountLog.txt"
              systemInfo >> "$SimplUsr/mountLog.txt"
              [ $isAndroid == false ] && { echo "-------------------Host Info--------------------" >> "$SimplUsr/mountLog.txt"; hostInfo >> "$SimplUsr/mountLog.txt"; }
              echo "------------------Device Info-------------------" >> "$SimplUsr/mountLog.txt"
              deviceInfo >> "$SimplUsr/mountLog.txt"
              echo "-------------------Assets-----------------------" >> "$SimplUsr/mountLog.txt"
              assetsInfo >> "$SimplUsr/mountLog.txt"
              echo "-------------------Mount Log-------------------" >> "$SimplUsr/mountLog.txt"
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
              echo "~~~~~~~~~~~~~~~END~~~~~~~~~~~~~~~" >> "$SimplUsr/mountLog.txt"
            fi
          fi
        fi
      else
        isPatchingSucceeded=false
        bugReportURL="https://github.com/$patches/issues"
        if [ $isAndroid == true ]; then termux-open-url "$bugReportURL"; elif [ $isMacOS == true ]; then open "$bugReportURL"; else xdg-open "$bugReportURL" &>/dev/null; fi
        rm -rf "$SimplUsr/$patchedAppsFilenameFormat-temporary-files"
      fi
      echo; read -p "Press Enter to continue..."
      [ "$rmPatchedApk" == "true" ] && { rm -f "$patchedAPK"; patched=null; } || patched="$patchedAPK"
      [ $isPatchingSucceeded == true ] && patchedAppsJson
    fi
  fi
}