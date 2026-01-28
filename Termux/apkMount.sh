#!/system/bin/sh

good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

Green="\033[92m"
Red="\033[91m"
Blue="\033[94m"
Cyan="\033[96m"
White="\033[37m"
Yellow="\033[93m"
Reset="\033[0m"

stock="${1}"
patched="${2}"
stockFileName="$(basename "$stock" 2>/dev/null)"
[ -f "/data/local/tmp/aapt2" ] && aapt2="/data/local/tmp/aapt2" || aapt2="/data/data/com.termux/files/home/aapt2"
stockInfo=$($aapt2 dump badging "$stock" 2>/dev/null)
appName=$(awk -F"'" '/application-label:/ {print $2}' <<< "$stockInfo")
pkgName=$(awk -F"'" '/package/ {print $2}' <<< "$stockInfo" | head -1)
versionName=$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<< "$stockInfo")

[ "$(getenforce 2>/dev/null)" == "Enforcing" ] && { setenforce 0; writeSELinux=1; } || writeSELinux=0

installationPath=$(pm path "$pkgName" | grep base | sed "s/package://g")

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

# Purge exist files
for FILE in "/data/adb/post-fs-data.d/$pkgName.sh" "/data/adb/service.d/$pkgName.sh" "/data/adb/revanced/$pkgName/base.apk"; do
  if [ -e "$FILE" ]; then
    rm -f "$FILE"
    echo "$info ${Cyan}$FILE${Reset} deleted."
  fi
done

# Installing stock app if not installed
echo "$running Checking if stock $appName $versionName is installed.."
if ! (pm list packages | grep -q "$pkgName" && [ "$(pm dump $pkgName | grep versionName | sed 's/^[[:space:]]*versionName=//')" = "$versionName" ]); then
  echo "$notice $appName $versionName is Not installed !!"
  echo "$running Installing $appName $versionName.."
  cp "$stock" "/data/local/tmp/$stockFileName"
  pm install --user 0 -r -i com.android.vending "/data/local/tmp/$stockFileName" && { rm -f "/data/local/tmp/$stockFileName"; echo "$good $appName $versionName installation complete."; } || { rm -f "/data/local/tmp/$stockFileName"; echo "$bad $appName $versionName installation failed !!"; exit 1; }
else
  echo "$good stock $appName $versionName is installed."
fi

# Force Stop app & Unmount any existing installation to prevent multiple unnecessary mounts.
echo "$running Force stopping $appName.."
am force-stop "$pkgName"
echo "$running Unmounting previous mounts to prevent multiple mounts.."
grep $pkgName /proc/mounts | while read -r line; do echo $line | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l; done

base="/data/adb/revanced/$pkgName/base.apk"
# Copying patched apk to /data/adb/revanced/$pkgName directory
if [ -f "$patched" ]; then
  echo "$running Copying patched apk to ${Cyan}/data/adb/revanced/$pkgName/${Reset} dir.."
  cp "$patched" "$base"
else
  echo "$bad Patched apk file doesn't exist !!"
  exit 1
fi

# Change context sensitivity label as 0 & give rwx permissions to copied base.apk
if [ -f "$base" ]; then
  echo "$good patched apk copied successfully."
  echo "$running Setting up base.apk file permissions.."
  chmod 644 "$base"  # give read-write (to owner) & read-only (to others) permissions to base.apk
  #chown system:system "$base"  # change ownership of user & others both set to system
  chcon u:object_r:apk_data_file:s0  "$base"  # Change SELinux user apk file & apk data context sensitivity label as 0 (not sensitive), to assign correct security context for apk-related files to avoid system_server won't be allowed to access it.
else
  echo "$bad Failed to copying patched apk !!"
  exit 1
fi

# Mounting (attaching) with bind (mirror): patched base.apk with installed app
if [ -f "$base" ] && [ -f "$installationPath" ]; then
  echo "$running Mounting (attaching) $appName.."
  # links an existing target file (installed app) to another file (patched apk). similar symlink that can hides target’s original contents
  if [ -n "$MIRROR" ]; then
    mount -o bind "${MIRROR}${base}" "$installationPath"
  else
    mount -o bind "$base" "$installationPath"
  fi
fi
! grep -q "$pkgName" /proc/mounts && { echo "$bad Mount failed !!"; exit 1; }

# Force stopping app to restart the mounted apk
echo  "$running Force stopping $appName.."
am force-stop "$pkgName"
echo "$running Clearing cache of $appName.."
pm clear --cache-only "$pkgName"  &> /dev/null

# Creating service scripts
echo "$running Creating service (boot) scripts.."
cat << EOF > "/data/adb/service.d/$pkgName.sh"
#!/system/bin/sh

[ "\$(getenforce 2>/dev/null)" == "Enforcing" ] && { setenforce 0; writeSELinux=1; } || writeSELinux=0

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

base=$base
installationPath=\$(pm path $pkgName | grep base | sed "s/package://g")

chcon u:object_r:apk_data_file:s0  \$base
mount -o bind \$MIRROR\$base \$installationPath

# Kill the app to force it to restart the mounted APK in case it is already running
am force-stop $pkgName

[ \$writeSELinux -eq 1 ] && setenforce 1
EOF

# Creating Unmount (Detached or Eject) script
echo "$running Creating unmount (detached or eject) scripts.."
cat << EOF > "/data/adb/revanced/$pkgName/$pkgName.sh"
#!/system/bin/sh

[ "\$(getenforce 2>/dev/null)" == "Enforcing" ] && { setenforce 0; writeSELinux=1; } || writeSELinux=0

installationPath=\$(pm path $pkgName | grep base | sed "s/package://g")
if [ -n \$installationPath ]; then
  grep $pkgName /proc/mounts | while read -r line; do echo \$line | cut -d " " -f 2 | sed "s/apk.*/apk/" | xargs -r umount -l; done
fi
am force-stop "$pkgName"
pm clear --cache-only "$pkgName"  &> /dev/null

[ "\$(ls /data/adb/revanced/ | wc -l)" == "1" ] && rm -rf /data/adb/revanced || rm -rf "/data/adb/revanced/$pkgName"
for FILE in "/data/adb/revanced/$pkgName/$pkgName.sh" "/data/adb/service.d/$pkgName.sh"; do
  if [ -e "\$FILE" ]; then
    rm -f "\$FILE"
  fi
done

[ \$writeSELinux -eq 1 ] && setenforce 1
EOF

# Give --rwx-- permissions to service sh
echo "$running Give execute permissions to service & unmount script.."
# give read-write-execute (to owner) & read-execute (to others) permissions
chmod 0755 "/data/adb/service.d/$pkgName.sh"
chmod 0755 "/data/adb/revanced/$pkgName/$pkgName.sh"

echo "$good Mount Successfull."
activityClass=$(pm resolve-activity --brief $pkgName | tail -1)
am start -n "$activityClass" &> /dev/null  # Launch app using activity monitor
#rm -f $patched  # remove patched.apk

[ $writeSELinux -eq 1 ] && setenforce 1
# su -mm -c "/system/bin/sh path/to/apkMount.sh stock.apk patched.apk"  # Mount (Attached): -mm flag required for bind-mounting & unmounting.
# su -mm -c "/system/bin/sh /data/adb/revanced/pkg.name/pkg.name.sh"  # Unmount (Detached / Eject)
