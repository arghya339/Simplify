#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

isRipLocale="true"  # RipLocale: options: true / false | it's delete locale (language) from patched apk file except device specific locale by default
isRipDpi="true"  # RipDpi: options: true / false | it's delete dpi from patched apk file except device specific dpi by default
isRipLib="true"  # RipLib: options: true / false | it's delete lib dir from patched apk file except device specific arch lib by default

isPrintArt=true

isAutoUpdatesScript="true"
isAutoUpdatesDependencies="true"

isShowUniversalPatches="false"

isButtonsSymbol="27A4"
isToggleSymbol="Toggle"
isSecureSymbol="Asterisk"

isRmStockApk="false"
isRmPatchedApk="false"

isU=0  # Install Package for: options: 0 (default-user) / 1 (all-users)
isK=false  # Allow Downgrade with keeps App data: options: 0 (false) / 1 (true) | default 0 because it's required reboot after pkg install.
isG=false  # Grant All Runtime Permissions: options: 0 (false) / 1 (true) | default 0 due to Security Risk
isT=false  # Installed as test-only app: options: 0 (false) / 1 (true)
isL=true  # Bypass Low Target SDK Bolck: options: 1 (true) / 0 (false) | it's allow Android 14+ to install apps that target below API level 23 (Android 6 and below).
isV=true  # Disable Play Protect Package Verification: options: 1 (true) / 0 (false)
isA=false  # Disable Verify ADB installs: options: 0 (false) / 1 (true) | 'Disable Play Protect' is Enabled; this makes Enabling 'Disable Verify ADB installs' unnecessary
isI="com.android.vending"  # Installer package: options: com.android.vending (PlayStore) / com.android.packageinstaller (PackageInstaller) / com.android.shell (Shell) / adb
isR=true  # Reinstall Existing Installed Package: options: 1 (true) / 0 (false) | default 1 because without this app can't be installed if installed and to-be-installed version code are same.
isB=false  # Enable Version Roolback: options: 0 (false) / 1 (true)

config() {
  key="$1"
  value="$2"
  jsonFile="$3"

  [ -z "$jsonFile" ] && jsonFile="$simplifyNextJson"
  
  [ ! -f "$jsonFile" ] && jq -n "{}" > "$jsonFile"
  jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$jsonFile" > temp.json && mv temp.json "$jsonFile"
}

all_key=(RipLocale RipDpi RipLib printArt AutoUpdatesScript AutoUpdatesDependencies ShowUniversalPatches ButtonsSymbol ToggleSymbol SecureSymbol rmStockApk rmPatchedApk jdk)
all_value=("$isRipLocale" "$isRipDpi" "$isRipLib" "$isPrintArt" "$isAutoUpdatesScript" "$isAutoUpdatesDependencies" "$isShowUniversalPatches" "$isButtonsSymbol" "$isToggleSymbol" "$isSecureSymbol" "$isRmStockApk" "$isRmPatchedApk" "$isJdk")
[ $isAndroid == true ] && { all_key+=(AutoUpdatesTermux); all_value+=("$isAutoUpdatesTermux"); }
all_key+=(InstallPackageFor KeepsData GrantAllRuntimePermissions InstalledAsTestOnly DisablePlayProtect DisableVerifyAdbInstalls Installer Reinstall EnableRoolback)
all_value+=("$isU" "$isK" "$isG" "$isT" "$isV" "$isA" "$isI" "$isR" "$isB")
if [ -n "$Android" ]; then
  [ $Android -ge 14 ] && { all_key+=(BypassLowTargetSdkBolck); all_value+=("$isL"); }
fi
for i in "${!all_key[@]}"; do
  ! jq -e --arg key "${all_key[i]}" 'has($key)' "$simplifyNextJson" &>/dev/null && config "${all_key[i]}" "${all_value[i]}"
done

reloadConfig() {
  RipLocale="$(jq -r '.RipLocale' "$simplifyNextJson" 2>/dev/null)"
  RipDpi="$(jq -r '.RipDpi' "$simplifyNextJson" 2>/dev/null)"
  RipLib="$(jq -r '.RipLib' "$simplifyNextJson" 2>/dev/null)"

  printArt="$(jq -r '.printArt' "$simplifyNextJson" 2>/dev/null)"

  AutoUpdatesScript="$(jq -r '.AutoUpdatesScript' "$simplifyNextJson" 2>/dev/null)"
  AutoUpdatesDependencies="$(jq -r '.AutoUpdatesDependencies' "$simplifyNextJson" 2>/dev/null)"

  ShowUniversalPatches="$(jq -r '.ShowUniversalPatches' "$simplifyNextJson" 2>/dev/null)"

  rmStockApk="$(jq -r '.rmStockApk' "$simplifyNextJson" 2>/dev/null)"
  rmPatchedApk="$(jq -r '.rmPatchedApk' "$simplifyNextJson" 2>/dev/null)"

  AutoUpdatesTermux=$(jq -r '.AutoUpdatesTermux' "$simplifyNextJson" 2>/dev/null)
  jdk=$(jq -r '.jdk' "$simplifyNextJson" 2>/dev/null)
}; reloadConfig

if gh auth status >/dev/null 2>&1; then
  ghToken="$(gh auth token)"
elif jq -e '.PAT' "$simplifyNextJson" >/dev/null 2>&1; then
  ghToken="$(jq -r '.PAT' "$simplifyNextJson" 2>/dev/null)"
fi
[ -n "$ghToken" ] && ghAuthH="-H \"Authorization: Bearer $ghToken\"" || ghAuthH=""

genPMCmd() {
  InstallPackageFor=$(jq -r '.InstallPackageFor' "$simplifyNextJson" 2>/dev/null)
  KeepsData=$(jq -r '.KeepsData' "$simplifyNextJson" 2>/dev/null)
  GrantAllRuntimePermissions=$(jq -r '.GrantAllRuntimePermissions' "$simplifyNextJson" 2>/dev/null)
  InstalledAsTestOnly=$(jq -r '.InstalledAsTestOnly' "$simplifyNextJson" 2>/dev/null)
  if [ -n "$Android" ]; then
    [ $Android -ge 14 ] && BypassLowTargetSdkBolck=$(jq -r '.BypassLowTargetSdkBolck' "$simplifyNextJson" 2>/dev/null)
  fi
  DisablePlayProtect=$(jq -r '.DisablePlayProtect' "$simplifyNextJson" 2>/dev/null)
  DisableVerifyAdbInstalls=$(jq -r '.DisableVerifyAdbInstalls' "$simplifyNextJson" 2>/dev/null)
  Installer=$(jq -r '.Installer' "$simplifyNextJson" 2>/dev/null)
  Reinstall=$(jq -r '.Reinstall' "$simplifyNextJson" 2>/dev/null)
  EnableRoolback=$(jq -r '.EnableRoolback' "$simplifyNextJson" 2>/dev/null)
  
  if [ $isAndroid == true ]; then
    [ $InstallPackageFor -eq 0 ] && pmCmd="--user $(am get-current-user)" || pmCmd="--user all"
  else
    ([ -n "$serial" ] && [ $InstallPackageFor -eq 0 ]) && pmCmd="--user $(adb -s $serial shell am get-current-user)" || pmCmd="--user all"
  fi
  [ "$GrantAllRuntimePermissions" == true ] && pmCmd+=" -g"
  [ "$InstalledAsTestOnly" == true ] && pmCmd+=" -t"
  if [ -n "$Android" ]; then
    if [ $Android -ge 14 ]; then
      [ "$BypassLowTargetSdkBolck" == true ] && pmCmd+=" --bypass-low-target-sdk-block"
    fi
  fi
  case "$Installer" in
    "com.android.vending") pmCmd+=" -i com.android.vending" ;;
    "com.android.packageinstaller") pmCmd+=" -i com.android.packageinstaller" ;;
    "com.android.shell") pmCmd+=" -i com.android.shell" ;;
    "adb") pmCmd+=" -i adb" ;;
  esac
  [ "$Reinstall" == true ] && pmCmd+=" -r"
  [ $EnableRoolback == true ] && pmCmd+=" --enable-rollback"
}; genPMCmd

if [ $isMacOS == true ] && [ -n $serial ]; then
  config "ABI" "$cpuAbi"
  config "LOCALE" "$locale"
  config "DENSITY" "$density"
fi
if [ $isMacOS == true ]; then
  jq -e '.ABI != null' "$simplifyNextJson" >/dev/null 2>&1 && cpuAbi="$(jq -r '.ABI' "$simplifyNextJson" 2>/dev/null)" || cpuAbi=
  jq -e '.LOCALE != null' "$simplifyNextJson" >/dev/null 2>&1 && locale="$(jq -r '.LOCALE' "$simplifyNextJson" 2>/dev/null)" || locale=
  jq -e '.DENSITY != null' "$simplifyNextJson" >/dev/null 2>&1 && density="$(jq -r '.DENSITY' "$simplifyNextJson" 2>/dev/null)" || density=
fi

ripLocaleGen() {
  if [ $RipLocale == true ] && [ -n "$locale" ]; then
    if [ $isAndroid == true ]; then
      locale=$(getprop persist.sys.locale | cut -d'-' -f1)
      [ -z $locale ] && locale=$(getprop ro.product.locale | cut -d'-' -f1)
    else
      locale="$(jq -r '.LOCALE' "$simplifyNextJson" 2>/dev/null)"
    fi
  else
    locale="[a-z][a-z]"
  fi
}; ripLocaleGen

ripDpiGen() {
  if [ $RipDpi == true ] && [ -n "$density" ]; then
    if [ "$density" -le "120" ]; then
      lcd_dpi="ldpi"  # Low Density
    elif [ "$density" -le "160" ]; then
      lcd_dpi="mdpi"  # Medium Density
    elif [ "$density" -le "213" ]; then
      lcd_dpi="tvdpi"  # TV Density
    elif [ "$density" -le "240" ]; then
      lcd_dpi="hdpi"  # High Density
    elif [ "$density" -le "320" ]; then
      lcd_dpi="xhdpi"  # Extra High Density
    elif [ "$density" -le "480" ]; then
      lcd_dpi="xxhdpi"  # Extra Extra High Density
    elif [ "$density" -gt "480" ] || [ "$density" -ge "640" ]; then
      lcd_dpi="xxxhdpi"  # Extra Extra Extra High Density
    else
      lcd_dpi="*dpi"
    fi
  else
    lcd_dpi="*dpi"
  fi
}; ripDpiGen

ripLibGen() {
  if [ $RipLib == true ] && [ -n "$cpuAbi" ]; then
    all_arch="arm64-v8a armeabi-v7a x86_64 x86"
    ripLib=""
    for current_arch in $all_arch; do
      if [ "$current_arch" != "$cpuAbi" ]; then
        if [ -z "$ripLib" ]; then
          ripLib="--rip-lib=$current_arch"
        else
          ripLib="$ripLib --rip-lib=$current_arch"
        fi
      fi
    done
  else
    ripLib=""
  fi
}; ripLibGen

dlBCP() {
  # Download BCP (Bouncy Castle Provider) | https://mvnrepository.com/artifact/org.bouncycastle/bcprov-jdk18on
  latest=$(curl -s "https://repo1.maven.org/maven2/org/bouncycastle/bcprov-jdk18on/maven-metadata.xml" | awk -F'[<>]' '/<latest>/{print $3}')
  localBCP=$(find "$simplifyNext" -type f -name "bcprov-jdk18on-*.jar" -print -quit)
  if [ -f "$localBCP" ]; then
    [ "$(basename "$localBCP" 2>/dev/null)" != "bcprov-jdk18on-$latest.jar" ] && rm -f "$localBCP"
  fi
  [ ! -f "$simplifyNext/bcprov-jdk18on-$latest.jar" ] && curl -C - -L --progress-bar -o "$simplifyNext/bcprov-jdk18on-$latest.jar" "https://repo1.maven.org/maven2/org/bouncycastle/bcprov-jdk18on/$latest/bcprov-jdk18on-$latest.jar"
}

# Generate BKS (Bouncy Castle Keystore) Keystore
genKeystore() {
  dlBCP
  # Generate BKS Keystore
  pButtons=("<Auto>" "Manually"); confirmPrompt "How would you like to generate the Android Keystore?" "pButtons" && response="Auto" || response="Manually"
  if [ "$response" == "Auto" ]; then
    [ -f "$simplifyNext/ks.json" ] && rm -f "$simplifyNext/ks.json"
    [ -f "$simplifyNext/ks.keystore" ] && rm -f "$simplifyNext/ks.keystore"
    $keytool -genkey -v -keystore "$simplifyNext/ks.keystore" -storetype BKS -providerclass org.bouncycastle.jce.provider.BouncyCastleProvider -providerpath "$simplifyNext/bcprov-jdk18on-$latest.jar" -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456
  else
    keys=(alias CN OU O L S C storepass keypass)
    prompts=(alias "CN (Common Name)" "OU (Organizational Unit)" "O (Organization)" "L (Locality)" "S (State)" "C (Country Code)" storepass keypass)
    descriptions=("name for your key" "your name or company name" "your department or team name" "your company name" "your city" "your state" "2-letter country code" "password for ks.keystore file itself" "password for individual key inside ks.keystore file")
    inputs=()
    ksJson="{"
    for i in "${!keys[@]}"; do
      echo -e "ⓘ ${descriptions[i]}"
      read -r -p "${prompts[i]}: " input
      [ -z "$input" ] && { echo -e "$notice ${prompts[i]} cannot be empty!! Please try again."; ((i--)); continue; }
      inputs+=("$input")
      ksJson+="\"${keys[i]}\": \"${inputs[i]}\","
    done
    ksJson="${ksJson%,}}"
    jq <<< "$ksJson"
    confirmPrompt "Would you like to generate keystore?" "ynButtons" && response=Yes || response=No
    if [ "$response" == "Yes" ]; then
      jq <<< "$ksJson" > $simplifyNext/ks.json
      [ -f "$simplifyNext/ks.keystore" ] && rm -f "$simplifyNext/ks.keystore"
      $keytool -genkey -v -keystore "$simplifyNext/ks.keystore" -storetype BKS -providerclass org.bouncycastle.jce.provider.BouncyCastleProvider -providerpath "$simplifyNext/bcprov-jdk18on-$latest.jar" -alias "${inputs[0]}" -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=${inputs[1]}, OU=${inputs[2]}, O=${inputs[3]}, L=${inputs[4]}, S=${inputs[5]}, C=${inputs[6]}" -storepass "${inputs[7]}" -keypass "${inputs[8]}"
    fi
  fi

  # Verification
  if [ -f "$simplifyNext/ks.keystore" ]; then
    list=$($keytool -list -v -keystore "$simplifyNext/ks.keystore" -storetype BKS -providerclass org.bouncycastle.jce.provider.BouncyCastleProvider -providerpath "$simplifyNext/bcprov-jdk18on-$latest.jar" -storepass 123456)
    grep "Keystore type" <<< "$list" | awk -F': ' '{print $2}'
    grep "Owner:" <<< "$list" | cut -d: -f2- | xargs
  fi
}

toolInfo() {
  echo "Tool Name   : SimplifyNext"
  echo "Tool Version: $localVersion"
  echo "Tool URL    : https://github.com/arghya339/Simplify/tree/next"
}

systemInfo() {
  [ $isAndroid == true ] && echo "TERMUX_VERSION: $TERMUX_VERSION"
  echo "Bash Version  : $(bash --version | head -1 | cut -d' ' -f4)"
  echo "Java Version  : $(java --version | head -1 | cut -d' ' -f2)"
}

hostInfo() {
  if [ $isMacOS == true ]; then
    echo "Model Identifier: $(system_profiler SPHardwareDataType | grep "Model Identifier" | awk -F: '{print $2}' | xargs)"
    echo "Product         : $(sw_vers -productName) $(sw_vers -ProductVersion)"
    echo "BuildVersion    : $(sw_vers -BuildVersion)"
    echo "Kernel          : $(uname -s) $(uname -r)"
    echo "Architecture    : $(uname -m)"
    totalGB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    pageSize=$(vm_stat | awk '/page size/ {print int($8)}')
    freePages=$(vm_stat | awk '/Pages free/ {print int($3)}')
    inactivePages=$(vm_stat | awk '/Pages inactive/ {print int($3)}')
    availableMB=$(( (freePages + inactivePages) * pageSize / 1024 / 1024 ))
    availableGB=$((availableMB / 1024))
    echo "Memory          : ${totalGB}Gi total, ${availableGB}Gi available"
    echo "Storage         : $(df -h / | awk 'NR==2 {print $2 " total, " $4 " available"}')"
    echo "Processor Name  : $(sysctl -n machdep.cpu.brand_string)"
    echo "Processor Speed : $(system_profiler SPHardwareDataType | grep "Processor Speed" | cut -d: -f2 | xargs)"
    echo "Processor Core  : $(sysctl -n hw.ncpu)"
    ( nvram boot-args 2>/dev/null | grep -q "alcid=\|keepsyms" && kextstat 2>/dev/null | grep -q "Lilu\|WhateverGreen\|AppleALC\|VirtualSMC" ) && echo "isOpenCore      : true" || echo "isOpenCore      : false"
  else
    echo "Hardware Model  : $(cat /sys/class/dmi/id/sys_vendor) $(cat /sys/class/dmi/id/product_name)"
    #echo "OS Name         : $(hostnamectl | grep "Operating System" | cut -d: -f2 | xargs)"
    echo "OS Name         : $(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')"
    echo "OS Version      : $(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')"
    echo "Kernel          : Linux $(uname -r)"
    echo "Architecture    : $(uname -m)"
    echo "Memory          : $(free -h | awk '/Mem:/ {print $2 " total,", $7 " available"}')"
    echo "Storage         : $(df -h / | awk 'NR==2 {print $2 " total, " $4 " available"}')"
    echo "CPU Model       : $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
    echo "CPU Frequency   : $(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{printf "%.1f GHz\n", $4/1000}')"
    echo "CPU Core        : $(nproc --all)"
    lsmod | grep -iq vbox && echo "isVirtualBox    : true" || echo "isVirtualBox    : false"
  fi
}

deviceInfo() {
  if [ $isAndroid == true ]; then
    echo "Model          : $(getprop ro.product.model)"
    echo "Android Version: $(getprop ro.build.version.release) ($(getprop ro.build.version.sdk))"
    echo "Build          : $(getprop ro.build.fingerprint)"
    echo "Kernel         : $(uname -s) $(uname -n) $(uname -r)"
    echo "Supported Archs: $(getprop ro.product.cpu.abilist)"
    echo "Memory         : $(free -h | awk '/Mem:/ {print $2 " total,", $7 " available"}')"
    echo "Storage        : $(df -h /storage/emulated | awk 'NR==2 {print $2 " total, " $4 " available"}')"
    echo "CPU Model      : $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
    cpuFreq=$(lscpu | grep "CPU max MHz" | awk '{printf "%.1f GHz\n", $4/1000}' | xargs)
    [ -z "$cpuFreq" ] && cpuFreq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk '{printf "%.1f GHz\n", $4/1000}')
    echo "CPU Frequency  : $cpuFreq"
    echo "CPU Core       : $(nproc --all)"
    getprop ro.hardware | grep -q -E "ranchu|goldfish|blue_stacks|waydroid|vbox" && echo "isEmulator     : true" || echo "isEmulator     : false"
  elif [ -n "$serial" ]; then
    echo "Model          : $(adb -s $serial shell getprop ro.product.model)"
    echo "Android Version: $(adb -s $serial shell getprop ro.build.version.release) ($(adb -s $serial shell getprop ro.build.version.sdk))"
    echo "Build          : $(adb -s $serial shell getprop ro.build.fingerprint)"
    echo "Kernel         : $(adb -s $serial shell uname -s) $(adb -s $serial shell uname -n) $(adb -s $serial shell uname -r)"
    echo "Supported Archs: $(adb -s $serial shell getprop ro.product.cpu.abilist)"
    echo "Memory         : $(adb -s $serial shell free -h | awk '/Mem:/ {print $2 " total,", $7 " available"}')"
    echo "Storage        : $(adb -s $serial shell df -h /storage/emulated | awk 'NR==2 {print $2 " total, " $4 " available"}')"
    cpuModel=$(adb -s $serial shell cat /proc/cpuinfo | grep "model name" | cut -d: -f2 | sort -u | xargs)
    [ -z $cpuModel ] && cpuModel=$(adb -s $serial shell cat /proc/cpuinfo | sed 's/0xd05/Cortex-A55/g; s/0xd0b/Cortex-A76/g' | grep "CPU part" | cut -d: -f2 | sort -u | xargs)
    echo "CPU Model      : $cpuModel"
    cpuFreq=$(adb -s $serial shell "cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null" | awk '{printf "%.1f GHz\n", $1/1000000}')
    [ -z "$cpuFreq" ] && cpuFreq=$(adb -s $serial shell 'grep "cpu MHz" /proc/cpuinfo' | head -1 | awk '{printf "%.1f GHz\n", $4/1000}')
    echo "CPU Frequency  : $cpuFreq"
    echo "CPU Core       : $(adb -s $serial shell nproc --all)"
    adb -s $serial shell getprop ro.hardware | grep -q -E "ranchu|goldfish|blue_stacks|waydroid|vbox" && echo "isEmulator     : true" || echo "isEmulator     : false"
  fi
  [ $su == true ] && echo "Device Rooted  : Yes" || echo "Device Rooted  : No"
}

configure() {
  configureOptions=(Customize Updates Delete Import Export Reset Advanced About)
  [ $isAndroid == true ] && configureOptions+=(Share)
  configureDescriptions=(toggleSymbol simplifyNextUpdates deleteApps importPatchSelection exportPatchSelection resetPatchSelection ripLib aboutSimplifyNext shareSimplifyNext)
  while true; do
    menu configureOptions bButtons configureDescriptions || break
    configureOption="${configureOptions[selected]}"
    case "$configureOption" in
      Customize)
        customizeOptions=(buttonsSymbol toggleSymbol secureSymbol showScriptBrandingOnLaunch)
        while true; do
          reloadConfig
          menu customizeOptions bButtons || break
          customizeOption="${customizeOptions[selected]}"
          case "$customizeOption" in
            buttonsSymbol)
              symbols=("➤" "➣" "➢" "▶" "▷" "❯" "❱" "»" "⨠" "➜" "➞" "➔" "➠" "➾" "ᐳ")
              unicodes=("27A4" "27A3" "27A2" "25B6" "25B7" "276F" "2771" "00AA" "2A20" "279C" "279E" "2794" "27A0" "27BE" "1433")
              if menu unicodes bButtons symbols; then
                unicode="${unicodes[selected]}"
                config "ButtonsSymbol" "$unicode"
              fi
              ;;
            toggleSymbol)
              symbols=("[ ]|[*]" "[ ]|[#]" "[ ]|[+]" "[0]|[1]" "[ ]|[✓]" "☐|☑" " |🜲" "〇━|━⚪" "〇|🔘" "⬡|⬢" "☆|★" "⟡|✦" "⬨|⬧" "⚐|⚑")
              names=(asteriskBox hashBox plusBox Binary tickBox checkBox Regulus Toggle radioButton Hexagon Star Sparkle Dymond Flag)
              if menu names bButtons symbols; then
                name="${names[selected]}"
                config "ToggleSymbol" "$name"
              fi
              ;;
            secureSymbol)
              symbols=("*" "●" "#" "×" "★" "✦" "⬧" "⬢" "■" "$")
              names=(Asterisk solidCircle Hash Multiplication Star Sparkle Dymond Hexagon Square dollarSign)
              if menu names bButtons symbols; then
                name="${names[selected]}"
                config "SecureSymbol" "$name"
              fi
              ;;
            showScriptBrandingOnLaunch)
              confirmPrompt "Show simplifyNext branding on launch" tfButtons "$printArt" && isPrintArt=true || isPrintArt=false
              config "printArt" "$isPrintArt"
              ;;
          esac
          source $simplifyNext/symbol.sh
        done
        ;;
      Updates)
        updatesOptions=("Check for script updates" "viewChangelogs" "Check for dependencies updates" "Auto updates script on launch" "Auto updates dependencies on launch")
        updatesDescriptions=("Manually updating simplifyNext" "Manually updating dependencies" "Check out the latest changes in this update" "Auto updates simplifyNext on launch" "")
        [ $isAndroid == true ] && { updatesOptions+=("Auto updates Termux on launch"); updatesDescriptions+=(""); }
        while true; do
          reloadConfig
          menu updatesOptions bButtons updatesDescriptions || break
          updatesOption="${updatesOptions[selected]}"
          case "$updatesOption" in
            "Check for script updates") checkInternet && updates ;;
            viewChangelogs) glow $simplifyNext/CHANGELOG.md; echo; read -p "Press Enter to continue..." ;;
            "Check for dependencies updates") checkInternet && dependencies ;;
            "Auto updates script on launch")
              confirmPrompt "Auto updates simplifyNext on launch" tfButtons "$AutoUpdatesScript" && autoupdates=true || autoupdates=false
              config "AutoUpdatesScript" "$autoupdates"
              ;;
            "Auto updates dependencies on launch")
              confirmPrompt "Auto updates dependencies on launch" tfButtons "$AutoUpdatesDependencies" && autoupdates=true || autoupdates=false
              config "AutoUpdatesDependencies" "$autoupdates"
              ;;
            "Auto updates Termux on launch")
              confirmPrompt "AutoUpdatesTermux" tfButtons "$AutoUpdatesTermux" && isAutoUpdatesTermux=true || isAutoUpdatesTermux=false
              config "AutoUpdatesTermux" "$isAutoUpdatesTermux"
          esac
        done
        ;;
      Delete)
        deleteOptions=(deleteStockApk deletePatchedApk deleteAllPatchedLog deleteAllMountLog deleteCli deletePatches deleteIntegrations deleteMicroG deleteKeystore deleteStockApksAfterSuccessfulPatching deletePatchedApksAfterInstallation uninstallSimplifyNext)
        while true; do
          reloadConfig
          menu deleteOptions bButtons || break
          deleteOption="${deleteOptions[selected]}"
          case "$deleteOption" in
            deleteStockApk)
              while true; do
                mapfile -t stockApks < <(find "$Download" -maxdepth 1 -type f -name "*_v*-*.apk" -exec basename {} \;)
                if [ ${#stockApks[@]} -gt 0 ]; then
                  menu stockApks bButtons || break
                  stockApk="${stockApks[selected]}"
                  rm -f "$Download/$stockApk"
                else
                  break
                fi
              done
              ;;
            deletePatchedApk)
              while true; do
                mapfile -t patchedApks < <(find "$SimplUsr" -maxdepth 1 -type f -name "*-*_v*-*.apk" -exec basename {} \;)
                if [ ${#patchedApks[@]} -gt 0 ]; then
                  menu patchedApks bButtons || break
                  patchedApk="${patchedApks[selected]}"
                  rm -f "$SimplUsr/$patchedApk"
                else
                  break
                fi
              done
              ;;
            deleteAllPatchedLog) find "$SimplUsr" -maxdepth 1 -type f -name "*-*_v*-*.txt" -exec echo "Deleting: {}" \; -exec rm -f {} \; 2>/dev/null ;;
            deleteAllMountLog) rm -f "$SimplUsr/mountLog.txt" "$SimplUsr/MountLog.txt" ;;
            deleteCli)
              while true; do
                clis=($(basename -a "$simplifyNext"/[0-9] 2>/dev/null))
                if [ ${#clis[@]} -gt 0 ]; then
                  menu clis bButtons || break
                  cliv=${clis[selected]}
                  rm -rf "$simplifyNext/$cliv"
                else
                  break
                fi
              done
              ;;
            deletePatches)
              sources=($(jq -r '.[].source' $simplifyNext/sources.json))
              while true; do
                existsSources=()
                for source in "${sources[@]}"; do
                  if [ -d "$simplifyNext/$source" ]; then
                    [ -n "$(find "$simplifyNext/$source" -maxdepth 1 -type f \( -name 'patches-*.rvp' -o -name 'patches-*.jar' -o -name 'patches-*.mpp' \) -print -quit)" ] && existsSources+=($source)
                  fi
                done
                if [ ${#existsSources[@]} -gt 0 ]; then
                  menu existsSources bButtons || break
                  existsSource="${existsSources[selected]}"
                  find "$simplifyNext/$existsSource" -maxdepth 1 -type f \( -name 'patches-*.rvp' -o -name 'patches-*.jar' -o -name 'patches-*.mpp' \) -delete
                  sleep 0.5
                else
                  break
                fi
              done
              ;;
            deleteIntegrations)
              sources=($(jq -r '.[].source' $simplifyNext/sources.json))
              while true; do
                existsSources=()
                for source in "${sources[@]}"; do
                  if [ -d "$simplifyNext/$source" ]; then
                    [ -n "$(find "$simplifyNext/$source" -maxdepth 1 -type f -name "revanced-integrations-*.apk" -print -quit)" ] && existsSources+=($source)
                  fi
                done
                if [ ${#existsSources[@]} -gt 0 ]; then
                  menu existsSources bButtons || break
                  existsSource="${existsSources[selected]}"
                  find "$simplifyNext/$existsSource" -maxdepth 1 -type f -name "revanced-integrations-*.apk" -delete
                  sleep 0.5
                else
                  break
                fi
              done
              ;;
            deleteMicroG)
              microgs=()
              [ -d "$SimplUsr/ReVanced-GmsCore" ] && microgs+=("ReVanced/GmsCore")
              [ -d "$SimplUsr/YT-Advanced-GmsCore" ] && microgs+=("YT-Advanced/GmsCore")
              [ -d "$SimplUsr/inotia00-VancedMicroG" ] && microgs+=("inotia00/VancedMicroG")
              [ -d "$SimplUsr/MorpheApp-MicroG-RE" ] && microgs+=("MorpheApp/MicroG-RE")
              if [ ${#microgs[@]} -gt 0 ]; then
                if menu microgs bButtons; then
                  microg="${microgs[selected]}"
                  rm -rf "$SimplUsr/$(sed 's|/|-|g' <<< "$microg")"
                  sleep 0.5
                fi
              fi
              ;;
            deleteKeystore)
              if [ -f "$simplifyNext/ks.keystore" ] && [ -f "$simplifyNext/ks.json" ]; then
                storepass=$(jq -r '.storepass' "$simplifyNext/ks.json")
              elif [ -f "$simplifyNext/ks.keystore" ] && [ ! -f "$simplifyNext/ks.json" ]; then
                storepass="123456"
              fi
              if [ -n "$storepass" ]; then
                dlBCP
                $keytool -list -v -keystore "$simplifyNext/ks.keystore" -storetype BKS -providerclass org.bouncycastle.jce.provider.BouncyCastleProvider -providerpath "$simplifyNext/bcprov-jdk18on-$latest.jar" -storepass "$storepass"
                pButtons=("<Confirm>" "<Cancel>"); confirmPrompt "Are you sure you want to delete this keystore?" "pButtons" "1" && response=Confirm || response=Cancel
                [ "$response" == "Confirm" ] && rm -f "$simplifyNext/ks.keystore" "$simplifyNext/ks.json"
              fi
              ;;
            deleteStockApksAfterSuccessfulPatching)
              confirmPrompt "deleteStockApksAfterSuccessfulPatching" tfButtons "$rmStockApk" && response=true || response=false
              config "rmStockApk" "$response"
              ;;
            deletePatchedApksAfterInstallation)
              confirmPrompt "deletePatchedApksAfterInstallation" tfButtons "$rmPatchedApk" && response=true || response=false
              config "rmPatchedApk" "$response"
              ;;
            uninstallSimplifyNext)
              confirmPrompt "Are you sure you want to uninstall simplifyNext?" "ynButtons" "1" && response=Yes || response=No
              case "$response" in
                Yes)
                  echo -ne "${Red}Type 'yes' in capital to continue: ${Reset}" && read -r userInput
                  case "$userInput" in
                    YES)
                      [ -d "$simplifyNext" ] && rm -rf "$simplifyNext"
                      [ -d "$SimplUsr" ] && rm -rf "$SimplUsr"
                      [ -f "$HOME/.simplifyx.sh" ] && rm -f "$HOME/.simplifyx.sh"
                      if [ $isAndroid == true ]; then
                        [ -f "$PREFIX/bin/simplifyx" ] && rm -f "$PREFIX/bin/simplifyx"
                        [ -f "$HOME/.shortcuts/simplifyx" ] && rm -f ~/.shortcuts/simplifyx
                        [ -f "$HOME/.termux/widget/dynamic_shortcuts/simplifyx" ] && rm -f ~/.termux/widget/dynamic_shortcuts/simplifyx
                      else
                        [ -f "/usr/local/bin/simplifyx" ] && rm -f "/usr/local/bin/simplifyx"
                      fi
                      confirmPrompt "Do you want to remove this script-related dependency?" "ynButtons" "1" && response=Yes || response=No
                      case "$response" in
                        Yes)
                          if [ $isAndroid == true ]; then
                            pkgUninstall "aria2"
                            pkgUninstall "jq"
                            pkgUninstall "pup"
                            pkgUninstall "openjdk-$jdk"
                            pkgUninstall "bsdtar"
                            pkgUninstall "pv"
                            pkgUninstall "glow"
                          elif [ $isMacOS == true ]; then
                            formulaeUninstall "aria2"
                            formulaeUninstall "jq"
                            formulaeUninstall "pv"
                            formulaeUninstall "pup"
                            formulaeUninstall "android-platform-tools"
                            formulaeUninstall "android-commandlinetools"
                            formulaeUninstall "$jdk"
                            formulaeUninstall "glow"
                          elif [ $isFedora == true ]; then
                            dnfRemove "aria2"
                            dnfRemove "jq"
                            dnfRemove "pv"
                            sudo rm -f "/usr/local/bin/pup"
                            dnfRemove "android-tools"
                            rm -rf "$HOME/Android/Sdk/cmdline-tools/latest"
                            dnfRemove "$jdk"
                            dnfRemove "glow"
                          elif [ $isDebian == true ]; then
                            aptRemove "curl"
                            aptRemove "aria2"
                            aptRemove "pv"
                            sudo rm -f "/usr/local/bin/pup"
                            aptRemove "adb"
                            aptRemove "aapt"
                            aptRemove "$jdk"
                            aptRemove "glow"
                          elif [ $isArchLinux == true ]; then
                            pacRemove "aria2"
                            pacRemove "pv"
                            sudo rm -f "/usr/local/bin/pup"
                            pacRemove "android-tools"
                            yay -R android-sdk-build-tools --noconfirm
                            pacRemove "$jdk"
                            pacRemove "glow"
                          elif [ $isOpenSUSE == true ]; then
                            pkgRemove "aria2"
                            pkgRemove "pv"
                            sudo rm -f "/usr/local/bin/pup"
                            pkgRemove "android-tools"
                            rm -rf "$HOME/Android/Sdk/cmdline-tools/latest"
                            pkgRemove "$jdk"
                            pkgRemove "glow"
                          elif [ $isAlpine == true ]; then
                            apkDel "curl"
                            apkDel "aria2"
                            apkDel "jq"
                            apkDel "pup"
                            apkDel "libarchive-tools"
                            apkDel "pv"
                            apkDel "glow"
                            apkDel "$jdk"
                            apkDel "android-tools"
                            rm -rf "$HOME/Android/Sdk/cmdline-tools/latest"
                            apkDel "gcompat"
                            apkDel "util-linux"
                          fi
                        ;;
                      esac
                      printf '\033[2J\033[3J\033[H'
                      echo -e "$good ${Yellow}simplifyNext has been uninstalled successfully :(${Reset}"
                      echo -e "💔 ${Yellow}We're sorry to see you go. Feel free to reinstall anytime!${Reset}"
                      simplifyNextURL="https://github.com/arghya339/Simplify/tree/next"
                      if [ $isAndroid == true ]; then termux-open-url "$simplifyNextURL"; elif [ $isMacOS == true ]; then open "$simplifyNextURL"; else xdg-open "$simplifyNextURL" &>/dev/null; fi
                      [ $isAlpine == true ] && apkDel "xdg-utils" &>/dev/null
                      exit 0
                    ;;
                  esac
                  ;;
              esac
              ;;
          esac
        done
        ;;
      Import)
        importOptions=(importKeystore importPatchSelection importSources importScriptSettings restoreScript)
        importDescriptions=("Import Android Keystore" "Import Patch Selection from ReVanced Manager" "" "" "")
        while true; do
          menu importOptions bButtons importDescriptions || break
          importOption="${importOptions[selected]}"
          case "$importOption" in
            importPatchSelection)
              sources=($(jq -r '.[].source' $simplifyNext/sources.json))
              patches=($(jq -r '.[].patches' $simplifyNext/sources.json))
              existsSources=(); existsPatches=()
              for i in "${!sources[@]}"; do
                [ -d "$simplifyNext/${sources[i]}" ] && { existsSources+=("${sources[i]}"); existsPatches+=("${patches[i]}"); }
              done
              menu existsSources bButtons existsPatches || break
              source="${existsSources[selected]}"
              fileSelector "json"
              if [ $? -eq 0 ]; then
                importPatchSelectionJson="$filePath" && unset filePath
                importPatchSelection
              fi
              ;;
            importKeystore)
              pButtons=("<simplifyNext>" "<External>"); confirmPrompt "Where was this keystore generated from?" "pButtons" && generatedby="simplifyNext" || generatedby="External"
              if [ "$generatedby" == "simplifyNext" ]; then
                pButtons=("<Automatically>" "<Manually>"); confirmPrompt "How did simplifyNext create keystore?" "pButtons" && response="Auto" || response="Manually"
                if [ "$response" == "Auto" ]; then
                  fileSelector "keystore" && cp $filePath $simplifyNext/ks.keystore && unset filePath
                else
                  fileSelector "json" && cp $filePath $simplifyNext/ks.json && fileSelector "keystore" && cp $filePath $simplifyNext/ks.keystore && unset filePath
                fi
              else
                fileSelector "keystore"
                if [ $? -eq 0 ]; then
                  keystorePath="$filePath" && unset filePath
                  read -r -p "alias: " alias
                  read -r -p "CN: " CN
                  read -r -p "keypass: " keypass
                  read -r -p "storepass: " storepass
                  if [ -n "$alias" ] && [ -n "$CN" ] && [ -n "$keypass" ] && [ -n "$storepass" ]; then
                    dlBCP
                    $keytool -list -v -keystore "$keystorePath" -storetype BKS -providerclass org.bouncycastle.jce.provider.BouncyCastleProvider -providerpath "$simplifyNext/bcprov-jdk18on-$latest.jar" -storepass "$storepass"
                    if [ $? -eq 0 ]; then
                      [ -f "$simplifyNext/ks.keystore" ] && rm -f "$simplifyNext/ks.keystore"
                      [ -f "$simplifyNext/ks.json" ] && rm -f "$simplifyNext/ks.json"
                      ksJson=$(jq -n --arg a "$alias" --arg c "$CN" --arg k "$keypass" --arg s "$storepass" '{"alias":$a,"CN":$c,"keypass":$k,"storepass":$s}')
                      jq <<< "$ksJson" > $simplifyNext/ks.json
                      cp "$keystorePath" "$simplifyNext/ks.keystore"
                    fi
                  fi
                fi
              fi
              ;;
            importSources) fileSelector "json" && cp "$filePath" "$simplifyNext/sources.json" ;;
            importScriptSettings) fileSelector "json" && cp "$filePath" "$simplifyNext/simplifyNext.json" ;;
            restoreScript) fileSelector "zip" && pv "$filePath" | bsdtar -xf - -C "$simplifyNext" ;;
          esac
        done
        ;;
      Export)
        exportOptions=(exportKeystore exportPatchSelection exportSources exportScriptSettings backupScript)
        exportDescriptions=("Export Android Keystore" "Export Patch Selection for ReVanced Manager" "" "" "")
        while true; do
          menu exportOptions bButtons exportDescriptions || break
          exportOption="${exportOptions[selected]}"
          case "$exportOption" in
            exportPatchSelection)
              sources=($(jq -r '.[].source' $simplifyNext/sources.json))
              patches=($(jq -r '.[].patches' $simplifyNext/sources.json))
              existsSources=(); existsPatches=()
              for i in "${!sources[@]}"; do
                [ -d "$simplifyNext/${sources[i]}" ] && { existsSources+=("${sources[i]}"); existsPatches+=("${patches[i]}"); }
              done
              menu existsSources bButtons existsPatches || break
              source="${existsSources[selected]}"
              exportPatchSelection
              ;;
            exportKeystore)
              [ -f "$simplifyNext/ks.keystore" ] && cp "$simplifyNext/ks.keystore" "$Download/ks.keystore"
              [ -f "$simplifyNext/ks.json" ] && cp "$simplifyNext/ks.json" "$Download/ks.json"
              ;;
            exportSources) cp "$simplifyNext/sources.json" "$Download/sources.json" ;;
            exportScriptSettings) cp "$simplifyNext/simplifyNext.json" "$Download/simplifyNext.json" ;;
            backupScript) bsdtar --format=zip -c -f - -C "$simplifyNext" . | pv -t -b -r > "/sdcard/Download/simplifyNextBack.zip" ;;
          esac
        done
        ;;
      Reset)
        resetOptions=(regenerateKeystore resetPatchSelection resetPatchOptions resetPatchSelectionPatchOptions resetSources resetScriptSettings)
        while true; do
          menu resetOptions bButtons || break
          resetOption="${resetOptions[selected]}"
          case "$resetOption" in
            resetSources)
              pButtons=("<Confirm>" "<Cancel>"); confirmPrompt "Are you sure you want to reset sources.json as default?" "pButtons" "1" && response=Confirm || response=Cancel
              [ "$response" == "Confirm" ] && { checkInternet && curl -sL -o "$simplifyNext/sources.json" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/sources.json"; } ;;
            resetPatchSelection)
              sources=($(jq -r '.[].source' $simplifyNext/sources.json))
              patches=($(jq -r '.[].patches' $simplifyNext/sources.json))
              if menu sources bButtons patches; then
                source="${sources[selected]}"
                cliv=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .cliv' $simplifyNext/sources.json)
                clivDir="$simplifyNext/$cliv"
                sourceDir="$simplifyNext/$source"
                findAssets
                pButtons=("<Confirm>" "<Cancel>"); confirmPrompt "Are you sure you want to reset only patch selection of “${source}”?" "pButtons" "1" && response=Confirm || response=Cancel
                [ "$response" == "Confirm" ] && resetPatchSelection
              fi
              ;;
            resetPatchOptions)
              sources=($(jq -r '.[].source' $simplifyNext/sources.json))
              patches=($(jq -r '.[].patches' $simplifyNext/sources.json))
              if menu sources bButtons patches; then
                source="${sources[selected]}"
                cliv=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .cliv' $simplifyNext/sources.json)
                clivDir="$simplifyNext/$cliv"
                sourceDir="$simplifyNext/$source"
                findAssets
                pButtons=("<Confirm>" "<Cancel>"); confirmPrompt "Are you sure you want to reset only patch options of “${source}”?" "pButtons" "1" && response=Confirm || response=Cancel
                [ "$response" == "Confirm" ] && resetPatchOptions
              fi
              ;;
            resetPatchSelectionPatchOptions)
              sources=($(jq -r '.[].source' $simplifyNext/sources.json))
              patches=($(jq -r '.[].patches' $simplifyNext/sources.json))
              if menu sources bButtons patches; then
                source="${sources[selected]}"
                pButtons=("<Confirm>" "<Cancel>"); confirmPrompt "Are you sure you want to reset both patch selection & patch options of “${source}”?" "pButtons" "1" && response=Confirm || response=Cancel
                [ "$response" == "Confirm" ] && rm -f "$source"/patches-*.json
                sleep 0.5
              fi
              ;;
            regenerateKeystore) genKeystore ;;
            resetScriptSettings) rm -f "$simplifyNext/simplifyNext.json" && exit 0 ;;
          esac
        done
        ;;
      Advanced)
        advancedOptions=(GitHubPAT installationOptions showUniversalPatches ripLib ripDpi ripLocale changeJavaVersion)
        advancedDescriptions=("increases gh api rate limit" "" "" "Remove unused native libraries from patched apps" "Remove unused native dpi from stock split apks" "Remove unused native locale from stock split apks" "")
        while true; do
          reloadConfig
          menu advancedOptions bButtons advancedDescriptions || break
          advancedOption="${advancedOptions[selected]}"
          case "$advancedOption" in
            GitHubPAT) checkInternet && ghAuth ;;
            ripLib)
              confirmPrompt "ripLib" "tfButtons" "$RipLib" && isRipLib=true || isRipLib=false
              config "RipLib" "$isRipLib"
              ripDpiGen
              ;;
            ripDpi)
              confirmPrompt "ripDpi" "tfButtons" "$RipDpi" && isRipDpi=true || isRipDpi=false
              config "RipDpi" "$isRipDpi"
              ripDpiGen
              ;;
            ripLocale)
              confirmPrompt "ripLocale" "tfButtons" "$RipLocale" && isRipLocale=true || isRipLocale=false
              config "RipLocale" "$isRipLocale"
              ripLocaleGen
              ;;
            showUniversalPatches)
              confirmPrompt "showUniversalPatches" "tfButtons" "$ShowUniversalPatches" && isShowUniversalPatches=true || isShowUniversalPatches=false
              config "ShowUniversalPatches" "$isShowUniversalPatches"
              ;;
            changeJavaVersion)
              if checkInternet; then
                attempt=0
                while true; do
                  if [ $isAndroid == true ]; then
                    jdks=($(pkg search openjdk 2>&1 | grep -E "^openjdk-[0-9]+/" | awk -F'[-/ ]' '{print $2}'))
                  elif [ $isMacOS == true ]; then
                    jdks=($(brew search openjdk | grep -E "^openjdk"))
                  elif [ $isFedora == true ]; then
                    jdks=($(dnf search openjdk 2>&1 | grep -E "^ java-[0-9]+-openjdk\." | awk -F'.' '{print $1}'))
                  elif [ $isDebian == true ]; then
                    jdks=($(apt search openjdk 2>&1 | grep -E "^openjdk-[0-9]+-jdk/" | awk -F'/' '{print $1}'))
                  elif [ $isArchLinux == true ]; then
                    jdks=($(pacman -Ss openjdk | grep -E "jdk[0-9]+-openjdk" | awk -F'[/ ]' '{print $2}'))
                  elif [ $isOpenSUSE == true ]; then
                    jdks=($(zypper search openjdk | grep -oE "java-[0-9]+-openjdk" | sort -u))
                  elif [ $isAlpine == true ]; then
                    jdks=($(apk search openjdk 2>&1 | grep -oE "^openjdk[0-9]+-jdk" | awk -F'/' '{print $1}'))
                  fi
                  [ $attempt -eq 5 ] && { echo -e "$notice Not found any java version in search result, after 5 attempts!"; break; }
                  [ ${#jdks[@]} -ne 0 ] && break
                  ((attempt++))
                  sleep 0.5
                done
                if menu jdks bButtons; then
                  jdk="${jdks[selected]}"
                  if [ $isAndroid == true ]; then
                    echo "selected: openjdk-$jdk"
                    pkgInstall "openjdk-$jdk"
                  elif [ $isMacOS == true ]; then
                    echo "selected: $jdk"
                    formulaeInstall "$jdk"
                  elif [ $isFedora == true ]; then
                    echo "selected: $jdk"
                    dnfInstall "$jdk"
                  elif [ $isDebian == true ]; then
                    echo "selected: $jdk"
                    aptInstall "$jdk"
                  elif [ $isArchLinux == true ]; then
                    echo "selected: $jdk"
                    pacInstall "$jdk"
                  elif [ $isOpenSUSE == true ]; then
                    echo "selected: $jdk"
                    pkgInstall "$jdk"
                  elif [ $isAlpine == true ]; then
                    apkAdd "$jdk"
                  fi
                  config "jdk" "$jdk"
                fi
              fi
              ;;
            installationOptions)
              while true; do
                genPMCmd
                installationOptions=("Install Package for *user" "Allow Downgrade with keeps App data (reboot required)" "Grant All Runtime/ Requested Permissions" "Installed as test-only app" "Disable Play Protect Package Verification" "Disable Verify Adb Installs" Installer "Reinstall (Replace/ Upgrade) Existing Installed Package" "Enable Version Roolback")
                [ $Android -ge 14 ] && installationOptions+=("Bypass Low Target SDK Bolck")
                menu installationOptions bButtons || break
                installationOption="${installationOptions[selected]}"
                case "$installationOption" in
                  "Install Package for *user")
                    users=("<default-user>" "<all-users>"); confirmPrompt "InstallPackageFor" "users" "$InstallPackageFor" && isU=0 || isU=1
                    config "InstallPackageFor" "$isU"
                    ;;
                  "Allow Downgrade with keeps App data (reboot required)")
                    confirmPrompt "KeepsData" tfButtons "$KeepsData" && isK=true || isK=false
                    config "KeepsData" "$isK"
                    ;;
                  "Grant All Runtime/ Requested Permissions")
                    confirmPrompt "GrantAllRuntimePermissions" tfButtons "$GrantAllRuntimePermissions" && isG=true || isG=false
                    config "GrantAllRuntimePermissions" "$isG"
                    ;;
                  "Installed as test-only app")
                    confirmPrompt "InstalledAsTestOnly" tfButtons "$InstalledAsTestOnly" && isT=true || isT=false
                    config "InstalledAsTestOnly" "$isT"
                    ;;
                  "Bypass Low Target SDK Bolck")
                    confirmPrompt "BypassLowTargetSdkBolck" tfButtons "$BypassLowTargetSdkBolck" && isL=true || isL=false
                    config "BypassLowTargetSdkBolck" "$isL"
                    ;;
                  "Disable Play Protect Package Verification")
                    confirmPrompt "DisablePlayProtect" tfButtons "$DisablePlayProtect" && isV=true || isV=false
                    config "DisablePlayProtect" "$isV"
                    ;;
                  "Disable Verify Adb Installs")
                    confirmPrompt "DisableVerifyAdbInstalls" tfButtons "$DisableVerifyAdbInstalls" && isA=true || isA=false
                    config "DisableVerifyAdbInstalls" "$isA"
                    ;;
                  Installer)
                    case "$Installer" in
                      "com.android.vending") selected_option=0 ;;
                      "com.android.packageinstaller") selected_option=1 ;;
                      "com.android.shell") selected_option=2 ;;
                      "adb") selected_option=3 ;;
                    esac
                    installerPackages=("com.android.vending" "com.android.packageinstaller" "com.android.shell" "adb")
                    installerNames=(PlayStore PackageInstaller Shell ADB)
                    if menu installerPackages bButtons installerNames "" "$selected_option"; then
                      installerPackage="${installerPackages[selected]}"
                      config "Installer" "$installerPackage"   
                    fi
                    ;;
                  "Reinstall (Replace/ Upgrade) Existing Installed Package")
                    confirmPrompt "Reinstall" tfButtons "$Reinstall" && isR=true || isR=false
                    config "Reinstall" "$isR"
                    ;;
                  "Enable Version Roolback")
                    confirmPrompt "EnableRoolback" tfButtons "$EnableRoolback" && isB=true || isB=false
                    config "EnableRoolback" "$isB"
                    ;;
                esac
              done
              ;;
          esac
        done
        ;;
      About)
        [ $isAndroid == false ] && aboutOptions=(aboutHost) || aboutOptions=()
        ([ $isAndroid == true ] || [ -n "$serial" ]) && aboutOptions+=(aboutDevice)
        aboutOptions+=(GitHub Donate YouTube)
        while true; do
          menu aboutOptions bButtons || break
          aboutOption="${aboutOptions[selected]}"
          case "$aboutOption" in
            aboutHost)
              printf '\033[?25l' && printArt
              echo "Made with ❤️  in India"
              echo "Script Version  : $localVersion"  # YYYYMMDDHHMM
              hostInfo
              echo; read -p "Press Enter to continue..."; printf '\033[?25h'
              ;;
            aboutDevice)
              printf '\033[?25l' && printArt
              [ $isAndroid == true ] && echo "Made with ❤️ in India" || echo "Made with ❤️  in India"
              echo "Script Version : $localVersion"  # YYYYMMDDHHMM
              deviceInfo
              [ -n "$serial" ] && echo "Serial         : $serial"
              echo; read -p "Press Enter to continue..."; printf '\033[?25h'
              ;;
            GitHub)
              GitHubURL="https://github.com/arghya339/Simplify/tree/next"
              if [ $isAndroid == true ]; then termux-open-url "$GitHubURL"; elif [ $isMacOS == true ]; then open "$GitHubURL"; else xdg-open "$GitHubURL" &>/dev/null; fi
              ;;
            Donate)
              DonateURL="https://www.paypal.com/paypalme/arghyadeep339"
              if [ $isAndroid == true ]; then termux-open-url "$DonateURL"; elif [ $isMacOS == true ]; then open "$DonateURL"; else xdg-open "$DonateURL" &>/dev/null; fi
              ;;
            YouTube)
              YouTubeURL="https://www.youtube.com/@mrpalash360?sub_confirmation=1"
              if [ $isAndroid == true ]; then termux-open-url "$YouTubeURL"; elif [ $isMacOS == true ]; then open "$YouTubeURL"; else xdg-open "$YouTubeURL" &>/dev/null; fi
              ;;
          esac
        done
        ;;
      Share) simplifyNextURL="https://github.com/arghya339/Simplify/tree/next"; am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "$simplifyNextURL" > /dev/null ;;
    esac
  done
}
