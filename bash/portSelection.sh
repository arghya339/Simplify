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
        reduce ($old[0][]? // empty) as $patch ({};
          ($patch.compatiblePackages // [{"name": "any"}]) as $compatible |
          reduce $compatible[] as $pkg (.; 
            .["\($pkg.name? // "any")|\($patch.name)"] = $patch
          )
        )
      ) as $oldLookup |

      map(
        . as $newPatch |
        ($newPatch.compatiblePackages // [{"name": "any"}]) as $compatible |
        
        (first($compatible[] | $oldLookup["\(.name? // "any")|\($newPatch.name)"]) // $oldLookup["any|\($newPatch.name)"]) as $matched |
        
        if $matched then
          (if $matched | has("excluded") then 
            .excluded = $matched.excluded 
          else 
            .use = $matched.use 
          end) |
          
          if (.options? | length > 0) and ($matched.options? | length > 0) then
            ($matched.options | map({key: .key, value: .}) | from_entries) as $oldOpts |
            .options |= map(
              . as $opt |
              if $oldOpts[$opt.key?] and $oldOpts[$opt.key?].default != null then
                .default = $oldOpts[$opt.key?].default
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