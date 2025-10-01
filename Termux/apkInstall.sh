#!/usr/bin/bash

# Colored log indicators
good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

# ANSI Color
Green="\033[92m"
Red="\033[91m"
Blue="\033[94m"
White="\033[37m"
Yellow="\033[93m"
Reset="\033[0m"

Android=$(getprop ro.build.version.release | cut -d. -f1)
Simplify="$HOME/Simplify"
POST_INSTALL="$Simplify/POST_INSTALL"; mkdir -p "$POST_INSTALL"
simplifyJson="$Simplify/simplify.json"
InstallPackageFor=$(jq -r '.InstallPackageFor' "$simplifyJson" 2>/dev/null)
KeepsData=$(jq -r '.KeepsData' "$simplifyJson" 2>/dev/null)
GrantAllRuntimePermissions=$(jq -r '.GrantAllRuntimePermissions' "$simplifyJson" 2>/dev/null)
InstalledAsTestOnly=$(jq -r '.InstalledAsTestOnly' "$simplifyJson" 2>/dev/null)
BypassLowTargetSdkBolck=$(jq -r '.BypassLowTargetSdkBolck' "$simplifyJson" 2>/dev/null)
DisablePlayProtect=$(jq -r '.DisablePlayProtect' "$simplifyJson" 2>/dev/null)
Installer=$(jq -r '.Installer' "$simplifyJson" 2>/dev/null)
Reinstall=$(jq -r '.Reinstall' "$simplifyJson" 2>/dev/null)
EnableRoolback=$(jq -r '.EnableRoolback' "$simplifyJson" 2>/dev/null)

[ $InstallPackageFor -eq 0 ] && cmd="--user $(am get-current-user)" || cmd="--all-users"
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
  local outputAPK=$1
  local activity=$2  # for non-rooted user to launch app after installtion
  local outputFileName=$(basename "$outputAPK")
  app_info=$($HOME/aapt2 dump badging "$outputAPK" 2>/dev/null)
  pkgName=$(awk -F"'" '/package/ {print $2}' <<< "$app_info")
  appName=$(awk -F"'" '/application-label:/ {print $2}' <<< "$app_info")
  if su -c "id" >/dev/null 2>&1; then
    if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
      su -c "setenforce 0"
      local activityClass=$(su -c "pm resolve-activity --brief $pkgName" | tail -n 1)
      su -c "setenforce 1"
    else
      local activityClass=$(su -c "pm resolve-activity --brief $pkgName" | tail -n 1)
    fi
  elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
    local activityClass=$($HOME/rish -c "pm resolve-activity --brief $pkgName" | tail -n 1)
  elif "$HOME/adb" -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | cut -f1) shell "id" >/dev/null 2>&1; then
    local activityClass=$($HOME/adb -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | cut -f1) shell "pm resolve-activity --brief $pkgName" | tail -n 1)
  else
    local activityClass="$activity"
  fi
  
  if su -c "id" >/dev/null 2>&1; then
    su -c "cp '$outputAPK' '/data/local/tmp/$outputFileName'"
    # Temporary Disable SELinux Enforcing during installation if it not in Permissive
    if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
      su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
      [ $DisablePlayProtect -eq 1 ] && su -c "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
      output=$(su -c "pm install ${cmd} '/data/local/tmp/$outputFileName'" 2>&1)
      [ $DisablePlayProtect -eq 1 ] && su -c "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
      if [[ $output == *"Downgrade detected"* ]] && [ $KeepsData -eq 1 ]; then
        echo -e "${Green}$appName uninstall successfully with keeps app data.${Reset}\n${Yellow}Don't forget to restart Simplify after reboot!${Reset}"
        su -c "cmd package uninstall -k $pkgName"
        cp "$outputAPK" "$POST_INSTALL"
        sleep 12
        su -c "reboot"
      fi
      su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
    else
      [ $DisablePlayProtect -eq 1 ] && su -c "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
      output=$(su -c "pm install ${cmd} '/data/local/tmp/$outputFileName'" 2>&1)
      [ $DisablePlayProtect -eq 1 ] && su -c "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
      if [[ $output == *"Downgrade detected"* ]] && [ $KeepsData -eq 1 ]; then
        echo -e "${Green}$appName uninstall successfully with keeps app data.${Reset}\n${Yellow}Don't forget to restart Simplify after reboot!${Reset}"
        su -c "cmd package uninstall -k $pkgName"
        cp "$outputAPK" "$POST_INSTALL"
        sleep 12
        su -c "reboot"
      fi
    fi
    am start -n "$activityClass" &> /dev/null  # launch app after update
    if [ $? != 0 ]; then
      su -c "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    fi
    su -c "rm -f '/data/local/tmp/$outputFileName'"
  elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
    ~/rish -c "cp '$outputAPK' '/data/local/tmp/$outputFileName'" > /dev/null 2>&1  # copy apk to System dir
    [ $DisablePlayProtect -eq 1 ] && $HOME/rish -c "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
    output=$(~/rish -c "pm install ${cmd} '/data/local/tmp/$outputFileName'" 2>&1)  # -r=reinstall
    [ $DisablePlayProtect -eq 1 ] && ~/rish -c "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
    if [[ $output == *"Downgrade detected"* ]] && [ $KeepsData -eq 1 ]; then
      echo -e "${Green}$appName uninstall successfully with keeps app data.${Reset}\n${Yellow}Don't forget to restart Shizuku & Simplify after reboot!${Reset}"
      ~/rish -c "cmd package uninstall -k $pkgName"
      cp "$outputAPK" "$POST_INSTALL"
      sleep 12
      ~/rish -c "reboot"
    fi
    am start -n "$activityClass" &> /dev/null  # launch app after update
    if [ $? != 0 ]; then
      ~/rish -c "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    fi
    $HOME/rish -c "rm -f '/data/local/tmp/$outputFileName'"  # Cleanup tmp APK
  elif "$HOME/adb" -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | awk '{print $1}') shell "id" >/dev/null 2>&1; then
    [ $DisablePlayProtect -eq 1 ] && "$HOME/adb" -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | awk '{print $1}') shell "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
    output=$(~/adb -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | cut -f1) shell pm install ${cmd} "$outputAPK" 2>&1)
    #$HOME/adb -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | awk '{print $1}') install ${cmd} "$outputAPK" 2>&1
    #~/adb -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | awk '{print $1}') shell cmd package install ${cmd} "$outputAPK" > /dev/null 2>&1
    [ $DisablePlayProtect -eq 1 ] && ~/adb -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | awk '{print $1}') shell "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
    if [[ $output == *"Downgrade detected"* ]] && [ $KeepsData -eq 1 ]; then
      echo -e "${Green}$appName uninstall successfully with keeps app data.${Reset}\n${Yellow}Don't forget to restart Simplify after reboot!${Reset}"
      ~/adb -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | cut -f1) shell "cmd package uninstall -k $pkgName"
      cp "$outputAPK" "$POST_INSTALL"
      sleep 12
      "$HOME/adb" -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | awk '{print $1}') "reboot"
    fi
    am start -n "$activityClass" &> /dev/null  # launch app after update
    [ $? != 0 ] && ~/adb -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | awk '{print $1}') shell "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
  elif [ "$Android" -le "6" ]; then
    am start -a android.intent.action.VIEW -t application/vnd.android.package-archive -d "file://$outputAPK" > /dev/null 2>&1  # Activity Manager
    sleep 15 && am start -n "$activityClass" &> /dev/null  # launch app after update
  else
    termux-open --view "$outputAPK"  # install apk using Session installer
    sleep 15 && am start -n "$activityClass" &> /dev/null  # launch app after update
  fi
  
  if su -c "id" >/dev/null 2>&1 || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | cut -f1) shell "id" >/dev/null 2>&1; then
    if [ $EnableRoolback -eq 1 ]; then
      read -r -p "Is the $appName app working correctly? [Y/n]: " response
      if [[ "$response" == [Yy]* ]]; then
        echo "Great! The $appName app is working properly."
      else
        echo -e "$running Roolback to previous version.."
        if su -c "id" >/dev/null 2>&1; then
          if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
            su -c "setenforce 0"
            su -c "pm rollback-app $pkgName"
            su -c "setenforce 1"
          else
            su -c "pm rollback-app $pkgName"
          fi
        elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
          $HOME/rish -c "pm rollback-app $pkgName"
        elif "$HOME/adb" -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | cut -f1) shell "id" >/dev/null 2>&1; then
          $HOME/adb -s $(~/adb devices 2>/dev/null | head -2 | tail -1 | awk '{print $1}') shell "pm rollback-app $pkgName"
        fi
      fi
    fi
  fi
}

apkInstall "$@"
########################################################################################################################################################
