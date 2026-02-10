#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

dlPatchedAppsJson() {
  [ ! -f "$simplifyNext/dlPatchedApps.json" ] && echo "[]" > $simplifyNext/dlPatchedApps.json
  NEW_DATA=$(cat <<EOF
{
  "name": "$name",
  "repo": "$repo",
  "assets": "$assets_name",
  "package": "$package",
  "versionName": "$versionName",
  "versionCode": $versionCode,
  "installed": $installed,
  "patched": "$patched",
  "date": "$updated_at"
}
EOF
)

  jq --argjson newApp "$NEW_DATA" '[$newApp, .[]] | unique_by(.name, .assets)' "$simplifyNext/dlPatchedApps.json" > tmp.json && mv tmp.json "$simplifyNext/dlPatchedApps.json"
}

dlApps() {
  dlURL="https://github.com/${repo}/releases/download/all/${assets_name}"
  [ -f "$simplifyNext/dlPatchedApps.json" ] && date=$(jq -r --arg name "$name" --arg assets "$assets_name" '.[] | select(.name == $name and .assets == $assets) | .date' "$simplifyNext/dlPatchedApps.json")
  responseJson=$(curl -sL ${ghAuthH} "https://api.github.com/repos/${repo}/releases/tags/all")
  updated_at=$(jq -r --arg n "$assets_name" '.assets[] | select(.name == $n) | .updated_at' <<< "$responseJson")
  if [ "$date" != "$updated_at" ]; then
    dlSizeM=$(jq -r --arg n "$assets_name" '.assets[] | select(.name == $n) | .size' <<< "$responseJson" | head -1 | awk '{ printf "%.0f\n", $1 / 1024 / 1024 }')
    patched="$Download/$assets_name"
    [ $dlSizeM -lt 25 ] && dl "curl" "$dlURL" "$patched" || dl "aria2" "$dlURL" "$patched"
    if [ -f "$patched" ]; then
      appInfo=$($aapt2 dump badging "$patched" 2>/dev/null)
      package=$(awk -F"'" '/package/ {print $2}' <<< "$appInfo" | head -1)
      appName=$(awk -F"'" '/application-label:/ {print $2}' <<< "$appInfo")
      versionName=$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<< "$appInfo")
      versionCode=$(sed -n "s/.*versionCode='\([^']*\)'.*/\1/p" <<< "$appInfo")
      installed=false
      if [ $isAndroid == true ] || [ -n "$serial" ]; then
        pButtons=("<Install>" "<Cancel>"); confirmPrompt "Do you want to install patched $appName v$versionName APK?" "pButtons" && response="Install" || response="Cancel"
        if [ "$response" == "Install" ]; then
          installed=true
          [ $isAndroid == true ] && apkInstall "$patched"
          [ $isAndroid == false ] && adbInstall "$patched"
        fi
      fi
    fi
    dlPatchedAppsJson
  else
    echo -e "$notice $name is already uptodate!"
  fi
  echo; read -p "Press Enter to continue..."
  [ "$rmPatchedApk" == true ] && { rm -f "$patched"; patched=null; }
}

dlPatchedApps() {
  checkInternet && curl -sL -o "$simplifyNext/dl.json" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/dl.json"
  mapfile -t names < <(jq -r '.[].name' $simplifyNext/dl.json)
  while true; do
    menu names bButtons || break
    name="${names[selected]}"
    channels=($(jq -r --arg n "$name" '.[] | select(.name==$n) | .assets | to_entries[] | select(.value | length > 0) | .key' $simplifyNext/dl.json))
    if menu channels bButtons; then
      channel="${channels[selected]}"
      archs=($(jq -r --arg n "$name" --arg c "$channel" '.[] | select(.name==$n) | .assets[$c] | to_entries[] | select(.value != null) | .key' $simplifyNext/dl.json))
      assets_names=($(jq -r --arg n "$name" --arg c "$channel" '.[] | select(.name==$n) | .assets[$c] | to_entries[] | select(.value != null) | .value' $simplifyNext/dl.json))
      if menu archs bButtons; then
        #arch="${archs[selected]}"
        #assets_name=$(jq -r --arg n "$name" --arg c "$channel" --arg a "$arch" '.[] | select(.name==$n) | .assets[$c][$a]' $simplifyNext/dl.json)
        assets_name="${assets_names[selected]}"
        repo=$(jq -r --arg n "$name" '.[] | select(.name==$n) | .repo' $simplifyNext/dl.json)
        checkInternet && dlApps
      fi
    fi
  done
}

viewDlPatchedApps() {
  if [ -f "$simplifyNext/dlPatchedApps.json" ] && [ $(jq '. | length' $simplifyNext/dlPatchedApps.json) -gt 0 ]; then
    mapfile -t names < <(jq -r '.[].name' "$simplifyNext/dlPatchedApps.json")
    repos=($(jq -r '.[].repo' "$simplifyNext/dlPatchedApps.json"))
    assets=($(jq -r '.[].assets' "$simplifyNext/dlPatchedApps.json"))
    packages=($(jq -r '.[].package' "$simplifyNext/dlPatchedApps.json"))
    mapfile -t versionNames < <(jq -r '.[].versionName' "$simplifyNext/dlPatchedApps.json")
    versionCodes=($(jq -r '.[].versionCode' "$simplifyNext/dlPatchedApps.json"))
    installeds=($(jq -r '.[].installed' "$simplifyNext/dlPatchedApps.json"))
    patcheds=($(jq -r '.[].patched' "$simplifyNext/dlPatchedApps.json"))
    dates=($(jq -r '.[].date' "$simplifyNext/dlPatchedApps.json"))
    options=("Download Patched Apps" "Manage Downloaded Apps")
    if menu options bButtons; then
      option="${options[selected]}"
      case "$option" in
        "Download Patched Apps") dlPatchedApps ;;
        "Manage Downloaded Apps")
          while true; do
            menu names bButtons packages || break
            name="${names[selected]}"
            repo="${repos[selected]}"
            assets_name="${assets[selected]}"
            package="${packages[selected]}"
            versionName="${versionNames[selected]}"
            versionCode="${versionCodes[selected]}"
            installed="${installeds[selected]}"
            patched="${patcheds[selected]}"
            date="${dates[selected]}"
            appsOptions=("App Info")
            if { [ $isAndroid == false ] && [ -n "$serial" ]; } || { [ $isAndroid == true ] && { [ $su == true ] || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; }; }; then
              [ $installed == true ] && appsOptions+=(Open)
            fi
            [ $isAndroid == true ] && appsOptions+=(Share)
            [[ "$patched" != "null" && "$installed" == false && ($isAndroid == true || -n "$serial") ]] && appsOptions+=(Install)
            [[ "$patched" != "null" && "$installed" == true && ($isAndroid == true || -n "$serial") ]] && appsOptions+=(Reinstall)
            [[ $installed == true && ($isAndroid == true || -n "$serial") ]] && appsOptions+=(Update Uninstall)
            [ $patched != "null" ] && appsOptions+=(Delete)
            if menu appsOptions bButtons; then
              appsOption="${appsOptions[selected]}"
              case "$appsOption" in
                "App Info") echo -e "name: $name\npackage: $package\nversion: $versionName ($versionCode)\ndate: $date" ;;
                Share)
                  dlURL="https://github.com/${repo}/releases/download/all/${assets_name}"
                  [ "$patched" != "null" ] && termux-open --send "$patched" || am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "$dlURL" > /dev/null
                  ;;
                Open)
                  if [ $isAndroid == false ]; then
                    adb -s $serial shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 &> /dev/null
                  else
                    if [ $su == true ]; then
                      [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=true; } || writeSELinux=false
                      su -c "monkey -p $package -c android.intent.category.LAUNCHER 1" &> /dev/null
                      [ $writeSELinux == true ] && su -c "setenforce 1"
                    elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
                      ~/rish -c "monkey -p $package -c android.intent.category.LAUNCHER 1" &> /dev/null
                    elif "$HOME/adb" -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
                      ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "monkey -p $package -c android.intent.category.LAUNCHER 1" &> /dev/null
                    fi
                  fi
                  ;;
                Install|Reinstall)
                  installed=true
                  jq --arg pkg "$package" --arg assets "$assets_name" --argjson stat true 'map(if (.package == $pkg and .assets == $assets) then .installed = $stat else . end)' $simplifyNext/dlPatchedApps.json > tmp.json && mv tmp.json $simplifyNext/dlPatchedApps.json
                  [ $isAndroid == true ] && apkInstall "$patched"
                  [ $isAndroid == false ] && adbInstall "$patched"
                  ;;
                Delete)
                  rm -f "$patched"
                  patched=null
                  jq --arg pkg "$package" --arg assets "$assets_name" --argjson v null 'map(if (.package == $pkg and .assets == $assets) then .patched = $v else . end)' $simplifyNext/dlPatchedApps.json > tmp.json && mv tmp.json $simplifyNext/dlPatchedApps.json
                  ;;
                Uninstall)
                  installed=false
                  jq --arg pkg "$package" --arg assets "$assets_name" --argjson stat false 'map(if (.package == $pkg and .assets == $assets) then .installed = $stat else . end)' $simplifyNext/dlPatchedApps.json > tmp.json && mv tmp.json $simplifyNext/dlPatchedApps.json
                  if [ $isAndroid == false ]; then
                    adb -s $serial shell "pm uninstall $package" &> /dev/null
                  else
                    if [ $su == true ]; then
                      [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=true; } || writeSELinux=false
                      su -c "pm uninstall $package"
                      [ $writeSELinux == true ] && su -c "setenforce 1"
                    elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
                      ~/rish -c "pm uninstall $package"
                    elif "$HOME/adb" -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
                      ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "pm uninstall $package"
                    else
                      am start -a android.intent.action.UNINSTALL_PACKAGE -d package:"$package" > /dev/null 2>&1
                      sleep 6
                      am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:"$package" > /dev/null 2>&1
                    fi
                  fi
                  ;;
                Update) checkInternet && dlApps ;;
              esac
              if [ $installed == false ] && [ "$patched" == "null" ]; then
                jq --arg pkg "$package" --arg assets "$assets_name" 'del(.[] | select(.package == $pkg and .assets == $assets))' $simplifyNext/dlPatchedApps.json > tmp.json && mv tmp.json $simplifyNext/dlPatchedApps.json
                break
              fi
              echo; read -p "Press Enter to continue..."
            fi
          done
          ;;
      esac
    fi
  else
    dlPatchedApps
  fi
}