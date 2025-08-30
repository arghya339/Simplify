#!/system/bin/sh

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
Cyan="\033[96m"
White="\033[37m"
Yellow="\033[93m"
Reset="\033[0m"

# --- Attaching patched apk file to system using su ---
apkMount() {
  # local variables
  local stock=${1}
  local stockFileName=$(basename "$stock")
  local patched=${2}
  local appName=${3}
  local pkgName=$4
  local versionName=$5
  local model=$(getprop ro.product.model)
  local stock_path=$(pm path "$pkgName" | grep base | sed "s/package://g")

  # Mount using Magisk mirror, if available.
  MAGISKTMP="$( magisk --path )" || MAGISKTMP=/sbin
  MIRROR="$MAGISKTMP/.magisk/mirror"
  if [ ! -f "$MIRROR" ]; then
    MIRROR=""
  fi
  
  # Creating some directory
  for DIR in /data/adb/revanced/$pkgName/ /data/adb/post-fs-data.d/ /data/adb/service.d/; do
    if [ ! -e "$DIR" ]; then
      mkdir -p "$DIR"
      echo "$info ${Cyan}$DIR${Reset} created."
    fi
  done
  
  local base_path="/data/adb/revanced/$pkgName/base.apk"
  
  # Purge exist files
  for FILE in "/data/adb/post-fs-data.d/$pkgName.sh" "/data/adb/service.d/$pkgName.sh" "/data/adb/revanced/$pkgName/base.apk"; do
    if [ -e "$FILE" ]; then
        rm "$FILE"
        echo "$info ${Cyan}$FILE${Reset} deleted."
    fi
  done
  
  # Installing stock app if doesn't exist
  echo "$running Checking if stock $appName $versionName is installed.."
  if ! (pm list packages | grep -q "$pkgName" && [ "$(pm dump $pkgName | grep versionName | sed 's/^[[:space:]]*versionName=//')" = "$versionName" ]); then
    echo "$notice $appName $versionName is NOT installed !!"
    echo "$running Installing $appName $versionName.."
    pm install --user 0 -r "$stock"
    if [ $? == 0 ]; then
      echo "$good $appName $versionName installation complete."
    else
      echo "$notice $appName $versionName installation failed! Attempting fallback to install Google Play as installation source."
      cp "$stock" "/data/local/tmp/$stockFileName"
      pm install -i com.android.vending "/data/local/tmp/$stockFileName"
      if [ $? == 0 ]; then
        rm "/data/local/tmp/$stockFileName"
      else
        echo "$bad $appName $versionName installation failed !!"
        rm "/data/local/tmp/$stockFileName"
        exit 1
      fi
    fi
  else
    echo "$good stock $appName $versionName is installed."
  fi
  
  local activityClass=$(pm resolve-activity --brief $pkgName | tail -n 1)
  
  # Force Stop app & Unmount any existing installation to prevent multiple unnecessary mounts.
  echo "$running Force stopping $appName.."
  am force-stop "$pkgName"
  echo "$running Unmounting previous mounts to prevent multiple mounts.."
  grep $pkgName /proc/mounts | while read -r line; do echo $line | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l; done
  
  # Copying patched apk to /data/adb/revanced/$pkgName directory
  if [ -f "$patched" ]; then
    echo "$running Copying patched base.apk file to ${Cyan}/data/adb/revanced/$pkgName/${Reset} dir.."
    cp -f "$patched" "$base_path"
  else
    echo "$bad Patched apk file doesn't exist !!"
    exit 1
  fi
  
  # Change context sensitivity label as 0 & give rwx permissions to copied base.apk
  if [ -f "$base_path" ]; then
    echo "$good base.apk copied successfully."
    echo "$running Setting up base.apk file permissions.."
    chmod 644 "$base_path"  # give read-write (to owner) & read-only (to others) permissions to base.apk
    #chown system:system "$base_path"  # change ownership of user & others both set to system
    chcon u:object_r:apk_data_file:s0  "$base_path"  # Change SELinux user apk file & apk data context sensitivity label as 0 (not sensitive), to assign correct security context for apk-related files to avoid system_server won't be allowed to access it.
  else
    echo "$bad Failed to copying base.apk !!"
    exit 1
  fi

  # Mounting (attaching) with bind (mirror) base.apk with system stock.apk
  if [ -f "$base_path" ] && [ -f "$stock_path" ]; then
    echo "$running Mounting (attaching) $appName.."
    if [ -n "$MIRROR" ]; then
      mount -o bind "${MIRROR}${base_path}" "$stock_path"  # links an existing target (stock) directory to another location (similar symlink that can hides target’s original contents)
    else
      mount -o bind "$base_path" "$stock_path"
    fi
  fi

  # Force stopping app to restart the mounted apk
  echo  "$running Force stopping $appName.."
  am force-stop "$pkgName"
  echo "$running Clearing cache of $appName.."
  pm clear --cache-only "$pkgName"  &> /dev/null

  # Creating service scripts
  echo "$running Creating service scripts.."
  cat << EOF > "/data/adb/service.d/$pkgName.sh"
#!/system/bin/sh

# Mount using Magisk mirror, if available.
MAGISKTMP="\$( magisk --path )" || MAGISKTMP=/sbin
MIRROR="\$MAGISKTMP/.magisk/mirror"
if [ ! -f \$MIRROR ]; then
  MIRROR=""
fi

until [ "\$(getprop sys.boot_completed)" = 1 ]; do sleep 3; done
until [ -d "/sdcard/Android" ]; do sleep 1; done

# Unmount any existing installation to prevent multiple unnecessary mounts.
grep $pkgName /proc/mounts | while read -r line; do echo \$line | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l; done

base_path=$base_path
stock_path=\$(pm path $pkgName | grep base | sed "s/package://g")

chcon u:object_r:apk_data_file:s0  \$base_path
mount -o bind \$MIRROR\$base_path \$stock_path

# Kill the app to force it to restart the mounted APK in case it is already running
am force-stop $pkgName
EOF
  
  # Creating Unmount (Detached or Eject) script
  echo "$running Creating unmount scripts.."
  cat << EOF > "/data/adb/post-fs-data.d/$pkgName.sh"
#!/system/bin/sh

unmount() {
  stock_path=\$(pm path $pkgName | grep base | sed "s/package://g")
  if [ -n \$stock_path ]; then
    grep $pkgName /proc/mounts | while read -r line; do echo \$line | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l; done
  fi
  if [ "\$(ls /data/adb/revanced/ | wc -l)" == "1" ]; then
    for DIR in /data/adb/revanced/ /data/adb/post-fs-data.d/ /data/adb/service.d/; do
      if [ -e \$DIR ]; then
        rm -rf "\$DIR"
      fi
    done
  else
    rm -rf "/data/adb/revanced/$pkgName"
    for FILE in "/data/adb/post-fs-data.d/$pkgName.sh" "/data/adb/service.d/$pkgName.sh"; do
      if [ -e "\$FILE" ]; then
        rm "\$FILE"
      fi
    done
  fi
  am force-stop "$pkgName"
  pm clear --cache-only "$pkgName"  &> /dev/null
}

if [ "\$(getenforce 2>/dev/null)" == "Enforcing" ]; then
  setenforce 0
  unmount
  setenforce 1
else
  unmount
fi
EOF
  
  # Give --rwx-- permissions to service sh
  echo "$running Give execute permissions to service & unmount script.."
  chmod 0755 "/data/adb/service.d/$pkgName.sh"  # give read-write-execute (to owner) & read-execute (to others) permissions
  chmod 0755 "/data/adb/post-fs-data.d/$pkgName.sh"
  
  echo "$good Mount Successfull."
  am start -n "$activityClass" &> /dev/null  # Launch app using activity monitor
  #rm $patched  # remove patched.apk file
}

if [ "$(getenforce 2>/dev/null)" == "Enforcing" ]; then
  setenforce 0  # set SELinux to Permissive mode to unblock unauthorized operations
  apkMount "$@"  # Call function with arguments
  setenforce 1  # set SELinux to Enforcing mode to block unauthorized operations
else
  apkMount "$@"
fi
# su -mm -c "/system/bin/sh apkMount.sh stock.apk patched.apk appName pkg.Name version.Name"  # Mount (Attached): -mm flag required for bind-mounting & unmounting.
# su -mm -c "/system/bin/sh /data/adb/post-fs-data.d/pkg.Name.sh"  # Unmount (Detached / Eject)
###############################################################################################