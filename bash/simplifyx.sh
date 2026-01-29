#!/usr/bin/env bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

shopt -s extglob

readonly good="\033[92;1m[✔]\033[0m"
readonly bad="\033[91;1m[✘]\033[0m"
readonly info="\033[94;1m[i]\033[0m"
readonly running="\033[37;1m[~]\033[0m"
readonly notice="\033[93;1m[!]\033[0m"
readonly question="\033[93;1m[?]\033[0m"

Green="\033[92m"
BoldGreen="\033[92;1m"
Red="\033[91m"
Blue="\033[94m"
Cyan="\033[96m"
White="\033[37m"
whiteBG="\e[47m\e[30m"
Yellow="\033[93m"
Reset="\033[0m"

checkInternet() {
  if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    return
  else
    echo -e "$bad ${Red}No Internet Connection available!${Reset}"
    return 1
  fi
}

if [[ "$(uname)" == "Darwin" ]]; then
  isMacOS=true; isAndroid=false; isDebian=false; isArchLinux=false; isFedora=false; isOpenSUSE=false; isAlpine=false
elif [[ -d "/sdcard" ]] && [[ -d "/system" ]]; then
  isAndroid=true; isMacOS=false; isDebian=false; isArchLinux=false; isFedora=false; isOpenSUSE=false; isAlpine=false
elif [[ -f "/etc/os-release" ]]; then
  if grep -qi "debian" /etc/os-release 2>/dev/null; then
    isDebian=true; isArchLinux=false; isFedora=false; isOpenSUSE=false; isAlpine=false; isAndroid=false; isMacOS=false
    curl -V >/dev/null 2>&1 || { echo -e "$running Installing curl package.."; sudo apt install curl -y >/dev/null 2>&1; }
  elif grep -qi "arch" /etc/os-release 2>/dev/null; then
    isArchLinux=true; isFedora=false; isDebian=false; isOpenSUSE=false; isAlpine=false; isAndroid=false; isMacOS=false
  elif grep -qi "fedora" /etc/os-release 2>/dev/null; then
    isFedora=true; isDebian=false; isArchLinux=false; isOpenSUSE=false; isAlpine=false; isAndroid=false; isMacOS=false
  elif grep -qi "opensuse" /etc/os-release 2>/dev/null; then
    isOpenSUSE=true; isFedora=false; isDebian=false; isArchLinux=false; isAlpine=false; isAndroid=false; isMacOS=false
  elif grep -qi "alpine" /etc/os-release 2>/dev/null; then
    isAlpine=true; isFedora=false; isDebian=false; isArchLinux=false; isOpenSUSE=false; isAndroid=false; isMacOS=false
    curl -V &>/dev/null || { echo -e "$running Installing curl package.."; sudo apk add curl &>/dev/null; }
  fi
fi

read rows cols < <(stty size)
cloudflareDOH="https://cloudflare-dns.com/dns-query"
cloudflareIP="1.1.1.1,1.0.0.1"
APKM_REST_API_URL="https://www.apkmirror.com/wp-json/apkm/v1/app_exists/"
AUTH_TOKEN="YXBpLXRvb2xib3gtZm9yLWdvb2dsZS1wbGF5OkNiVVcgQVVMZyBNRVJXIHU4M3IgS0s0SCBEbmJL"
[ $isAndroid == true ] && Download="/sdcard/Download" || Download="$HOME/Downloads"
simplifyNext="$HOME/Simplify/Next"
[ $isAndroid == true ] && SimplUsr="/sdcard/Simplify" || SimplUsr="$Download/Simplify"
mkdir -p $simplifyNext $SimplUsr
POST_INSTALL="$simplifyNext/POST_INSTALL"
[ $isAndroid == true ] && mkdir -p $POST_INSTALL 
simplifyNextJson="$simplifyNext/simplifyNext.json"
eButtons=("<Select>" "<Exit>")
bButtons=("<Select>" "<Back>")
cButtons=("<Select>" "<Close>")
ynButtons=("<Yes>" "<No>")
tfButtons=("<true>" "<false>")

[ $isAndroid == true ] && scripts=(Termux)
[ $isMacOS == true ] && scripts=(macOS adbInstall)
[ $isDebian == true ] && scripts=(Debian adbInstall)
[ $isArchLinux == true ] && scripts=(Arch adbInstall)
[ $isFedora == true ] && scripts=(Fedora adbInstall)
[ $isOpenSUSE == true ] && scripts=(openSUSE adbInstall)
[ $isAlpine == true ] && scripts=(Alpine adbInstall)
scripts+=(preferences art symbol menu confirmPrompt ghAuth fetchAssets dlGitHub fetchAppsInfo portSelection resetSelection viewPatches workflow APKMdl fileSelector managePatches editOptions editOptionsJson buildPatchCmd importExportSelection patchedApps dlPatchedApps)
run() {
  if [ $isAndroid == true ]; then
    [ ! -f "$PREFIX/bin/simplifyx" ] && ln -s ~/.simplifyx.sh $PREFIX/bin/simplifyx
  elif [ $isMacOS == true ]; then
    [ ! -f "/usr/local/bin/simplifyx" ] && ln -s $HOME/.simplifyx.sh /usr/local/bin/simplifyx
  else
    [ ! -f "/usr/local/bin/simplifyx" ] && sudo ln -s $HOME/.simplifyx.sh /usr/local/bin/simplifyx
  fi
  [ ! -x $HOME/.simplifyx.sh ] && chmod +x $HOME/.simplifyx.sh
  
  for ((c=0; c<${#scripts[@]}; c++)); do
    script="${scripts[c]}"
    source $simplifyNext/$script.sh
  done
  [ $isAndroid == true ] && source $simplifyNext/apkInstall.sh
}

[ -f "$simplifyNext/.version" ] && localVersion=$(cat "$simplifyNext/.version") || localVersion=
checkInternet &>/dev/null && remoteVersion=$(curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/bash/.version") || remoteVersion="$localVersion"
updates() {
  curl -sL -o "$simplifyNext/.version" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/bash/.version"
  curl -sL -o "$simplifyNext/CHANGELOG.md" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/bash/CHANGELOG.md"
  curl -sL -o "$HOME/.simplifyx.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/bash/simplifyx.sh"
  if [ $isAndroid == true ]; then
    [ ! -f "$PREFIX/bin/simplifyx" ] && ln -s ~/.simplifyx.sh $PREFIX/bin/simplifyx
  elif [ $isMacOS == true ]; then
    [ ! -f "/usr/local/bin/simplifyx" ] && ln -s $HOME/.simplifyx.sh /usr/local/bin/simplifyx
  else
    [ ! -f "/usr/local/bin/simplifyx" ] && sudo ln -s $HOME/.simplifyx.sh /usr/local/bin/simplifyx
  fi
  [ ! -x $HOME/.simplifyx.sh ] && chmod +x $HOME/.simplifyx.sh
  
  for ((c=0; c<${#scripts[@]}; c++)); do
    script="${scripts[c]}"
    curl -sL -o "$simplifyNext/$script.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/bash/$script.sh"
    source $simplifyNext/$script.sh
  done
  if [ $isAndroid == true ]; then
    curl -sL -o "$simplifyNext/apkInstall.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkInstall.sh"
    source $simplifyNext/apkInstall.sh
  fi
  curl -sL -o "$simplifyNext/apkMount.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkMount.sh"
}
[ -f "$simplifyNextJson" ] && AutoUpdatesScript=$(jq -r '.AutoUpdatesScript' "$simplifyNextJson" 2>/dev/null) || AutoUpdatesScript=true
if [ "$AutoUpdatesScript" == true ]; then
  [ "$remoteVersion" != "$localVersion" ] && { checkInternet && updates && localVersion="$remoteVersion"; } || run
else
  run
fi
[ ! -f "$simplifyNext/sources.json" ] && curl -sL -o "$simplifyNext/sources.json" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/sources.json"

[ $isMacOS == true ] && memSize=$(sysctl -n hw.memsize | awk '{printf "%.0f\n", $1/1024^3}') || memSize=$(free | awk '/Mem:/ {printf "%.1f\n", $2/1048576}')
crVersion=$(curl -sL "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Android&num=1" | jq -r '.[0].version')
USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$crVersion Mobile Safari/537.36"

branding() {
  base=${1:-branding}
  ([ ! -d "$SimplUsr/.$base" ] && [ ! -f "$SimplUsr/$base.zip" ]) && { checkInternet && dl "curl" "https://github.com/arghya339/Simplify/releases/download/all/$base.zip" "$SimplUsr/$base.zip"; }
  if [ -f "$SimplUsr/$base.zip" ] && [ ! -d "$SimplUsr/.$base" ]; then
    echo -e "$running Extrcting ${Red}$base.zip${Reset} to $SimplUsr dir.."
    pv "$SimplUsr/$base.zip" | bsdtar -xof - -C "$SimplUsr/" --no-same-owner --no-same-permissions
    mv "$SimplUsr/$base" "$SimplUsr/.$base"  # Rename branding dir to .branding to hide it from file Gallery
  fi
  ([ -d "$SimplUsr/.$base" ] && [ -f "$SimplUsr/$base.zip" ]) && rm -f "$SimplUsr/$base.zip"
}

if [ $isAndroid == true ] && { [ $su == true ] || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; }; then
  if [ -n "$(find "$POST_INSTALL" -mindepth 1 -type f -o -type d -o -type l 2>/dev/null)" ]; then
    filePath="$(find "$POST_INSTALL" -maxdepth 1 -type f -print -quit)"
    [ $isAndroid == true ] && { apkInstall "$filePath" "" && rm -f "$filePath"; } || { adbInstall "$filePath" "" && rm -f "$filePath"; }
  fi
fi

[ $printArt == true ] && { printf '\033[?25l' && printArt && sleep 3 && printf '\033[?25h'; }

while true; do
  sources=($(jq -r '.[].source' $simplifyNext/sources.json))
  patches=($(jq -r '.[].patches' $simplifyNext/sources.json))
  sources+=("Add Sources" Apps "Download Patched Apps" Settings); patches+=("Add Custom Patches Sources" "Manage Patched Apps" "Download Patched Apps" "SimplifyNext Settings")
  if menu sources eButtons patches; then
    source="${sources[selected]}"
    echo "selected: $source"
    if [ "$source" == "Settings" ]; then
      configure
    elif [ "$source" == "Download Patched Apps" ]; then
      viewDlPatchedApps
    elif [ "$source" == "Apps" ]; then
      ([ -f "$simplifyNext/patchedApps.json" ] && [ $(jq '. | length' $simplifyNext/patchedApps.json) -gt 0 ]) && viewPatchedApps
    elif [ "$source" == "Add Sources" ]; then
      read -r -p "patchesSource: " -i "ReVanced/revanced-patches" -e patchesSource
      read -r -p "displayName: " -i "ReVanced-Official" -e displayName
      displayName=$(sed 's/ /-/g' <<< "$displayName")
      cliVersions=(cliv5 cliv6 cliv4 cliv3 cliv2); cliSources=("inotia00/revanced-cli" "MorpheApp/morphe-cli" "inotia00/revanced-cli" "inotia00/revanced-cli" "inotia00/revanced-cli-arsclib")
      if menu cliVersions bButtons cliSources; then
        cliSource="${cliSources[selected]}"
        cliVersion="${cliVersions[selected]}"
        cliVersion="${cliVersion: -1}"
      fi
      if [ $cliVersion -ge 5 ]; then
        owners=(custom)
        checkInternet && owners+=($(curl -sL ${ghAuthH} "https://api.github.com/repos/Jman-Github/ReVanced-Patch-Bundles/contents/patch-bundles?ref=bundles" | jq -r '.[].name | sub("-patch-bundles$"; "")'))
        if menu owners bButtons; then
          owner="${owners[selected]}"
          case "$owner" in
            custom) read -r -p "patchesjson: " -i "https://api.revanced.app/v4/patches/list" -e patchesjson ;;
            *) patchesjson="https://raw.githubusercontent.com/Jman-Github/ReVanced-Patch-Bundles/refs/heads/bundles/patch-bundles/${owner}-patch-bundles/${owner}-stable-patches-list.json" ;;
          esac
        fi
      else
        patchesjson=null
      fi
      [ -z "$patchesjson" ] && patchesjson=null
      if [ $cliVersion -lt 5 ]; then
        read -r -p "integrationsSource: " -i "ReVanced/revanced-integrations" -e integrationsSource
      else
        integrationsSource=null
      fi
      read -r -p "microgSource: " -i "ReVanced/GmsCore" -e microgSource
      [ -z "$microgSource" ] && microgSource=null
      prereleases=false
      checkInternet && autoupdates=true || autoUpdates=false
      [ $cliVersion -eq 2 ] && arsclib=true || arsclib=false
      newSource=$(jq << EOF
  {
    "source": "$displayName",
    "cli": "$cliSource",
    "patches": "$patchesSource",
    "patchesjson": "$patchesjson",
    "integrations": "$integrationsSource",
    "microg": "$microgSource",
    "prereleases": $prereleases,
    "autoupdates": $autoupdates,
    "cliv": $cliVersion,
    "arsclib": $arsclib
  }
EOF
)
      jq <<< "$newSource"
      confirmPrompt "Would you like to add “${displayName}” source to sources.json?" "ynButtons" && response=Yes || response=No
      if [ "$response" == "Yes" ]; then
        jq --argjson new "$newSource" 'if any(.[]; .source == $new.source) then . else . + [$new] end' $simplifyNext/sources.json > tmp.json && mv tmp.json $simplifyNext/sources.json
        echo -e "$good Source “${displayName}” has been added successfully."
      fi
      continue
    else
      autoupdates=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .autoupdates' $simplifyNext/sources.json)
      cli=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .cli' $simplifyNext/sources.json)
      patches=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .patches' $simplifyNext/sources.json)
      patchesjson=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .patchesjson' $simplifyNext/sources.json)
      integrations=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .integrations' $simplifyNext/sources.json)
      microg=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .microg' $simplifyNext/sources.json)
      prereleases=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .prereleases' $simplifyNext/sources.json)
      cliv=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .cliv' $simplifyNext/sources.json)
      arsclib=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .arsclib' $simplifyNext/sources.json)
      clivDir="$simplifyNext/$cliv"
      sourceDir="$simplifyNext/$source"
      mkdir -p $clivDir $sourceDir
      patchesUpdated=false
      [ "$autoupdates" == "true" ] && { checkInternet && fetchAssets || findAssets; } || findAssets
      [ "$patchesUpdated" == "true" ] && fetchAppsInfo || patchesVersion=$(ls $sourceDir/patches-*.json | xargs -n 1 basename | sed -E 's/^patches-|.json$//g')
      sourceOptions=("View Changelog" "Patch App" "Use Pre-releases" "Auto Updates" "Manually Updating" "View Patches" "Display Name" "Source Code" "Delete Source")
      [ "$microg" != "null" ] && sourceOptions+=("Install MicroG")
      [ $cliv -ge 5 ] && sourceOptions+=("Import Assets")
      ([ "$patches" == "inotia00/revanced-patches" ] || [ "$patches" == "anddea/revanced-patches" ]) && branding
      [ "$patches" == "ReVanced/revanced-patches" ] && branding "revanced_branding"
      [ "$patches" == "MorpheApp/morphe-patches" ] && branding "morphe_branding"
      while true; do
        if menu sourceOptions bButtons; then
          sourceOption="${sourceOptions[selected]}"
          case "$sourceOption" in
            "View Changelog") glow $sourceDir/CHANGELOG.md ;;
            "Patch App")
              cliVersion=$(ls $clivDir/*-cli-*-all.jar | xargs -n 1 basename | sed -E 's/.*-cli-|-all\.jar$//g')
              [ $cliv -lt 5 ] && integrationsVersion=$(ls $sourceDir/revanced-integrations-*.apk | xargs -n 1 basename | sed -E 's/^revanced-integrations-|\.apk$//g')
              packages=($(jq -r '.[].package' $sourceDir/apps.json))
              mapfile -t names < <(jq -r '.[].name' $sourceDir/apps.json)
              links=($(jq -r '.[].link' $sourceDir/apps.json))
              while true; do
                if menu names bButtons packages; then
                  package="${packages[selected]}"
                  appName="${names[selected]}"
                  link="${links[selected]}"
                  echo "selected: $appName"
                  patchingWorkflow
                else
                  break
                fi
              done
              ;;
            "Use Pre-releases")
              prereleases=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .prereleases' $simplifyNext/sources.json)
              pButtons=("<true>" "<false>"); confirmPrompt "Use Pre-releases" "pButtons" "$prereleases" && prereleases=true || prereleases=false
              jq --arg source "$source" --argjson pre "$prereleases" 'map(if .source == $source then .prereleases = $pre else . end)' $simplifyNext/sources.json > tmp.json && mv tmp.json $simplifyNext/sources.json
              checkInternet && fetchAssets
              [ "$patchesUpdated" == "true" ] && fetchAppsInfo || patchesVersion=$(ls $sourceDir/patches-*.json | xargs -n 1 basename | sed -E 's/^patches-|.json$//g')
              ;;
            "Auto Updates")
              autoupdates=$(jq -r --arg source "$source" '.[] | select(.source == $source) | .autoupdates' $simplifyNext/sources.json)
              pButtons=("<true>" "<false>"); confirmPrompt "Auto Updates" "pButtons" "$autoupdates" && autoupdates=true || autoupdates=false
              jq --arg source "$source" --argjson aup "$autoupdates" 'map(if .source == $source then .autoupdates = $aup else . end)' $simplifyNext/sources.json > tmp.json && mv tmp.json $simplifyNext/sources.json
              if [ "$autoupdates" == "true" ]; then
                checkInternet && fetchAssets
                [ "$patchesUpdated" == "true" ] && { checkInternet && fetchAppsInfo; } || patchesVersion=$(ls $sourceDir/patches-*.json | xargs -n 1 basename | sed -E 's/^patches-|.json$//g')
              fi
              ;;
            "Manually Updating")
              checkInternet && fetchAssets
              [ "$patchesUpdated" == "true" ] && { checkInternet && fetchAppsInfo; } || patchesVersion=$(ls $sourceDir/patches-*.json | xargs -n 1 basename | sed -E 's/^patches-|.json$//g')
              ;;
            "View Patches") viewPatches ;;
            "Install MicroG")
              microgDir="$SimplUsr/$(sed 's|/|-|g' <<< "$microg")"; mkdir -p $microgDir
              checkInternet && dlgh "$microg" "false" ".apk" "$microgDir" || assetsPath=$(find "$microgDir" -type f -name "*.apk" -print -quit)
              if [ -f "$assetsPath" ]; then
                [ $isAndroid == true ] && apkInstall "$assetsPath"
                [ -n "$serial" ] && adbInstall "$assetsPath"
              fi
              unset assetsPath
              ;;
            "Import Assets")
              while true; do
                importAssets=(CLI "Patch Bundles")
                menu importAssets bButtons || break
                importAsset="${importAssets[selected]}"
                case "$importAsset" in
                  CLI)
                    if fileSelector "jar"; then
                      rm -f $clivDir/revanced-cli-*-all.jar
                      cp "$filePath" "$clivDir" && unset filePath
                      jq --arg source "$source" --argjson aup false 'map(if .source == $source then .autoupdates = $aup else . end)' $simplifyNext/sources.json > tmp.json && mv tmp.json $simplifyNext/sources.json
                      findAssets
                    fi
                    ;;
                  "Patch Bundles")
                    [ "$source" == "Morphe" ] && pArchiveExt="mpp" || pArchiveExt="rvp"
                    if fileSelector "$pArchiveExt"; then
                      rm -f $sourceDir/patches-*.$pArchiveExt
                      cp "$filePath" "$sourceDir" && unset filePath
                      jq --arg source "$source" --argjson aup false 'map(if .source == $source then .autoupdates = $aup else . end)' $simplifyNext/sources.json > tmp.json && mv tmp.json $simplifyNext/sources.json
                      findAssets
                    fi
                    ;;
                esac
              done
              ;;
            "Display Name")
              read -r -p "Display Name: " -i "$source" -e displayName
              displayName=$(sed 's/ /-/g' <<< "$displayName")
              if [ -n "$displayName" ]; then
                if [ "$source" != "$displayName" ]; then
                  jq --arg source "$source" --arg name "$displayName" 'map(if .source == $source then .source = $name else . end)' $simplifyNext/sources.json > tmp.json && mv tmp.json $simplifyNext/sources.json
                  mv "$sourceDir" "$simplifyNext/$displayName"
                  break
                fi
              fi
              ;;
            "Source Code")
              sourceURL="https://github.com/$patches"
              if [ $isAndroid == true ]; then termux-open-url "$sourceURL"; elif [ $isMacOS == true ]; then open "$sourceURL"; else xdg-open "$sourceURL" &>/dev/null; fi
              ;;
            "Delete Source")
              pButtons=("<Confirm>" "<Cancel>"); confirmPrompt "Are you sure you want to delete “${source}”?" "pButtons" "1" && response=Confirm || response=Cancel
              [ "$response" == "Confirm" ] && jq --arg source "$source" 'map(select(.source != $source))' $simplifyNext/sources.json > tmp.json && mv tmp.json $simplifyNext/sources.json
              rm -rf $sourceDir
              break
              ;;
          esac
          echo; read -p "Press Enter to continue..."
        else
          break
        fi
      done
    fi
  fi
done

