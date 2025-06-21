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

# Install final apk
apkInstall() {
  local outputAPK=$1
  local outputFileName=$2
  local pkgName=$3
  local activity=$4
  local Model=$(getprop ro.product.model)
  
  if su -c "id" >/dev/null 2>&1; then
    su -c "cp '$outputAPK' '/data/local/tmp/$outputFileName'"
    rm "$outputAPK"
    # Temporary Disable SELinux Enforcing during installation if it not in Permissive
    if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
      su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
      su -c "pm install -i com.android.vending '/data/local/tmp/$outputFileName'"
      su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
    else
      su -c "pm install -i com.android.vending '/data/local/tmp/$outputFileName'"
    fi
    am start -n $pkgName/$activity > /dev/null 2>&1  # launch app after update
    if [ $? != 0 ]; then
      su -c "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    fi
    su -c "rm '/data/local/tmp/$outputFileName'"
  elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
    ~/rish -c "cp '$outputAPK' '/data/local/tmp/$outputFileName'" > /dev/null 2>&1  # copy apk to System dir
    ./rish -c "pm install -r -i com.android.vending '/data/local/tmp/$outputFileName'" > /dev/null 2>&1  # -r=reinstall --force-uplow=downgrade
    INSTALL_STATUS=$?  # Capture exit status of the install command
    am start -n $pkgName/$activity > /dev/null 2>&1  # launch app after update
    if [ $? != 0 ]; then
      ~/rish -c "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    fi
    $HOME/rish -c "rm '/data/local/tmp/$outputFileName'"  # Cleanup tmp APK
  elif [ $OEM == "Xiaomi" ] || [ $OEM == "Poco" ] || [ $arch == "x86_64" ]; then
    if [ $OEM == "Xiaomi" ] || [ $OEM == "Poco" ]; then
      echo -e $notice "${Yellow}MIUI Optimization detected! Please manually install app from${Reset} ${Blue}file://$outputAPK${Reset}"
    else
      echo -e $notice "${Yellow}There was a problem open the app package using Termux API! Please manually install app from${Reset} Files: $Model > ${Blue}Simplify${Reset} > $outputAPK"
    fi
    am start -n com.google.android.documentsui/com.android.documentsui.files.FilesActivity > /dev/null 2>&1  # Open Android Files
  elif [ $Android -le 13 ]; then
    am start -a android.intent.action.VIEW -t application/vnd.android.package-archive -d "file://$outputAPK" > /dev/null 2>&1  # Activity Manager
    INSTALL_STATUS=$?
    if [ "$INSTALL_STATUS" != "0" ]; then
      termux-open "$outputAPK"
      FALLBACK_INSTALL_STATUS=$?
    fi
    if [ "$INSTALL_STATUS" == "0" ] || [ "$FALLBACK_INSTALL_STATUS" == "0" ]; then
      am start -n $pkgname/$activity > /dev/null 2>&1  # launch app after update
    else
      echo -e $notice "${Yellow}There was a problem open the app package using Termux API! Please manually install app from${Reset} Files: $Model > ${Blue}Simplify${Reset} > $outputFileName"
    fi
  else
    termux-open "$outputAPK"  # install apk using Session installer
    INSTALL_STATUS=$?
    if [ "$INSTALL_STATUS" != "0" ]; then
      am start -a android.intent.action.VIEW -t application/vnd.android.package-archive -d "file://$outputAPK" > /dev/null 2>&1  # Activity Manager
      FALLBACK_INSTALL_STATUS=$?
    fi
    if [ "$INSTALL_STATUS" == "0" ] || [ "$FALLBACK_INSTALL_STATUS" == "0" ]; then
      am start -n $pkgname/$activity > /dev/null 2>&1  # launch app after update
    else
      echo -e $notice "${Yellow}There was a problem open the app package using Termux API! Please manually install app from${Reset} Files: $Model > ${Blue}Simplify${Reset} > $outputFileName"
    fi
  fi
}

apkInstall "$@"
##########################################################################################