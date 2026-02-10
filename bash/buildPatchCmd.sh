#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

buildPatchCmd() {
  if [ "$ShowUniversalPatches" == true ]; then
    mapfile -t patchNamesNotHaveOptions < <(jq -r --arg pkg "$package" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) | select(.options | length == 0) | .name' $sourceDir/patches-$patchesVersion.json)
    mapfile -t patchNamesContainOptions < <(jq -r --arg pkg "$package" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) | select(.options | length > 0) | .name' $sourceDir/patches-$patchesVersion.json)
    mapfile -t disabledPatchNames < <(jq -r --arg pkg "$package" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) | select(.use == false) | .name' $sourceDir/patches-$patchesVersion.json)
  else
    mapfile -t patchNamesNotHaveOptions < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.options | length == 0) | .name' $sourceDir/patches-$patchesVersion.json)
    mapfile -t patchNamesContainOptions < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.options | length > 0) | .name' "$sourceDir/patches-$patchesVersion.json")
    mapfile -t disabledPatchNames < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.use == false) | .name' $sourceDir/patches-$patchesVersion.json)
  fi

  selectedPatchNamesContainOptions=(); selectedPatchNamesNotHaveOptions=()
  for ((i=0; i<${#selectedItems[@]}; i++)); do
    selectedItem="${selectedItems[i]}"
    for ((j=0; j<${#patchNamesContainOptions[@]}; j++)); do
      [ "$selectedItem" == "${patchNamesContainOptions[j]}" ] && selectedPatchNamesContainOptions+=("${patchNamesContainOptions[j]}")
    done
    for ((k=0; k<${#patchNamesNotHaveOptions[@]}; k++)); do
      [ "$selectedItem" == "${patchNamesNotHaveOptions[k]}" ] && selectedPatchNamesNotHaveOptions+=("${patchNamesNotHaveOptions[k]}")
    done
  done

  patchesCommand=()
  for name in "${selectedPatchNamesNotHaveOptions[@]}"; do
    [ $cliv -ge 5 ] && patchesCommand+=("-e" "$name") || patchesCommand+=("-i" "$name")
  done
  for name in "${disabledPatchNames[@]}"; do
    [ $cliv -ge 5 ] && patchesCommand+=("-d" "$name") || patchesCommand+=("-e" "$name")
  done
  for ((i=0; i<${#selectedPatchNamesContainOptions[@]}; i++)); do
    patchName="${selectedPatchNamesContainOptions[i]}"
    [ $cliv -ge 5 ] && patchesCommand+=("-e" "$patchName") || patchesCommand+=("-i" "$patchName")
    isUniversal=$(jq -r --arg pn "$patchName" '.[] | select(.name == $pn) | if .compatiblePackages == null then "true" else "false" end' $sourceDir/patches-$patchesVersion.json)
    if [ "$ShowUniversalPatches" == "true" ]; then
      mapfile -t keys < <(jq -r --arg pn "$patchName" '.[] | select(.name == $pn) | .options[].key' $sourceDir/patches-$patchesVersion.json)
    else
      mapfile -t keys < <(jq -r --arg pkg "$package" --arg pn "$patchName" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.name == $pn) | .options[].key' $sourceDir/patches-$patchesVersion.json)
    fi
    for key in "${keys[@]}"; do
      if [ "$isUniversal" == "true" ]; then
        val=$(jq -r --arg pn "$patchName" --arg k "$key" '.[] | select(.name == $pn) | .options[] | select(.key == $k) | .default' $sourceDir/patches-$patchesVersion.json)
      else
        val=$(jq -r --arg pkg "$package" --arg pn "$patchName" --arg k "$key" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.name == $pn) | .options[] | select(.key == $k) | .default' $sourceDir/patches-$patchesVersion.json)
      fi
      [ $cliv -ge 5 ] && patchesCommand+=("-O$key=$val")
    done
  done

  patchCmd=("$java")
  [ -n "$JvmHeapSize" ] && patchCmd+=("-Xmx${JvmHeapSize}M")
  patchCmd+=("-jar" "$cliPath")
  if [ $cliv -lt 5 ]; then
    [ "$patches" == "inotia00/revanced-patches-arsclib" ] && patchCmd+=("-b" "$patchesPath") || patchCmd+=("patch" "-b" "$patchesPath")
  else
    patchCmd+=("patch" "-p" "$patchesPath")
  fi
  patchCmd+=("${patchesCommand[@]}")
  [ "$patches" == "inotia00/revanced-patches-arsclib" ] && patchCmd+=("-a" "$stockAPK" "-o" "$SimplUsr" "-c" "--experimental") || patchCmd+=("$stockAPK" "-o" "$patchedAPK" "--purge" "-f")
  [ $cliv -lt 5 ] && patchCmd+=("-m" "$integrationsPath" "--options" "$sourceDir/options.json")
  ([ $cli == "inotia00/revanced-cli" ] && [ -n "$ripLib" ]) && patchCmd+=("$ripLib")
  ([ $cli == "MorpheApp/morphe-cli" ] && [ -n "$stripLibs" ]) && patchCmd+=("$stripLibs")
  ([ $isAndroid == true ] && [ "$patches" != "inotia00/revanced-patches-arsclib" ] && [ "$patches" != "MorpheApp/morphe-patches" ]) && patchCmd+=("--custom-aapt2-binary=$HOME/aapt2")

  if [ -f "$simplifyNext/ks.json" ] && [ -f "$simplifyNext/ks.keystore" ]; then
    alias=$(jq -r '.alias' "$simplifyNext/ks.json")
    CN=$(jq -r '.CN' "$simplifyNext/ks.json")
    keypass=$(jq -r '.keypass' "$simplifyNext/ks.json")
    storepass=$(jq -r '.storepass' "$simplifyNext/ks.json")
    patchCmd+=("--keystore" "$simplifyNext/ks.keystore" "--keystore-entry-alias" "$alias" "--signer" "$CN" "--keystore-entry-password" "$keypass" "--keystore-password" "$storepass")
  elif [ -f "$simplifyNext/ks.keystore" ] && [ ! -f "$simplifyNext/ks.json" ]; then
    patchCmd+=("--keystore" "$simplifyNext/ks.keystore" "--keystore-entry-alias" "ReVancedKey" "--signer" "arghya339" "--keystore-entry-password" "123456" "--keystore-password" "123456")
  fi
}