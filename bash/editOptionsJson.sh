#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

editOptionsJson() {
  java -jar $cliPath options $patchesPath -p $sourceDir/options.json
  mapfile -t patchNames < <(jq -r '.[].patchName' $sourceDir/options.json)
  while true; do
    if [ ${#patchNames[@]} -gt 0 ]; then
      if menu patchNames cButtons; then
        patchName="${patchNames[selected]}"
        while true; do
          mapfile -t patchKeys < <(jq -r --arg pn "$patchName" '.[] | select(.patchName == $pn) | .options[].key' $sourceDir/options.json)
          mapfile -t values < <(jq -r --arg pn "$patchName" '.[] | select(.patchName == $pn) | .options[].value' $sourceDir/options.json)
          if [ ${#patchKeys[@]} -gt 0 ]; then
            if menu patchKeys bButtons; then
              patchKey="${patchKeys[selected]}"
              value="${values[selected]}"
              keyValues=("$value")
              [ "$value" == "true" ] && keyValues+=(false)
              [ "$value" == "false" ] && keyValues+=(true)
              [[ "$value" != "true" && "$value" != "false" ]] && keyValues+=("Custom value")
              if menu keyValues bButtons; then
                keyValue="${keyValues[selected]}"
                if [ "$keyValue" == "Custom value" ]; then
                  read -r -p $'\e[1m'"$patchNameOptionsKey: "$'\e[0m' -i "$optionsDefaultValue" -e customValue
                  [ -n "$customValue" ] && keyValue="$customValue" || keyValue="$value"
                fi
                [[ "$keyValue" != "true" && "$keyValue" != "false" ]] && keyValue=$(jq -n --arg v "$keyValue" '$v')
                jq --arg pn "$patchName" --arg k "$patchKey" --argjson v "$keyValue" '(.[] | select(.patchName == $pn) | .options[] | select(.key == $k)).value = $v' $sourceDir/options.json > tmp.json && mv tmp.json $sourceDir/options.json
                echo "$patchKey: $keyValue"
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
}