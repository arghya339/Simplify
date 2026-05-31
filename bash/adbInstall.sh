#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

adbInstall() {
  targetAPK=${1}

  targetFileName=$(basename "$targetAPK" 2>/dev/null)
  app_info=$($aapt2 dump badging "$targetAPK" 2>/dev/null)
  pkgName=$(awk -F"'" '/package/ {print $2}' <<< "$app_info" | head -1)
  appLabel=$(awk -F"'" '/application-label:/ {print $2}' <<< "$app_info")
  activityClass=$(adb -s $serial shell "pm resolve-activity --brief $pkgName" | tail -1)
  Android=$(adb -s $serial shell getprop ro.build.version.release | cut -d. -f1)
  [ $DisablePlayProtect == true ] && adb -s $serial shell "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
  if [ $DisableVerifyAdbInstalls == true ]; then
    [ $Android -le 10 ] && adb -s $serial shell "settings put global package_verifier_enable 0" || adb -s $serial shell "settings put global verifier_verify_adb_installs 0"  # Disable Verify Adb Installs
  fi
  adb -s $serial push "$targetAPK" "/data/local/tmp/$targetFileName" 2>/dev/null
  output=$(adb -s $serial shell pm install ${pmCmd} "\"/data/local/tmp/${targetFileName}\"" 2>&1); echo "$output"
  if [[ "$output" == *"signatures do not match"* ]]; then
    echo -e "$notice The current app has a different signature than the patched one!"
    confirmPrompt "Do you want to uninstall the current app and proceed?" "ynButtons" "1" && response=Yes || response=No
    if [ "$response" == "Yes" ]; then
      adb -s $serial uninstall $pkgName
      output=$(adb -s $serial shell pm install ${pmCmd} "\"/data/local/tmp/${targetFileName}\"" 2>&1); echo "$output"
    fi
  fi
  adb -s $serial shell rm -f "/data/local/tmp/$targetFileName"
  [ $DisablePlayProtect == true ] && adb -s $serial shell "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
  if [ $DisableVerifyAdbInstalls == true ]; then
    [ $Android -le 10 ] && adb -s $serial shell "settings put global package_verifier_enable 1" || adb -s $serial shell "settings put global verifier_verify_adb_installs 1"  # Enabled Verify Adb Installs
  fi
  if [[ $output == *"Downgrade detected"* ]] && [ $KeepsData == true ]; then
    adb -s $serial shell "cmd package uninstall -k $pkgName"
    echo -e "${Green}$appLabel uninstall successfully with keeps app data.${Reset}\n${Yellow}Reboot required !!${Reset}"
    echo; read -p "Press Enter to reboot..."
    adb -s $serial "reboot"
    until [ "$(adb -s $serial shell "getprop sys.boot_completed" 2>&1)" == "1" ]; do
      printf "Waiting for device..." && sleep 1 && printf "\r\033[K"
    done && echo -e "$good boot completed."
    adb -s $serial shell pm install ${pmCmd} "\"/data/local/tmp/${targetFileName}\""
  fi
  am start -n "$activityClass" &> /dev/null  # launch app after install
  [ $? != 0 ] && adb -s $serial shell "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
  if [ $EnableRoolback == true ]; then
    confirmPrompt "Is $appLabel app working correctly?" "ynButtons" && response=Yes || response=No
    if [[ "$response" == [Nn]* ]]; then
      echo -e "$running Roolback to previous version.."
      adb -s $serial shell "pm rollback-app $pkgName"
      am start -n "$activityClass" &> /dev/null
    fi
  fi
}
