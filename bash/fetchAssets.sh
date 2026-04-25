#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

fetchAssets() {
  if [ $cliv -eq 3 ] || [ $cliv -eq 4 ]; then
    repositorySlugs=($cli $patches $patches $integrations)
    exts=(".jar" ".jar" ".json" ".apk")
    [ $cliv -eq 3 ] && dlUrl="https://github.com/inotia00/revanced-cli/releases/download/v3.1.4/revanced-cli-3.1.4-all.jar" || dlUrl="https://github.com/inotia00/revanced-cli/releases/download/v4.6.2/revanced-cli-4.6.2-all.jar"
    assetsPath="$clivDir/$(basename "$dlUrl" 2>/dev/null)"
    [ ! -f "$assetsPath" ] && dl "aria2" "$dlUrl" "$assetsPath"
    assetsPaths=("$assetsPath") && unset assetsPath
  else
    if [ $cliv -eq 2 ]; then
      repositorySlugs=($cli $patches $patches $integrations)
      exts=(".jar" ".jar" ".json" ".apk")
    else
      repositorySlugs=($cli $patches)
      [ $cliv -eq 6 ] && exts=(".jar" ".mpp") || exts=(".jar" ".rvp")
    fi
    [ "$cli" == "ReVanced/revanced-cli" ] && dlgh "${repositorySlugs[0]}" "true" "${exts[0]}" "$clivDir" || dlgh "${repositorySlugs[0]}" "$prereleases" "${exts[0]}" "$clivDir"
    assetsPaths=("$assetsPath") && unset assetsPath
  fi
  for ((i=1; i<${#repositorySlugs[@]}; i++)); do
    if [ "${repositorySlugs[i]}" == "ReVanced/revanced-patches" ]; then
      [ $prereleases == false ] && requestURL="https://api.revanced.app/v5/patches" || requestURL="https://api.revanced.app/v5/patches/prerelease"
      patchesRelease=$(curl -sL "$requestURL")
      version=$(jq -r '.version | sub("^v"; "")' <<< "$patchesRelease")
      description=$(jq -r '.description' <<< "$patchesRelease")
      downloadURL=$(jq -r '.download_url' <<< "$patchesRelease")
      #signatureDownloadURL=$(jq -r '.signature_download_url' <<< "$patchesRelease")
      fileName=$(basename "$downloadURL")
      assetsName="patches-$version.rvp"
      assetsPath="$sourceDir/$assetsName"
      findFile=$(find "$sourceDir" -type f -name "patches-*.rvp" -print -quit)
      fileBaseName=$(basename "$findFile" 2>/dev/null)
      if [ "$assetsName" != "$fileBaseName" ]; then
        [ -f "$findFile" ] && { echo -e "$notice diffs: $assetsName ~ $fileBaseName"; rm -f "$findFile"; }
        patchesUpdated=true; patchesVersion="$version"; cat <<< "$description" > "$sourceDir/CHANGELOG.md"
        dl "curl" "$downloadURL" "$assetsPath"
      fi
    else
      dlgh "${repositorySlugs[i]}" "$prereleases" "${exts[i]}" "$sourceDir"
    fi
    assetsPaths+=("$assetsPath") && unset assetsPath
  done
  if [ $cliv -lt 5 ]; then
    cliPath="${assetsPaths[0]}"
    patchesPath="${assetsPaths[1]}"
    patchesJsonPath="${assetsPaths[2]}"
    integrationsPath="${assetsPaths[3]}"
  else
    cliPath="${assetsPaths[0]}"
    patchesPath="${assetsPaths[1]}"
  fi
}

findAssets() {
  if [ $cliv -eq 3 ] || [ $cliv -eq 4 ]; then
    filePattern=("revanced-cli-*-all.jar" "revanced-patches-*.jar" "revanced-integrations-*.apk")
    [ $cliv -eq 3 ] && assetsPaths=("$clivDir/revanced-cli-3.1.4-all.jar") || assetsPath=("$clivDir/revanced-cli-4.6.2-all.jar")
  else
    if [ $cliv -eq 2 ]; then
      filePattern=("revanced-cli-*-all.jar" "revanced-patches-*.jar" "revanced-integrations-*.apk")
    else
      [ $cliv -eq 6 ] && filePattern=("morphe-cli-*-all.jar" "patches-*.mpp") || filePattern=("revanced-cli-*-all.jar" "patches-*.rvp")
    fi
    assetsPaths=("$(find "$clivDir" -type f -name "${filePattern[0]}" -print -quit)")
  fi
  for ((i=1; i<${#filePattern[@]}; i++)); do
    assetsPaths+=("$(find "$sourceDir" -type f -name "${filePattern[i]}" -print -quit)")
  done
  if [ $cliv -lt 5 ]; then
    cliPath="${assetsPaths[0]}"
    patchesPath="${assetsPaths[1]}"
    integrationsPath="${assetsPaths[2]}"
  else
    cliPath="${assetsPaths[0]}"
    patchesPath="${assetsPaths[1]}"
  fi
}