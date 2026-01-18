#!/usr/bin/bash

# Install final apk
apkInstall() {
  targetAPK=${1}
  activity=$2  # for non-rooted user to launch app after installtion
  iCmd() {
    icmd=${1}
    if [ "$su" == "1" ] || [ "$su" == "true" ]; then
      su -c "$icmd"
    elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
      ~/rish -c "$icmd"
    elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
      ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "$icmd"
    fi
  }
  outputFileName=$(basename "$targetAPK")
  app_info=$($HOME/aapt2 dump badging "$targetAPK" 2>/dev/null)
  pkgName=$(awk -F"'" '/package/ {print $2}' <<< "$app_info" | head -1)
  appLabel=$(awk -F"'" '/application-label:/ {print $2}' <<< "$app_info")
  if [ "$su" == "1" ] || [ "$su" == "true" ]; then
    [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=1; } || writeSELinux=0
  fi
  if [[ "$su" == "1" || "$su" == "true" ]] || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
    iCmdOut=$(iCmd "pm resolve-activity --brief $pkgName")
    activityClass=$(tail -n 1 <<< "$iCmdOut") && unset iCmdOut
    iCmd "cp '$targetAPK' '/data/local/tmp/$outputFileName'"
    ([ "$DisablePlayProtect" == "1" ] || [ "$DisablePlayProtect" == "true" ]) && iCmd "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
    if ([ "$DisableVerifyAdbInstalls" == "1" ] || [ "$DisableVerifyAdbInstalls" == "true" ]); then
      [ $Android -le 10 ] && iCmd "settings put global package_verifier_enable 0" || iCmd "settings put global verifier_verify_adb_installs 0"  # Disable Verify Adb Installs
    fi
    output=$(iCmd "pm install ${pmCmd} \"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
    if [[ "$output" == *"signatures do not match"* ]]; then
      echo -e "$notice The current app has a different signature than the patched one!"
      buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to uninstall the current app and proceed?" "buttons" "1" && response=Yes || response=No
      if [ "$response" == "Yes" ]; then
        iCmd "pm uninstall $pkgName"
        output=$(iCmd "pm install ${pmCmd} \"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
      fi
    fi
    ([ "$DisablePlayProtect" == "1" ] || [ "$DisablePlayProtect" == "true" ]) && iCmd "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
    if ([ "$DisableVerifyAdbInstalls" == "1" ] || [ "$DisableVerifyAdbInstalls" == "true" ]); then
      [ $Android -le 10 ] && iCmd "settings put global package_verifier_enable 1" || iCmd "settings put global verifier_verify_adb_installs 1"  # Enabled Verify Adb Installs
    fi
    if [[ $output == *"Downgrade detected"* ]] && { [ "$KeepsData" == "1" ] || [ "$KeepsData" == "true" ]; }; then
      echo -e "${Green}$appLabel uninstall successfully with keeps app data.${Reset}\n${Yellow}Don't forget to restart Simplify after reboot!${Reset}"
      iCmd "cmd package uninstall -k $pkgName"
      cp "$targetAPK" "$POST_INSTALL"
      echo; read -p "Press Enter to reboot..."
      iCmd "reboot"
    fi
    am start -n "$activityClass" &> /dev/null  # launch app after install
    if [ $? != 0 ]; then
      iCmd "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    fi
    iCmd "rm -f '/data/local/tmp/$outputFileName'"
    if [ "$EnableRoolback" == "1" ] || [ "$EnableRoolback" == "true" ]; then
      buttons=("<Yes>" "<No>"); confirmPrompt "Is $appLabel app working correctly?" "buttons" && response=Yes || response=No
      if [[ "$response" == [Nn]* ]]; then
        echo -e "$running Roolback to previous version.."
        iCmd "pm rollback-app $pkgName"
        am start -n "$activityClass" &> /dev/null
      fi
    fi
  else
    activityClass="$activity"
    if [ $Android -le 6 ]; then
      am start -a android.intent.action.VIEW -t application/vnd.android.package-archive -d "file://$targetAPK" > /dev/null 2>&1  # Activity Manager
    else
      termux-open --view "$targetAPK"  # install apk using Session installer
    fi
    sleep 15 && am start -n "$activityClass" &> /dev/null  # launch app after install
  fi
  if [ "$su" == "1" ] || [ "$su" == "true" ]; then
    [ $writeSELinux -eq 1 ] && su -c "setenforce 1"
  fi
}
########################################################################################################################################################
