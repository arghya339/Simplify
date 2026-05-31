#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

viewPatches() {
  allPackages=($(jq -r '[.[].compatiblePackages[]? | if .name | type == "string" then .name else .versions | (if type == "object" then .packageName elif type == "array" then .[]?.packageName else empty end) end] | unique[]' "$sourceDir/patches-$patchesVersion.json"))
  existsPackages=($(jq -r '.[].package' $sourceDir/apps.json))
  mapfile -t existsNames < <(jq -r '.[].name' $sourceDir/apps.json)
  for current in "${allPackages[@]}"; do
    found=false
    for exist in "${existsPackages[@]}"; do
      if [[ "$current" == "$exist" ]]; then
        found=true
        break
      fi
    done
    if [ "$found" == false ]; then
      existsPackages+=("$current")
      existsNames+=("$current")
    fi
  done
  jq -e 'any(.[]; .compatiblePackages == null)' "$sourceDir/patches-$patchesVersion.json" >/dev/null && { existsPackages+=("null"); existsNames+=("Universal Patches"); }
  while true; do
    if menu existsNames bButtons existsPackages; then
      package="${existsPackages[selected]}"
      if [ "$package" == "null" ]; then
        mapfile -t patchNames < <(jq -r '.[] | select(.compatiblePackages == null) .name' $sourceDir/patches-$patchesVersion.json)
        mapfile -t patchDescriptions < <(jq -r '.[] | select(.compatiblePackages == null) .description' $sourceDir/patches-$patchesVersion.json)
        decalare -ga versions
      else
        mapfile -t patchNames < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; if (.name | type) == "string" then .name == $pkg else .versions | if type == "object" then .packageName == $pkg elif type == "array" then any(.packageName == $pkg) else false end end)) .name' $sourceDir/patches-$patchesVersion.json)
        mapfile -t patchDescriptions < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; if (.name | type) == "string" then .name == $pkg else .versions | if type == "object" then .packageName == $pkg elif type == "array" then any(.packageName == $pkg) else false end end)) .description' $sourceDir/patches-$patchesVersion.json)
        mapfile -t versions < <(jq -c --arg pkg "$package" '.[] | .compatiblePackages[]? | select( if .name? and (.name|type)=="string" then .name == $pkg else if .versions? and (.versions|type)=="object" then .versions.packageName == $pkg elif .versions? and (.versions|type)=="array" then any(.versions[]?.packageName? == $pkg) else false end end ) | ( if .versions? and (.versions|type)=="array" then .versions else .versions.targets? // [] | map(.version) end )' $sourceDir/patches-$patchesVersion.json)
      fi
      while true; do
        if menu patchNames bButtons patchDescriptions versions; then
          patchName="${patchNames[selected]}"
          if [ "$package" == "null" ]; then
            mapfile -t optionsKeys < <(jq -r --arg pn "$patchName" '.[] | select(.compatiblePackages == null) | select(.name == $pn) | .options[] | (if .key then .key else .name end)' $sourceDir/patches-$patchesVersion.json)
            mapfile -t optionsTitles < <(jq -r --arg pn "$patchName" '.[] | select(.compatiblePackages == null) | select(.name == $pn) | .options[] | (if .title then .title else .name end)' $sourceDir/patches-$patchesVersion.json)
            mapfile -t optionsDescriptions < <(jq -r --arg pn "$patchName" '.[] | select(.compatiblePackages == null) | select(.name == $pn) | .options[].description' $sourceDir/patches-$patchesVersion.json)
          else
            mapfile -t optionsKeys < <(jq -r --arg pkg "$package" --arg pn "$patchName" '.[] | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else if .versions? and (.versions|type)=="object" then .versions.packageName == $pkg elif .versions? and (.versions|type)=="array" then any(.versions[].packageName? == $pkg) else false end end)) | select(.name == $pn) | .options[] | (if .key then .key else .name end)' $sourceDir/patches-$patchesVersion.json)
            mapfile -t optionsTitles < <(jq -r --arg pkg "$package" --arg pn "$patchName" '.[] | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | select(.name == $pn) | .options[] | (if .title then .title else .name end)' $sourceDir/patches-$patchesVersion.json)
            mapfile -t optionsDescriptions < <(jq -r --arg pkg "$package" --arg pn "$patchName" '.[] | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | select(.name == $pn) | .options[].description' $sourceDir/patches-$patchesVersion.json)
          fi
          if [ ${#optionsTitles[@]} -gt 0 ]; then
            while true; do
              if menu optionsTitles bButtons optionsDescriptions; then
                optionsKey="${optionsKeys[selected]}"
                optionsTitle="${optionsTitles[selected]}"
                if [ "$package" == "null" ]; then
                  mapfile -t pairedOptions < <(jq -r --arg pn "$patchName" '.[] | select(.compatiblePackages == null) | select(.name == $pn) | .options[] | select((.name == "Package name") or (.key == "packageName")) | if .values != null then (.values | to_entries[] | "\(.key)|\(.value)") else "\(.default)|\(.default)" end' "$sourceDir/patches-$patchesVersion.json")
                else
                  mapfile -t pairedOptions < <(jq -r --arg pkg "$package" --arg pn "$patchName" --arg opt "$optionsKey" '.[] | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name==$pkg else .versions | if type=="object" then .packageName==$pkg elif type=="array" then any(.[].packageName?==$pkg) else false end end)) | select(.name==$pn) | .options[] | select((.key // "")==$opt or (.name // "")==$opt or (.title // "")==$opt) | if .values then .values | to_entries[] | "\(.key)|\(.value)" else "\(.default)|\(.default)" end' "$sourceDir/patches-$patchesVersion.json")
                fi
                Keys=(); Values=()
                for pair in "${pairedOptions[@]}"; do
                  Keys+=("${pair%%|*}")
                  Values+=("${pair##*|}")
                done
                if [ "$package" == "null" ]; then
                  defaultValue=$(jq -r --arg pn "$patchName" --arg opt "$optionsKey" '.[] | select(.compatiblePackages == null) | select(.name == $pn) | .options[] | select((.name // "") == $opt or (.key // "") == $opt or (.title // "") == $opt) | (.default // "null")' $sourceDir/patches-$patchesVersion.json)
                else
                  defaultValue=$(jq -r --arg pkg "$package" --arg pn "$patchName" --arg opt "$optionsKey" '.[] | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | select(.name == $pn) | .options[] | select((.name // "") == $opt or (.key // "") == $opt or (.title // "") == $opt) | if .values then (.values | to_entries[] | "\(.key)=\(.value)") else .default end' $sourceDir/patches-$patchesVersion.json)
                fi
                if [[ "$defaultValue" == "true" || "$defaultValue" == "false" ]]; then
                  if ! printf '%s\n' "${Values[@]}" | grep -q "^true$"; then
                    Keys+=("true")
                    Values+=("true")
                  fi
                  if ! printf '%s\n' "${Values[@]}" | grep -q "^false$"; then
                    Keys+=("false")
                    Values+=("false")
                  fi
                else
                  Keys+=("Custom value")
                  Values+=("")
                fi
              keys=()
              for ((i=0; i<${#Keys[@]}; i++)); do
                [ "${Values[i]}" == "$defaultValue" ] && keys+=("${Keys[i]} (Default)") || keys+=("${Keys[i]}")
              done
              menu keys bButtons Values
              else
                break
              fi
            done
          else
            echo -e "$notice This patch has no configurable options!"; sleep 1
          fi
        else
          break
        fi
      done
    else
      break
    fi
  done
}