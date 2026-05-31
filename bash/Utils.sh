#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

runCmd() {
  cmd=${1}
  if [ $isAndroid == true ]; then
    if [ $su == true ]; then
      [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=true; } || writeSELinux=false
      su -c "$cmd"
      [ $writeSELinux == true ] && su -c "setenforce 1"
    elif rish -c "id" &>/dev/null; then
      rish -c "$cmd"
    elif adb -s $(adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" &>/dev/null; then
      adb -s $(adb devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) $cmd
    fi
  else
    adb -s $serial $cmd
  fi
}

shellCmd() {
  cmd=$1
  if [ $isAndroid == true ]; then
    if [ $su == true ] || rish -c "id" &>/dev/null; then
      runCmd "$cmd"
    elif adb -s $(adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" &>/dev/null; then
      runCmd "shell $cmd"
    fi
  else
    runCmd "shell $cmd"
  fi
}

pullFile() {
  sourceFile=$1
  targetFile=$2
  if [ $isAndroid == true ]; then
    if [ $su == true ] || rish -c "id" &>/dev/null; then
      runCmd "cp $sourceFile $targetFile"
    elif adb -s $(adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" &>/dev/null; then
      runCmd "pull $sourceFile $targetFile"
    fi
  else
    runCmd "pull $sourceFile $targetFile"
  fi
}

verify() {
  package=$1
  cmdOut=$(shellCmd "pm path $package")
  basePath=$(cut -d ':' -f2 <<< "$cmdOut" | head -1); unset cmdOut
  pullFile $basePath $Download/$package.apk
  appInfo=$($aapt2 dump badging "$Download/$package.apk" 2>/dev/null)
  package=$(awk -F"'" '/package/ {print $2}' <<< "$appInfo" | head -1)
  appName=$(awk -F"'" '/application-label:/ {print $2}' <<< "$appInfo")
  version=$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<< "$appInfo")
  echo -e "$appName ($package) v$version"
  if [ $isAndroid == true ]; then
    pkgInstall "apksigner"
    $java -jar $PREFIX/share/java/apksigner.jar verify --print-certs "$Download/$package.apk" | grep "certificate DN:" | head -1 | cut -d: -f2-
  else
    $apksigner verify --print-certs "$Download/$package.apk" | grep "certificate DN:" | head -1 | cut -d: -f2-
  fi
}

exportApp() {
  package=$1
  mapfile -t cmdOut < <(shellCmd "pm path $package")
  packagePath=("${cmdOut[@]#package:}"); unset cmdOut
  if [ ${#packagePath[@]} -eq 1 ]; then
    filePath="$Download/${appName}_v${version}.apk"
    mv $Download/$package.apk "$filePath"
  else
    mkdir -p $Download/$package
    mv $Download/$package.apk $Download/$package/base.apk
    for ((i=1; i<${#packagePath[@]}; i++)); do
      pullFile ${packagePath[i]} $Download/$package
    done
    bsdtar --format=zip -c -f - -C "$Download/$package" . | pv -t -b -r > "$Download/${appName}_v${version}.apks" && rm -rf "$Download/$package"
    antisplitApp "$Download/${appName}_v${version}.apks" $package
  fi
  echo "filePath: $filePath"
}

installedAppPicker() {
  package=$1
  appName=$2
  pickers=(selectedApp 3rdPartyApp systemApp)
  pickerd=("$appName ($package)" "third-party (installed) apps only" "system (pre-installed) apps only")
  if menu pickers bButtons pickerd; then
    picker="${pickers[selected]}"
    if [ "$picker" == "selectedApp" ]; then
      verify $package
      confirmPrompt "Do you want to export $appName app?" ynButtons && exportApp $package || rm -f $Download/$package.apk
    else
      [ "$picker" == "3rdPartyApp" ] && arg="-3" || arg="-s"
      mapfile -t cmdOut < <(shellCmd "pm list packages $arg")
      packages=("${cmdOut[@]#package:}")
      if menu packages bButtons; then
        package=${packages[selected]}
        verify $package
        confirmPrompt "Do you want to export $appName app?" ynButtons && exportApp $package || rm -f $Download/$package.apk
      fi
    fi
  fi
}

BuildPatches() {
  pkgInstall "git"
  if [ $isMacOS == true ]; then
    /usr/local/bin/sdkmanager $(/usr/local/bin/sdkmanager --list | grep "^  platforms;" | awk '{print $1}' | grep -E "platforms;android-[0-9]+$" | sort -V | tail -1)
    /usr/local/bin/sdkmanager --update
    SDK_DIR="$HOME/Library/Android/sdk"
  else
    if [ $isDebian == true ] || [ $isArchLinux == true ]; then
      if [ ! -f "$HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager" ]; then
        cmdlinetoolslatest=$(curl -sL https://developer.android.com/studio | grep -o "https://dl.google.com/android/repository/commandlinetools-linux-[0-9]*_latest.zip" | head -1 | awk -F'[-_]' '{print $3}')
        curl -L --progress-bar -C - -o "$HOME/Downloads/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip" "https://dl.google.com/android/repository/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip"
        mkdir -p ~/Android/Sdk/cmdline-tools/latest
        pv "$HOME/Downloads/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip" | bsdtar -xf - -C "$HOME/Android/Sdk/cmdline-tools/latest" --strip-components 1
        rm -f "$HOME/Downloads/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip"
        chmod +x ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager
        ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --version
        yes | ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --licenses
        ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager $($HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --list | grep "^  build-tools;" | awk '{print $1}' | tail -1)
        grep -qxF 'export PATH="$HOME/Android/Sdk/build-tools/$(ls $HOME/Android/Sdk/build-tools | sort -V | tail -1):$PATH"' ~/.android-env || echo 'export PATH="$HOME/Android/Sdk/build-tools/$(ls $HOME/Android/Sdk/build-tools | sort -V | tail -1):$PATH"' >> ~/.android-env && source ~/.android-env
      fi
    fi
    [ $isBazzite == true ] && sdkmanager="/home/linuxbrew/.linuxbrew/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager" || sdkmanager="$HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager"
    $sdkmanager $($sdkmanager --list | grep "^  platforms;" | awk '{print $1}' | grep -E "platforms;android-[0-9]+$" | sort -V | tail -1)
    $sdkmanager --update
    SDK_DIR="$HOME/Android/Sdk"
  fi
  if [ ! -d "$sourceDir/$(basename $patches)" ]; then
    webURL="https://github.com/$patches"; curl -fsL "$webURL" &>/dev/null || webURL="https://gitlab.com/$patches"
    (cd "$sourceDir" && git clone "$webURL")
  else
    (cd "$sourceDir/$(basename $patches)" && git fetch origin)
  fi
  wd=$(pwd)
  cd "$sourceDir/$(basename $patches)"
  echo "sdk.dir=$SDK_DIR" > local.properties
  export ANDROID_HOME=$SDK_DIR
  export GITHUB_ACTOR=$ghUser
  export GITHUB_TOKEN=$ghToken
  ./gradlew clean :patches:buildAndroid generatePatchesList
  rm -f $sourceDir/patches-*.{mpp,rvp,json}
  cp $(ls patches/build/libs/patches-*.{mpp,rvp} 2>/dev/null | grep -vE "javadoc|sources") $sourceDir
  patchesVersion=$(ls patches/build/libs/patches-*.{mpp,rvp} 2>/dev/null | grep -vE "javadoc|sources" | xargs -n 1 basename | sed -E 's/^patches-|\.(mpp|rvp)$//g')
  patchesJson="$sourceDir/patches.json"
  cp patches-list.json $patchesJson
  [ $cli == "MorpheApp/morphe-cli" ] && jq '.patches | map(.compatiblePackages |= (if . == null then null else to_entries | map({name: .key, versions: .value}) end))' "$patchesJson" > "tmp.json" && mv "tmp.json" "$patchesJson"
  rm -rf patches/build/
  cd $wd
  checkInternet && fetchAppsInfo
}