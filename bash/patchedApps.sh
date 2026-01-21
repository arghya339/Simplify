#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

patchedAppsJson() {
  if jq -e --arg pkg "$package" '.. | .name? // empty | select(. == $pkg)' $sourceDir/patches-*.json >/dev/null; then
    if [ "$ShowUniversalPatches" == true ]; then
      appliedPatchesJson=$(jq --arg pkg "$package" '[.[] | 
        select(
          .use == true and 
          (.compatiblePackages == null or any(.compatiblePackages[]?; .name == $pkg))
        ) | {
          name: .name,
          description: .description,
          options: [.options[]? | {
              key: .key,
              default: .default,
              title: .title,
              description: .description
          }]
        }]' $sourceDir/patches-*.json)
    else
      appliedPatchesJson=$(jq --arg pkg "$package" '[.[] | select(.use == true) | select(.compatiblePackages[]?.name | . == $pkg) | {
        name: .name,
        description: .description,
        options: [.options[]? | {
            key: .key,
            default: .default,
            title: .title,
            description: .description
        }]
      }]' $sourceDir/patches-*.json)
    fi
  else
    appliedPatchesJson=$(jq '[.[] | select(.use == true) | select(.compatiblePackages == null) | {
      name: .name,
      description: .description,
      options: [.options[]? | {
          key: .key,
          default: .default,
          title: .title,
          description: .description
      }]
    }]' $sourceDir/patches-*.json)
  fi

  [ ! -f "$simplifyNext/patchedApps.json" ] && echo "[]" > $simplifyNext/patchedApps.json && sleep 0.5
  NEW_DATA=$(cat <<EOF
{
  "source": "$source",
  "spkg": "$stockPKG",
  "ppkg": "$patchedPKG",
  "name": "$appName",
  "version": "$version",
  "patch": "$patchesVersion",
  "mount": $mount,
  "installed": $installed,
  "stock": "$stock",
  "patched": "$patched",
  "date": $(date +%s),
  "patchUse": $appliedPatchesJson
}
EOF
)

  jq --argjson newApp "$NEW_DATA" '[$newApp, .[]] | unique_by(.ppkg, .source)' "$simplifyNext/patchedApps.json" > tmp.json && mv tmp.json "$simplifyNext/patchedApps.json"
}

startMountLog() {
  echo "--------------------Tool Info--------------------" > "$SimplUsr/MountLog.txt"
  toolInfo >> "$SimplUsr/MountLog.txt"
  echo "------------------System Info------------------" >> "$SimplUsr/MountLog.txt"
  systemInfo >> "$SimplUsr/MountLog.txt"
  [ $isAndroid == false ] && { echo "-------------------Host Info--------------------" >> "$SimplUsr/MountLog.txt"; hostInfo >> "$SimplUsr/MountLog.txt"; }
  echo "------------------Device Info-------------------" >> "$SimplUsr/MountLog.txt"
  deviceInfo >> "$SimplUsr/MountLog.txt"
  echo "-------------------Assets-----------------------" >> "$SimplUsr/MountLog.txt"
  echo "Source      : $source" >> "$SimplUsr/MountLog.txt"
  echo "App Name    : $name" >> "$SimplUsr/MountLog.txt"
  echo "Package Name: $spackage" >> "$SimplUsr/MountLog.txt"
  echo "Version     : $version ($source-$patch)" >> "$SimplUsr/MountLog.txt"
  echo "Stock       : $stock" >> "$SimplUsr/MountLog.txt"
  echo "Patched     : $patched" >> "$SimplUsr/MountLog.txt"
  echo "-------------------Mount Log-------------------" >> "$SimplUsr/MountLog.txt"
}

viewAppliedPatches() {
  while true; do
    mapfile -t patchNames < <(jq -r '.[].name' <<< "$appliedPatchesJson")
    mapfile -t patchDescriptions < <(jq -r '.[].description | gsub("\n"; " ")' <<< "$appliedPatchesJson")
    menu patchNames bButtons patchDescriptions || break
    patchName="${patchNames[selected]}"
    while true; do
      mapfile -t optionsTitles < <(jq -r --arg pn "$patchName" '.[] | select(.name == $pn) | .options[].title' <<< $appliedPatchesJson)
      [ ${#optionsTitles[@]} -eq 0 ] && { echo -e "$notice This patch has no configurable options!"; sleep 1; break; }
      mapfile -t optionsDescriptions < <(jq -r --arg pn "$patchName" '.[] | select(.name == $pn) | .options[].description | gsub("\n"; " ")' <<< $appliedPatchesJson)
      mapfile -t optionsDefaults < <(jq -r --arg pn "$patchName" '.[] | select(.name == $pn) | .options[].default' <<< $appliedPatchesJson)
      menu optionsTitles bButtons optionsDescriptions optionsDefaults || break
    done
  done
}

viewPatchedApps() {
  sources=($(jq -r '.[].source' $simplifyNext/patchedApps.json))
  mapfile -t names < <(jq -r '.[].name' $simplifyNext/patchedApps.json)
  spackages=($(jq -r '.[].spkg' $simplifyNext/patchedApps.json))
  ppackages=($(jq -r '.[].ppkg' $simplifyNext/patchedApps.json))
  mapfile -t versions < <(jq -r '.[].version' $simplifyNext/patchedApps.json)
  mapfile -t patchs < <(jq -r '.[].patch' $simplifyNext/patchedApps.json)
  mapfile -t stocks < <(jq -r '.[].stock' $simplifyNext/patchedApps.json)
  mapfile -t patcheds < <(jq -r '.[].patched' $simplifyNext/patchedApps.json)
  installeds=($(jq -r '.[].installed' $simplifyNext/patchedApps.json))
  mounts=($(jq -r '.[].mount' $simplifyNext/patchedApps.json))
  patchedDates=($(jq -r '.[].date' $simplifyNext/patchedApps.json))
  now=$(date +%s)
  patchedAges=()
  for date in "${patchedDates[@]}"; do
    diff=$((now - date))
    if [ $diff -ge 31536000 ]; then
      dateAge=$((diff / 31536000))
      unit=year
    elif [ $diff -ge 2630000 ]; then
      dateAge=$((diff / 2630000))
      unit=month
    elif [ $diff -ge 604800 ]; then
      dateAge=$((diff / 604800))
      unit=week
    elif [ $diff -ge 86400 ]; then
      dateAge=$((diff / 86400))
      unit=day
    elif [ $diff -ge 3600 ]; then
      dateAge=$((diff / 3600))
      unit=hour
    elif [ $diff -ge 60 ]; then
      dateAge=$((diff / 60))
      unit=minute
    else
      dateAge=$diff
      unit=second
    fi
    [ $dateAge -ne 1 ] && unit="${unit}s"
    patchedAges+=("$dateAge $unit")
  done
  while true; do
    menu names bButtons ppackages versions || break
    spackage="${spackages[selected]}"
    ppackage="${ppackages[selected]}"
    source="${sources[selected]}"
    name="${names[selected]}"
    version="${versions[selected]}"
    patch="${patchs[selected]}"
    patchedDate=${patchedDates[selected]}
    [ $isMacOS == true ] && patchedDateH=$(date -r $patchedDate +"%a %b %-d %Y %H:%M:%S") || patchedDateH=$(date -d @$patchedDate +"%a %b %-d %Y %H:%M:%S")
    patchedAge="${patchedAges[selected]}"
    stock="${stocks[selected]}"
    patched="${patcheds[selected]}"
    installed="${installeds[selected]}"
    mount="${mounts[selected]}"
    appliedPatchesJson=$(jq -r ".[$selected].patchUse" $simplifyNext/patchedApps.json)
    while true; do
      opts=(appInfo Action)
      menu opts bButtons || break
      opt="${opts[selected]}"
      case "$opt" in
        appInfo)
          [ $mount == true ] && package="$spackage" || package="$ppackage"
          echo "appName: $name"
          echo "package: $package"
          echo "version: $version ($source-$patch)"
          echo "patchedDate: $patchedDateH ($patchedAge ago)"
          echo; read -p "Press Enter to continue..."
          ;;
        Action)
          echo "Please Wait!!"
          actions=(appliedPatches)
          if { [ $isAndroid == false ] && [ -n "$serial" ]; } || { [ $isAndroid == true ] && { [ $su == true ] || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; }; }; then
            [ $installed == true ] && actions+=(Open)
          fi
          ([ $isAndroid == true ] && [ "$patched" != "null" ]) && actions+=(Share)
          [[ "$patched" != "null" && "$installed" == false && ($isAndroid == true || -n "$serial") ]] && actions+=(Install)
          [[ "$patched" != "null" && "$installed" == true && "$mount" == false && ($isAndroid == true || -n "$serial") ]] && actions+=(Reinstall)
          ([ "$patched" != "null" ] && [ "$stock" != "null" ] && [ $su == true ] && [ $mount == false ]) && actions+=(Mount)
          ([ "$patched" != "null" ] && [ "$stock" != "null" ] && [ $su == true ] && [ $mount == true ]) && actions+=(Remount)
          [[ $installed == true && $mount == false && ($isAndroid == true || -n "$serial") ]] && actions+=(Uninstall)
          ([ $su == true ] && [ $mount == true ]) && actions+=(Unmount)
          [ "$patched" != "null" ] && actions+=(Delete)
          while true; do
            menu actions bButtons || break
            action="${actions[selected]}"
            case "$action" in
              Share) termux-open --send "$patched" ;;
              Open)
                [ $mount == true ] && package="$spackage" || package="$ppackage"
                if [ $isAndroid == false ]; then
                  activityClass=$(adb -s $serial shell "pm resolve-activity --brief $package" | tail -1)
                  adb -s $serial shell am start -n "$activityClass" &> /dev/null
                  [ $? -ne 0 ] && adb -s $serial shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 &> /dev/null
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
                jq --arg pkg "$ppackage" --arg src "$source" --argjson stat true 'map(if (.ppkg == $pkg and .source == $src) then .installed = $stat else . end)' $simplifyNext/patchedApps.json > tmp.json && mv tmp.json $simplifyNext/patchedApps.json
                [ $isAndroid == true ] && apkInstall "$patched"
                [ -n "$serial" ] && adbInstall "$patched"
                ;;
              Mount|Remount)
                mount=true
                jq --arg pkg "$spackage" --arg src "$source" --argjson stat true 'map(if (.spkg == $pkg and .source == $src) then .mount = $stat else . end)' $simplifyNext/patchedApps.json > tmp.json && mv tmp.json $simplifyNext/patchedApps.json
                startMountLog
                if [ $isAndroid == true ]; then
                  su -mm -c "/system/bin/sh $simplifyNext/apkMount.sh \"$stock\" \"$patched\"" | tee -a "$SimplUsr/MountLog.txt"
                else
                  [ ! -f "$simplifyNext/aapt2_$cpuAbi" ] && curl -L --progress-bar -o "$simplifyNext/aapt2_$cpuAbi" "https://github.com/arghya339/aapt2/releases/download/all/aapt2_$cpuAbi"
                  adb -s "$serial" shell "[ ! -f '/data/local/tmp/aapt2' ]" && { adb -s "$serial" push "$simplifyNext/aapt2_$cpuAbi" /data/local/tmp/aapt2 >/dev/null 2>&1 && adb -s "$serial" shell "chmod +x /data/local/tmp/aapt2"; }
                  adb -s "$serial" shell "[ ! -f '/data/local/tmp/apkMount.sh' ]" && { adb -s "$serial" push "$simplifyNext/apkMount.sh" /data/local/tmp/apkMount.sh >/dev/null 2>&1 && adb -s "$serial" shell "chmod +x /data/local/tmp/apkMount.sh"; }
                  stockFileName=$(basename "$stock" 2>/dev/null)
                  patchedFileName=$(basename "$patched" 2>/dev/null)
                  adb -s $serial push "$stock" "/data/local/tmp"
                  adb -s $serial push "$patched" "/data/local/tmp"
                  adb -s $serial exec-out su -mm -c "/system/bin/sh /data/local/tmp/apkMount.sh \"/data/local/tmp/$stockFileName\" \"/data/local/tmp/$patchedFileName\"" | tee -a "$SimplUsr/MountLog.txt"
                  adb -s $serial shell "rm -f \"/data/local/tmp/$stockFileName\" \"/data/local/tmp/$patchedFileName\""
                fi
                echo "~~~~~~~~~~~~~~~END~~~~~~~~~~~~~~~" >> "$SimplUsr/MountLog.txt"
                ;;
              Uninstall)
                installed=false
                jq --arg pkg "$ppackage" --arg src "$source" --argjson stat false 'map(if (.ppkg == $pkg and .source == $src) then .installed = $stat else . end)' $simplifyNext/patchedApps.json > tmp.json && mv tmp.json $simplifyNext/patchedApps.json
                if [ $isAndroid == false ]; then
                  adb -s $serial shell "pm uninstall $ppackage" &> /dev/null
                else
                  if [ $su == true ]; then
                    [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=true; } || writeSELinux=false
                    su -c "pm uninstall $ppackage"
                    [ $writeSELinux == true ] && su -c "setenforce 1"
                  elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
                    ~/rish -c "pm uninstall $ppackage"
                  elif "$HOME/adb" -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
                    ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "pm uninstall $package"
                  else
                    am start -a android.intent.action.UNINSTALL_PACKAGE -d package:"$ppackage" > /dev/null 2>&1
                    sleep 6
                    am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:"$ppackage" > /dev/null 2>&1
                  fi
                fi
                ;;
              Unmount)
                installed=false
                jq --arg pkg "$ppackage" --arg src "$source" --argjson stat false 'map(if (.ppkg == $pkg and .source == $src) then .installed = $stat else . end)' $simplifyNext/patchedApps.json > tmp.json && mv tmp.json $simplifyNext/patchedApps.json
                mount=false
                jq --arg pkg "$spackage" --arg src "$source" --argjson stat false 'map(if (.spkg == $pkg and .source == $src) then .mount = $stat else . end)' $simplifyNext/patchedApps.json > tmp.json && mv tmp.json $simplifyNext/patchedApps.json
                if [ $isAndroid == true ]; then
                  su -c "/system/bin/sh /data/adb/revanced/$spackage/${spackage}.sh" 2>/dev/null
                else
                  adb -s $serial exec-out su -c "/system/bin/sh /data/adb/revanced/$spackage/${spackage}.sh" 2>/dev/null
                fi
                ;;
              Delete)
                rm -f "$patched"
                patched=null
                jq --arg pkg "$ppackage" --arg src "$source" --argjson v null 'map(if (.ppkg == $pkg and .source == $src) then .patched = $v else . end)' $simplifyNext/patchedApps.json > tmp.json && mv tmp.json $simplifyNext/patchedApps.json
                ;;
              appliedPatches) viewAppliedPatches ;;
            esac
            if [ $installed == false ] && [ "$patched" == "null" ]; then
              jq --arg pkg "$ppackage" --arg src "$source" 'del(.[] | select(.ppkg == $pkg and .source == $src))' $simplifyNext/patchedApps.json > tmp.json && mv tmp.json $simplifyNext/patchedApps.json
              break
            fi
            echo; read -p "Press Enter to continue..."
          done
          ;;
      esac
      ([ $installed == false ] && [ "$patched" == "null" ]) && break
    done
  done
}