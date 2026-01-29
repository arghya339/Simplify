#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

dl() {
  dlUtility=${1:-curl}
  dlUrl=$2
  assetsPath=$3
  fileName=$(basename $assetsPath 2>/dev/null)
  
  echo -e "$running Downloading $fileName from ${Blue}$dlUrl${Reset}"
  while true; do
    if [ "$dlUtility" == "curl" ]; then
      curl -L -C - --progress-bar -o "$assetsPath" "$dlUrl"
      dlExitStatus=$?
    elif [ "$dlUtility" == "aria2" ]; then
      ariaCmd=(aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$fileName" -d "$(dirname "$assetsPath")" "$dlUrl")
      [ $isMacOS == true ] && ariaCmd+=("--ca-certificate=\"/etc/ssl/cert.pem\"")
      eval "${ariaCmd[*]}"
      dlExitStatus=$?
      echo
    fi
    [ $dlExitStatus -eq 0 ] && break || { echo -e "$bad ${Red}Download failed! retrying in 5 seconds..${Reset}"; sleep 5; }
  done
}

dlgh() {
  repositorySlug=$1
  preReleases=$2
  ext=$3
  regex="${ext}$"
  dir=$4

  #reposJson=$(curl -sL ${ghAuthH} "https://api.github.com/repos/${repositorySlug}")
  #parentName=$(jq -r '.parent.name' <<< "$reposJson")
  #templateRepository=$(jq -r '.template_repository.name' <<< "$reposJson")
  patchesList=($(jq -r '.[].patches' $simplifyNext/sources.json))
  printf '%s\n' "${patchesList[@]}" | grep -q "^$repositorySlug$" && isPatchesRepo=true || isPatchesRepo=false
  if [ "$preReleases" == "false" ]; then
    ghApiUrl="https://api.github.com/repos/${repositorySlug}/releases/latest"
  else
    ghApiUrl="https://api.github.com/repos/${repositorySlug}/releases"
    tagName=$(curl -sL ${ghAuthH} $ghApiUrl | jq -r '.[0].tag_name')
    ghApiUrl+="/tags/$tagName"
  fi
  responseJson=$(curl -sL ${ghAuthH} $ghApiUrl)
  body=$(jq -r '.body' <<< "$responseJson")
  [ "$repositorySlug" == "REAndroid/APKEditor" ] && tagNameWOv=$(jq -r '.tag_name | sub("^V"; "")' <<< "$responseJson") || tagNameWOv=$(jq -r '.tag_name | sub("^v"; "")' <<< "$responseJson")
  assetsName=$(jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name' <<< "$responseJson" | head -1)
  dlUrl=$(jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .browser_download_url' <<< "$responseJson" | head -1)
  dlSizeM=$(jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .size' <<< "$responseJson" | head -1 | awk '{ printf "%.0f\n", $1 / 1024 / 1024 }')
  #dlSizeM=$(curl -sIL $dlUrl | grep -i Content-Length | tail -1 | awk '{ printf "%.f\n", $2 / 1024 / 1024 }')
  if [ "$repositorySlug" == "inotia00/VancedMicroG" ] || [ "$repositorySlug" == "MorpheApp/MicroG-RE" ]; then
    fileName="$(basename "$repositorySlug" 2>/dev/null)-$tagNameWOv${ext}"
    assetsNamePattern=$(sed "s/$tagNameWOv/*/g" <<< "$fileName")
  else
    assetsNamePattern=$(sed "s/$tagNameWOv/*/g" <<< "$assetsName")
  fi
  ([ "$repositorySlug" == "inotia00/VancedMicroG" ] || [ "$repositorySlug" == "MorpheApp/MicroG-RE" ]) && assetsPath="$dir/$fileName" || assetsPath="$dir/$assetsName"
  findFile=$(find "$dir" -type f -name "$assetsNamePattern" -print -quit)
  fileBaseName=$(basename $findFile 2>/dev/null)
  if [ "$repositorySlug" == "inotia00/VancedMicroG" ] || [ "$repositorySlug" == "MorpheApp/MicroG-RE" ]; then
    if [ "$fileName" != "$fileBaseName" ]; then
      [ -n "$fileBaseName" ] && echo -e "$notice diffs: $fileName ~ $fileBaseName"
      [ -f "$findFile" ] && rm -f "$findFile"
      dl "curl" "$dlUrl" "$assetsPath"
    fi
  else
    if [ "$assetsName" != "$fileBaseName" ]; then
      #([ "$parentName" == "revanced-patches-template" ] || [ "$templateRepository" == "revanced-patches-template" ] || [ "$parentName" == "revanced-patches" ] || [ "$parentName" == "revanced-patches-android6-7" ] || [ "$repositorySlug" == "ReVanced/revanced-patches" ] || [ "$(basename "$repositorySlug" 2>/dev/null)" == "revanced-patches" ] || [ "$(basename "$repositorySlug" 2>/dev/null)" == "revanced-patches-arsclib" ]) && { patchesUpdated="true"; patchesVersion="$tagNameWOv"; cat <<< "$body" > $sourceDir/CHANGELOG.md; }
      [ $isPatchesRepo == true ] && { patchesUpdated=true; patchesVersion="$tagNameWOv"; cat <<< "$body" > $sourceDir/CHANGELOG.md; }
      [ -n "$fileBaseName" ] && echo -e "$notice diffs: $assetsName ~ $fileBaseName"
      [ -f "$findFile" ] && rm -f "$findFile"
      [ $dlSizeM -lt 25 ] && dl "curl" "$dlUrl" "$assetsPath" || dl "aria2" "$dlUrl" "$assetsPath"
    fi
  fi
}