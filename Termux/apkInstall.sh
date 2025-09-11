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

# Install final apk
apkInstall() {
  local outputAPK=$1
  local activity=$2
  local outputFileName=$(basename "$outputAPK")
  pkgName=$($HOME/aapt2 dump badging "$outputAPK" 2>/dev/null | awk -F"'" '/package/ {print $2}')
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
  else
    local activityClass="$activity"
  fi
  
  if su -c "id" >/dev/null 2>&1; then
    su -c "cp '$outputAPK' '/data/local/tmp/$outputFileName'"
    # Temporary Disable SELinux Enforcing during installation if it not in Permissive
    if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
      su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
      su -c "pm install -i com.android.vending '/data/local/tmp/$outputFileName'"
      su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
    else
      su -c "pm install -i com.android.vending '/data/local/tmp/$outputFileName'"
    fi
    am start -n "$activityClass" &> /dev/null  # launch app after update
    if [ $? != 0 ]; then
      su -c "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    fi
    su -c "rm -f '/data/local/tmp/$outputFileName'"
  elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
    ~/rish -c "cp '$outputAPK' '/data/local/tmp/$outputFileName'" > /dev/null 2>&1  # copy apk to System dir
    ./rish -c "pm install -r -i com.android.vending '/data/local/tmp/$outputFileName'" > /dev/null 2>&1  # -r=reinstall --force-uplow=downgrade
    am start -n "$activityClass" &> /dev/null  # launch app after update
    if [ $? != 0 ]; then
      ~/rish -c "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    fi
    $HOME/rish -c "rm -f '/data/local/tmp/$outputFileName'"  # Cleanup tmp APK
  elif [ "$Android" -le "6" ]; then
    am start -a android.intent.action.VIEW -t application/vnd.android.package-archive -d "file://$outputAPK" > /dev/null 2>&1  # Activity Manager
    sleep 15 && am start -n "$activityClass" &> /dev/null  # launch app after update
  else
    termux-open --view "$outputAPK"  # install apk using Session installer
    sleep 15 && am start -n "$activityClass" &> /dev/null  # launch app after update
  fi
}

apkInstall "$@"
########################################################################################################################################################