#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

importPatchSelection() {
  sourceDir="$simplifyNext/$source"
  patchesVersion=$(ls $sourceDir/patches-*.json | xargs -n 1 basename | sed -E 's/^patches-|.json$//g')
  patchesJson="$sourceDir/patches-$patchesVersion.json"
  if [ "$patches" == "d4n3436/revanced-patches-android5" ] || [ "$patches" == "inotia00/revanced-patches-arsclib" ]; then
    jq --argjson import "$(jq -c . "$importPatchSelectionJson")" '
      map(. as $patch |
        if .compatiblePackages then
          .compatiblePackages |= map(. as $pkg |
            if $import[$pkg.name] then
              ($import[$pkg.name] | index($patch.name)) as $index |
              if $index != null then
                $pkg | .excluded = false
              else
                $pkg | .excluded = true
              end
            else
              $pkg | .excluded = true
            end
          )
        else
          .
        end
      )
    ' "$patchesJson" > tmp.json && mv tmp.json "$patchesJson"
  else
    jq --argjson import "$(jq -c . "$importPatchSelectionJson")" '
      map(. as $patch |
        if .compatiblePackages then
          any(.compatiblePackages[];
            $import[.name] and ($import[.name] | index($patch.name) != null)
          ) as $shouldEnable |
          if $shouldEnable then
            .use = true
          else
            .use = false
          end
        else
          .
        end
      )
    ' "$patchesJson" > tmp.json && mv tmp.json "$patchesJson"
  fi
}

exportPatchSelection() {
  sourceDir="$simplifyNext/$source"
  patchesVersion=$(ls $sourceDir/patches-*.json | xargs -n 1 basename | sed -E 's/^patches-|.json$//g')
  patchesJson="$sourceDir/patches-$patchesVersion.json"
  exportPatchSelectionJson="$Download/$source-PatchSelection.json"
  packages=($(jq -r '[.[].compatiblePackages[]?.name] | unique[]' "$patchesJson"))
  selectionJson="{}"
  for package in "${packages[@]}"; do
    if [ "$patches" == "d4n3436/revanced-patches-android5" ] || [ "$patches" == "inotia00/revanced-patches-arsclib" ]; then
      mapfile -t enabledPatchNames < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.excluded == false) | .name' $patchesJson)
    else
      mapfile -t enabledPatchNames < <(jq -r --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | select(.use == true) | .name' $patchesJson)
    fi
    if [ ${#enabledPatchNames[@]} -gt 0 ]; then
      patchArrayJson=$(printf '%s\n' "${enabledPatchNames[@]}" | jq -R . | jq -s .)
      selectionJson=$(jq --arg pkg "$package" --argjson patches "$patchArrayJson" '. + {($pkg): $patches}' <<< "$selectionJson")
    fi
  done
  jq <<< "$selectionJson" > "$exportPatchSelectionJson"
}