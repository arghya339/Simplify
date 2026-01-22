#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

editOptions() {
  if [ "$ShowUniversalPatches" == true ]; then
    mapfile -t patchNamesContainOptions < <(jq -r --arg pkg "$package" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) | select(.options | length > 0) | .name' $sourceDir/patches-$patchesVersion.json)
    mapfile -t patchDescriptionsContainOptions < <(jq -r --arg pkg "$package" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) | select(.options | length > 0) | .description' $sourceDir/patches-$patchesVersion.json)
  else
    mapfile -t patchNamesContainOptions < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.options | length > 0) | .name' $sourceDir/patches-$patchesVersion.json)
    mapfile -t patchDescriptionsContainOptions < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.options | length > 0) | .description' $sourceDir/patches-$patchesVersion.json)
  fi
  while true; do
    if [ ${#patchNamesContainOptions[@]} -gt 0 ]; then
      if menu patchNamesContainOptions cButtons patchDescriptionsContainOptions; then
        patchNamecontainOptions="${patchNamesContainOptions[selected]}"
        if [ "$ShowUniversalPatches" == true ]; then
          patchNameOptionsKeys=($(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select(.name == $pn) | select((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) | .options[].key' $sourceDir/patches-$patchesVersion.json))
        else
          patchNameOptionsKeys=($(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.name == $pn) | .options[].key' $sourceDir/patches-$patchesVersion.json))
        fi
        if [ "$ShowUniversalPatches" == true ]; then
          mapfile -t patchNameOptionsTitles < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) | select(.name == $pn) | .options[].title' $sourceDir/patches-$patchesVersion.json)
          mapfile -t patchNameOptionsDescriptions < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) | select(.name == $pn) | .options[].description' $sourceDir/patches-$patchesVersion.json)
        else
          mapfile -t patchNameOptionsTitles < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.name == $pn) | .options[].title' $sourceDir/patches-$patchesVersion.json)
          mapfile -t patchNameOptionsDescriptions < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.name == $pn) | .options[].description' $sourceDir/patches-$patchesVersion.json)
        fi
        while true; do
          if [ ${#patchNameOptionsTitles[@]} -gt 0 ]; then
            if menu patchNameOptionsTitles bButtons patchNameOptionsDescriptions; then
              patchNameOptionsKey="${patchNameOptionsKeys[selected]}"
              if [ "$ShowUniversalPatches" == true ]; then
                mapfile -t pairedOptions < <(jq -r --arg pkg "$package" --arg k "$patchNameOptionsKey" --arg pn "$patchNamecontainOptions" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) | select(.name == $pn) | .options[] | select(.key == $k) | if .values != null then (.values | to_entries[] | "\(.key)|\(.value)") else "\(.default)|\(.default)" end' "$sourceDir/patches-$patchesVersion.json")
                optionsDefaultValue=$(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" --arg k "$patchNameOptionsKey" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) | select(.name == $pn) | .options[] | select(.key == $k) | .default' $sourceDir/patches-$patchesVersion.json)
              else
                mapfile -t pairedOptions < <(jq -r --arg pkg "$package" --arg k "$patchNameOptionsKey" --arg pn "$patchNamecontainOptions" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.name == $pn) | .options[] | select(.key == $k) | if .values != null then (.values | to_entries[] | "\(.key)|\(.value)") else "\(.default)|\(.default)" end' "$sourceDir/patches-$patchesVersion.json")
                optionsDefaultValue=$(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" --arg k "$patchNameOptionsKey" '.[] | select(.compatiblePackages[]?.name == $pkg) | select(.name == $pn) | .options[] | select(.key == $k) | .default' $sourceDir/patches-$patchesVersion.json)
              fi
              optionsKeys=(); optionsKeyValues=()
              for pair in "${pairedOptions[@]}"; do
                optionsKeys+=("${pair%%|*}")
                optionsKeyValues+=("${pair##*|}")
              done
              # Add: VancedMicroG as gmsCoreVendorGroupId
              if [[ "$patchNameOptionsKey" == "gmsCoreVendorGroupId" ]]; then
                if ! printf '%s\n' "${optionsKeyValues[@]}" | grep -q "^com.mgoogle$"; then
                  optionsKeys+=("VancedMicroG")
                  optionsKeyValues+=("com.mgoogle")
                fi
              fi
              # Add: GoogleFamily, Pink, VancedLight appIcon / customHeader
              if [ "$patchNameOptionsKey" == "appIcon" ] || [ "$patchNameOptionsKey" == "customHeader" ] || [ "$patchNameOptionsKey" == "customIcon" ] || [ "$patchNameOptionsKey" == "custom" ]; then
                IconNames=(GoogleFamily Pink); icon_names=(google_family pink)
                ([ "$patches" == "inotia00/revanced-patches" ] || [ "$patches" == "wchill/rvx-morphed" ]) && { IconNames+=(VancedLight); icon_names+=(vanced_light); }
                ([ "$patches" == "ReVanced/revanced-patches" ] || [ "$patches" == "MorpheApp/morphe-patches" ]) && { IconNames+=(VancedLight RevancifyBlue); icon_names+=(vanced_light revancify_blue); }
                if [ "$patches" == "ReVanced/revanced-patches" ] || [ "$patches" == "MorpheApp/morphe-patches" ]; then
                  [ "$patches" == "ReVanced/revanced-patches" ] && base=revanced_branding || base=morphe_branding
                  [ "$package" == "com.google.android.youtube" ] && for=youtube || for=music
                  [ "$patchNamecontainOptions" == "Change header" ] && type=header || type=launcher
                else
                  base=branding
                  if [ "$patchNamecontainOptions" == "Custom branding icon for YouTube" ]; then for=youtube; elif [ "$patchNamecontainOptions" == "Custom branding icon for YouTube Music" ]; then for=music; fi
                  [ "$patchNameOptionsKey" == "appIcon" ] && type=launcher || type=header
                fi
                for i in "${!icon_names[@]}"; do
                  if ! printf '%s\n' "${optionsKeyValues[@]}" | grep -q "^$SimplUsr/.branding/$for/$type/${icon_names[i]}$"; then
                    optionsKeys+=("${IconNames[i]}")
                    optionsKeyValues+=("$SimplUsr/.$base/$for/$type/${icon_names[i]}")
                  fi
                done
              fi
              if [[ "${optionsKeyValues[0]}" == "true" || "${optionsKeyValues[0]}" == "false" ]]; then
                targetBool=true; [ "${optionsKeyValues[0]}" == "true" ] && targetBool=false
                if ! printf '%s\n' "${optionsKeyValues[@]}" | grep -q "^$targetBool$"; then
                  optionsKeys+=($targetBool)
                  optionsKeyValues+=($targetBool)
                fi
              else
                if ! printf '%s\n' "${optionsKeyValues[@]}" | grep -q "^$optionsDefaultValue$"; then
                  optionsKeys+=("Custom")
                  optionsKeyValues+=("$optionsDefaultValue")
                fi
                optionsKeys+=("Custom value")
                optionsKeyValues+=("")
              fi
              keys=()
              for ((i=0; i<${#optionsKeys[@]}; i++)); do
                [ "${optionsKeyValues[i]}" == "$optionsDefaultValue" ] && keys+=("${optionsKeys[i]} (Default)") || keys+=("${optionsKeys[i]}")
              done
              if menu keys bButtons optionsKeyValues; then
                key="${keys[selected]}"
                optionsKeyValue="${optionsKeyValues[selected]}"
                key="${key%% (Default)}"
                if [ "$key" == "Custom value" ]; then
                  read -r -p $'\e[1m'"$patchNameOptionsKey: "$'\e[0m' -i "$optionsDefaultValue" -e customValue
                  [ -n "$customValue" ] && optionsKeyValue="$customValue" || optionsKeyValue="$optionsDefaultValue"
                fi
                [[ "$optionsKeyValue" != "true" && "$optionsKeyValue" != "false" ]] && optionsKeyValue=$(jq -n --arg v "$optionsKeyValue" '$v')
                if [ "$ShowUniversalPatches" == "true" ]; then
                  jq --arg pkg "$package" --arg pn "$patchNamecontainOptions" --arg k "$patchNameOptionsKey" --argjson v "$optionsKeyValue" 'map(if .name == $pn and ((.compatiblePackages == null) or any(.compatiblePackages[]?; .name == $pkg)) then .options |= map(if .key == $k then .default = $v else . end) else . end)' $sourceDir/patches-$patchesVersion.json > tmp.json && mv tmp.json $sourceDir/patches-$patchesVersion.json
                else
                  jq --arg pkg "$package" --arg pn "$patchNamecontainOptions" --arg k "$patchNameOptionsKey" --argjson v "$optionsKeyValue" 'map(if .name == $pn and any(.compatiblePackages[]?; .name == $pkg) then .options |= map(if .key == $k then .default = $v else . end) else . end)' $sourceDir/patches-$patchesVersion.json > tmp.json && mv tmp.json $sourceDir/patches-$patchesVersion.json
                fi
                echo "$patchNameOptionsKey: $optionsKeyValue"
                sleep 3
              fi
            else
              break
            fi
          else
            break
          fi
        done
      else
        break
      fi
    else
      break
    fi
  done
  <<comment
  hasOptions=$(jq 'any(.[]; .options | length > 0)' $sourceDir/patches-$patchesVersion.json)
  if [ "$hasOptions" == "true" ]; then
    # options.json
    jq '[ 
      .[] 
      | select(.options | length > 0) 
      | { 
          patchName: .name, 
          options: [ 
            .options[] 
            | { 
                key: .key, 
                value: .default 
              } 
          ] 
        } 
    ] | unique_by(.patchName)' $sourceDir/patches-$patchesVersion.json
  fi
comment
}