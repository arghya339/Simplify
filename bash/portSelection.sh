#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

portSelection() {
  oldPatchesJsons=($(ls -t $sourceDir/patches-*.json 2>/dev/null))
  if [ ${#oldPatchesJsons[@]} -gt 1 ]; then
    for ((i=1; i<${#oldPatchesJsons[@]}; i++)); do
      rm -f "${oldPatchesJsons[i]}"
    done
  fi
  if [ -f "${oldPatchesJsons[0]}" ]; then
    echo -e "$running Porting Patch & Options selection.."
    jq --slurpfile old "${oldPatchesJsons[0]}" '
      (
        reduce ($old[0][]? | select(.name != null)) as $patch ({};
          ($patch.compatiblePackages // [{"name": "any"}]) as $compatible |
          reduce $compatible[] as $pkg (.; 
            (if ($pkg.name | type) == "string" then $pkg.name elif ($pkg.versions?.packageName | type) == "string" then $pkg.versions.packageName else "any" end) as $pkgName |
            .["\($pkgName)|\($patch.name)"] = $patch
          )
        )
      ) as $oldLookup |

      map(
        select(.name != null) |
        . as $newPatch |
        ($newPatch.compatiblePackages // [{"name": "any"}]) as $compatible |
        
        (first($compatible[] | 
          (if (.name | type) == "string" then .name elif (.versions?.packageName | type) == "string" then .versions.packageName else "any" end) as $pkgName |
          $oldLookup["\($pkgName)|\($newPatch.name)"]
        ) // $oldLookup["any|\($newPatch.name)"]) as $matched |
        
        if $matched then
          (if $matched | has("excluded") then .excluded = $matched.excluded else . end) |
          (if $matched | has("use") then .use = $matched.use else . end) |
          (if $matched | has("default") then .default = $matched.default else . end) |
          
          if (.options? | type == "array" and length > 0) and ($matched.options? | type == "array" and length > 0) then
            ($matched.options | map(select((.key // .name // .id) != null) | {key: (.key // .name // .id | tostring), value: .}) | from_entries) as $oldOpts |
            .options |= map(
              . as $opt |
              (.key // .name // .id) as $rawOptKey |
              if ($rawOptKey != null) then
                ($rawOptKey | tostring) as $optKey |
                if ($oldOpts | has($optKey)) then
                  (if $oldOpts[$optKey] | has("default") then .default = $oldOpts[$optKey].default else . end) |
                  (if $oldOpts[$optKey] | has("value") then .value = $oldOpts[$optKey].value else . end)
                else . end
              else . end
            )
          else . end
        else . end
      )
    ' "$patchesJson" > "$sourceDir/patches-$patchesVersion.json"  && sleep 0.5 && rm -f "${oldPatchesJsons[0]}" "$patchesJson"
  else
    jq . "$patchesJson" > $sourceDir/patches-$patchesVersion.json && rm -f "$patchesJson"
  fi
}