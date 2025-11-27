#!/usr/bin/bash

InstallPackageFor=$(jq -r '.InstallPackageFor' "$simplifyJson" 2>/dev/null)
KeepsData=$(jq -r '.KeepsData' "$simplifyJson" 2>/dev/null)
GrantAllRuntimePermissions=$(jq -r '.GrantAllRuntimePermissions' "$simplifyJson" 2>/dev/null)
InstalledAsTestOnly=$(jq -r '.InstalledAsTestOnly' "$simplifyJson" 2>/dev/null)
BypassLowTargetSdkBolck=$(jq -r '.BypassLowTargetSdkBolck' "$simplifyJson" 2>/dev/null)
DisablePlayProtect=$(jq -r '.DisablePlayProtect' "$simplifyJson" 2>/dev/null)
DisableVerifyAdbInstalls=$(jq -r '.DisableVerifyAdbInstalls' "$simplifyJson" 2>/dev/null)
Installer=$(jq -r '.Installer' "$simplifyJson" 2>/dev/null)
Reinstall=$(jq -r '.Reinstall' "$simplifyJson" 2>/dev/null)
EnableRoolback=$(jq -r '.EnableRoolback' "$simplifyJson" 2>/dev/null)

[ $InstallPackageFor -eq 0 ] && cmd="--user $(am get-current-user)" || cmd="--user all"
[ $GrantAllRuntimePermissions -eq 1 ] && cmd+=" -g"
[ $InstalledAsTestOnly -eq 1 ] && cmd+=" -t"
[ $BypassLowTargetSdkBolck -eq 1 ] && cmd+=" --bypass-low-target-sdk-block"
case "$Installer" in
  "com.android.vending") cmd+=" -i com.android.vending" ;;
  "com.android.packageinstaller") cmd+=" -i com.android.packageinstaller" ;;
  "com.android.shell") cmd+=" -i com.android.shell" ;;
  "adb") cmd+=" -i adb" ;;
esac
[ $Reinstall -eq 1 ] && cmd+=" -r"
[ $EnableRoolback -eq 1 ] && cmd+=" --enable-rollback"

# Install final apk
apkInstall() {
  outputAPK=${1}
  activity=$2  # for non-rooted user to launch app after installtion
  iCmd() {
    icmd=${1}
    if [ $su -eq 1 ]; then
      su -c "$icmd"
    elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
      ~/rish -c "$icmd"
    elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
      ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "$icmd"
    fi
  }
  outputFileName=$(basename "$outputAPK")
  app_info=$($HOME/aapt2 dump badging "$outputAPK" 2>/dev/null)
  pkgName=$(awk -F"'" '/package/ {print $2}' <<< "$app_info" | head -1)
  appName=$(awk -F"'" '/application-label:/ {print $2}' <<< "$app_info")
  if [ $su -eq 1 ]; then
    [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=1; } || writeSELinux=0
  fi
  if [ $su -eq 1 ] || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
    iCmdOut=$(iCmd "pm resolve-activity --brief $pkgName")
    activityClass=$(tail -n 1 <<< "$iCmdOut") && unset iCmdOut
    iCmd "cp '$outputAPK' '/data/local/tmp/$outputFileName'"
    [ $DisablePlayProtect -eq 1 ] && iCmd "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
    if [ $DisableVerifyAdbInstalls -eq 1 ]; then
      [ $Android -le 10 ] && iCmd "settings put global package_verifier_enable 0" || iCmd "settings put global verifier_verify_adb_installs 0"  # Disable Verify Adb Installs
    fi
    output=$(iCmd "pm install ${cmd} \"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
    [ $DisablePlayProtect -eq 1 ] && iCmd "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
    if [ $DisableVerifyAdbInstalls -eq 1 ]; then
      [ $Android -le 10 ] && iCmd "settings put global package_verifier_enable 1" || iCmd "settings put global verifier_verify_adb_installs 1"  # Enabled Verify Adb Installs
    fi
    if [[ $output == *"Downgrade detected"* ]] && [ $KeepsData -eq 1 ]; then
      echo -e "${Green}$appName uninstall successfully with keeps app data.${Reset}\n${Yellow}Don't forget to restart Simplify after reboot!${Reset}"
      iCmd "cmd package uninstall -k $pkgName"
      cp "$outputAPK" "$POST_INSTALL"
      sleep 12
      iCmd "reboot"
    fi
    am start -n "$activityClass" &> /dev/null  # launch app after update
    if [ $? != 0 ]; then
      iCmd "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    fi
    iCmd "rm -f '/data/local/tmp/$outputFileName'"
    if [ $EnableRoolback -eq 1 ]; then
      buttons=("<Yes>" "<No>"); confirmPrompt "Is $appName app working correctly?" "buttons" && response=Yes || response=No
      if [[ "$response" == [Yy]* ]]; then
        echo "Great! The $appName app is working properly."
      else
        echo -e "$running Roolback to previous version.."
        iCmd "pm rollback-app $pkgName"
      fi
    fi
  else
    activityClass="$activity"
    if [ $Android -le 6 ]; then
      am start -a android.intent.action.VIEW -t application/vnd.android.package-archive -d "file://$outputAPK" > /dev/null 2>&1  # Activity Manager
      sleep 15 && am start -n "$activityClass" &> /dev/null  # launch app after update
    else
      termux-open --view "$outputAPK"  # install apk using Session installer
      sleep 15 && am start -n "$activityClass" &> /dev/null  # launch app after update
    fi
  fi
  if [ $su -eq 1 ]; then
    [ $writeSELinux -eq 1 ] && su -c "setenforce 1"
  fi
}
########################################################################################################################################################