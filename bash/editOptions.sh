#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

editOptions() {
  if [ "$ShowUniversalPatches" == true ]; then
    mapfile -t patchNamesContainOptions < <(jq -r --arg pkg "$package" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | select(.options | length > 0) | .name' $sourceDir/patches-$patchesVersion.json)
    mapfile -t patchDescriptionsContainOptions < <(jq -r --arg pkg "$package" '.[] | select((.compatiblePackages == null) or any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | select(.options | length > 0) | .description' $sourceDir/patches-$patchesVersion.json)
  else
    mapfile -t patchNamesContainOptions < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | select(.options | length > 0) | .name' $sourceDir/patches-$patchesVersion.json)
    mapfile -t patchDescriptionsContainOptions < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | select(.options | length > 0) | .description' $sourceDir/patches-$patchesVersion.json)
  fi
  selected_pn=0
  while true; do
    if [ ${#patchNamesContainOptions[@]} -gt 0 ]; then
      if menu patchNamesContainOptions cButtons patchDescriptionsContainOptions "" $selected_pn; then
        selected_pn=$selected
        patchNamecontainOptions="${patchNamesContainOptions[selected_pn]}"
        if [ "$ShowUniversalPatches" == true ]; then
          mapfile -t patchNameOptionsKeys < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select(.name == $pn) | select((.compatiblePackages == null) or any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | .options[] | (if .key then .key else .name end)' $sourceDir/patches-$patchesVersion.json)
        else
          mapfile -t patchNameOptionsKeys < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select(.name == $pn) | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | .options[] | (if .key then .key else .name end)' $sourceDir/patches-$patchesVersion.json)
        fi
        if [ "$ShowUniversalPatches" == true ]; then
          mapfile -t patchNameOptionsTitles < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select(.name == $pn) | select((.compatiblePackages == null) or any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | .options[] | (if .name then .name else .title end)' $sourceDir/patches-$patchesVersion.json)
          mapfile -t patchNameOptionsDescriptions < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select(.name == $pn) | select((.compatiblePackages == null) or any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | .options[].description' $sourceDir/patches-$patchesVersion.json)
        else
          mapfile -t patchNameOptionsTitles < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select(.name == $pn) | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | .options[] | (if .name then .name else .title end)' $sourceDir/patches-$patchesVersion.json)
          mapfile -t patchNameOptionsDescriptions < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" '.[] | select(.name == $pn) | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | .options[].description' $sourceDir/patches-$patchesVersion.json)
        fi
        selected_o=0
        while true; do
          if [ ${#patchNameOptionsTitles[@]} -gt 0 ]; then
            if menu patchNameOptionsTitles bButtons patchNameOptionsDescriptions "" $selected_o; then
              selected_o=$selected
              patchNameOptionsKey="${patchNameOptionsKeys[selected_o]}"
              if [ "$ShowUniversalPatches" == true ]; then
                mapfile -t pairedOptions < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" --arg k "$patchNameOptionsKey" '.[] | select(.name == $pn) | select((.compatiblePackages == null) or any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | .options[] | select((.name // "") == $k or (.key // "") == $k or (.title // "") == $k) | if .values then (.values | to_entries[] | "\(.key)|\(.value)") else empty end' "$sourceDir/patches-$patchesVersion.json")
                optionsDefaultValue=$(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" --arg k "$patchNameOptionsKey" '.[] | select(.name == $pn) | select((.compatiblePackages == null) or any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | .options[] | select((.name // "") == $k or (.key // "") == $k or (.title // "") == $k) | .default' $sourceDir/patches-$patchesVersion.json)
              else
                mapfile -t pairedOptions < <(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" --arg k "$patchNameOptionsKey" '.[] | select(.name == $pn) | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | .options[] | select((.name // "") == $k or (.key // "") == $k or (.title // "") == $k) | if .values then (.values | to_entries[] | "\(.key)|\(.value)") else empty end' "$sourceDir/patches-$patchesVersion.json")
                optionsDefaultValue=$(jq -r --arg pkg "$package" --arg pn "$patchNamecontainOptions" --arg k "$patchNameOptionsKey" '.[] | select(.name == $pn) | select(any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) | .options[] | select((.name // "") == $k or (.key // "") == $k or (.title // "") == $k) | .default' $sourceDir/patches-$patchesVersion.json)
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
              # Add: GoogleFamily, Pink, VancedLight as launcherIcon & headerIcon
              # ReVanced: YouTube & YT Music Launcher Icon - "Custom icon"; YouTube Header Icon - "Custom header logo"; YT Music Header Icon - N/A
              # RVX/RVE: YouTube & YT Music Launcher Icon - "appIcon"; YouTube & YT Music Header Icon - "customHeader"
              # Morphe: YouTube & YT Music Launcher Icon - "customIcon"; YouTube & YT Music Header Icon - "custom"
              if [ "$patchNameOptionsKey" == "Custom icon" ] || [ "$patchNameOptionsKey" == "Custom header logo" ] || [ "$patchNameOptionsKey" == "appIcon" ] || [ "$patchNameOptionsKey" == "customHeader" ] || [ "$patchNameOptionsKey" == "customIcon" ] || [ "$patchNameOptionsKey" == "custom" ]; then
                IconNames=(GoogleFamily Pink); icon_names=(google_family pink)
                [ "$patches" == "inotia00/revanced-patches" ] && { IconNames+=(VancedLight); icon_names+=(vanced_light); }
                ([ "$patches" == "ReVanced/revanced-patches" ] || [ "$patches" == "MorpheApp/morphe-patches" ]) && { IconNames+=(VancedLight RevancifyBlue); icon_names+=(vanced_light revancify_blue); }
                [ "$package" == "com.google.android.youtube" ] && for=youtube || for=music
                if [ "$patches" == "ReVanced/revanced-patches" ]; then
                  base=revanced_branding
                  [ "$patchNameOptionsKey" == "Custom icon" ] && type=launcher || type=header
                elif [ "$patches" == "MorpheApp/morphe-patches" ]; then
                  base=morphe_branding
                  [ "$patchNameOptionsKey" == "customIcon" ] && type=launcher || type=header
                else
                  base=branding
                  [ "$patchNameOptionsKey" == "appIcon" ] && type=launcher || type=header
                fi
                for i in "${!icon_names[@]}"; do
                  if ! printf '%s\n' "${optionsKeyValues[@]}" | grep -q "^$SimplUsr/.$base/$for/$type/${icon_names[i]}$"; then
                    optionsKeys+=("${IconNames[i]}")
                    optionsKeyValues+=("$SimplUsr/.$base/$for/$type/${icon_names[i]}")
                  fi
                done
              fi
              if [[ "$optionsDefaultValue" == "true" || "$optionsDefaultValue" == "false" ]]; then
                if ! printf '%s\n' "${optionsKeyValues[@]}" | grep -q "^true$"; then
                  optionsKeys+=("true")
                  optionsKeyValues+=("true")
                fi
                if ! printf '%s\n' "${optionsKeyValues[@]}" | grep -q "^false$"; then
                  optionsKeys+=("false")
                  optionsKeyValues+=("false")
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
              selected_k=
              for ((i=0; i<${#optionsKeys[@]}; i++)); do
                [ "${optionsKeyValues[i]}" == "$optionsDefaultValue" ] && { keys+=("${optionsKeys[i]} (Default)"); selected_k=${selected_k:-$i}; } || keys+=("${optionsKeys[i]}")
              done
              if menu keys bButtons optionsKeyValues "" $selected_k; then
                key="${keys[selected]}"
                optionsKeyValue="${optionsKeyValues[selected]}"
                key="${key%% (Default)}"
                if [ "$key" == "Custom value" ]; then
                  read -r -p $'\e[1m'"$patchNameOptionsKey: "$'\e[0m' -i "$optionsDefaultValue" -e customValue
                  [ -n "$customValue" ] && optionsKeyValue="$customValue" || optionsKeyValue="$optionsDefaultValue"
                fi
                [[ "$optionsKeyValue" != "true" && "$optionsKeyValue" != "false" ]] && optionsKeyValue=$(jq -n --arg v "$optionsKeyValue" '$v')
                if [ "$ShowUniversalPatches" == "true" ]; then
                  jq --arg pkg "$package" --arg pn "$patchNamecontainOptions" --arg opt "$patchNameOptionsKey" --argjson v "$optionsKeyValue" 'map(if .name == $pn and ((.compatiblePackages == null) or any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) then .options |= map(if (.name // "") == $opt or (.key // "") == $opt or (.title // "") == $opt then .default = $v else . end) else . end)' $sourceDir/patches-$patchesVersion.json > tmp.json && mv tmp.json $sourceDir/patches-$patchesVersion.json
                else
                  jq --arg pkg "$package" --arg pn "$patchNamecontainOptions" --arg opt "$patchNameOptionsKey" --argjson v "$optionsKeyValue" 'map(if .name == $pn and (any(.compatiblePackages[]?; if .name? and (.name|type)=="string" then .name == $pkg else .versions | if type=="object" then .packageName == $pkg elif type=="array" then any(.[].packageName? == $pkg) else false end end)) then .options |= map(if (.name // "") == $opt or (.key // "") == $opt or (.title // "") == $opt then .default = $v else . end) else . end)' $sourceDir/patches-$patchesVersion.json > tmp.json && mv tmp.json $sourceDir/patches-$patchesVersion.json
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