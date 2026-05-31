#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

resetPatchSelection() {
  patchesJson="$sourceDir/patches.json"
  [ $cliv -ge 5 ] && java -jar $cliPath patches $patchesPath -p $patchesJson
  oldPatchesJson=$(ls -t $sourceDir/patches-*.json 2>/dev/null | head -1)
  if [ -f "${oldPatchesJson}" ]; then
    echo "Resetting patch selection.."
    jq --slurpfile new "$patchesJson" '
      (
        reduce $new[0][] as $patch ({};
          ($patch.compatiblePackages // [null]) as $compatible |
          reduce $compatible[] as $pkg (.; 
            .["\($pkg.name // "any")|\($patch.name)"] = $patch
          )
        )
      ) as $masterLookup |

      map(
        . as $existingPatch |
        ($existingPatch.compatiblePackages // [null]) as $compatible |
        
        (first($compatible[] | $masterLookup["\(.name // "any")|\($existingPatch.name)"]) // $masterLookup["any|\($existingPatch.name)"]) as $matched |
        
        if $matched then
          if $matched | has("excluded") then 
             .excluded = $matched.excluded 
          else 
             .use = $matched.use 
          end
        else . end
      )' "${oldPatchesJson}" > temp.json && mv temp.json "${oldPatchesJson}"
  fi
  rm -f "$patchesJson"
}

resetPatchOptions() {
  patchesJson="$sourceDir/patches.json"
  [ $cliv -ge 5 ] && java -jar $cliPath patches $patchesPath -p $patchesJson
  oldPatchesJson=$(ls -t $sourceDir/patches-*.json 2>/dev/null | head -1)
  if [ -f "${oldPatchesJson}" ]; then
    echo "Resetting patch options.."
    jq --slurpfile new "$patchesJson" '
      (
        reduce $new[0][] as $patch ({};
          ($patch.compatiblePackages // [null]) as $compatible |
          reduce $compatible[] as $pkg (.; 
            .["\($pkg.name // "any")|\($patch.name)"] = $patch
          )
        )
      ) as $masterLookup |

      map(
        . as $existingPatch |
        ($existingPatch.compatiblePackages // [null]) as $compatible |
        (first($compatible[] | $masterLookup["\(.name // "any")|\($existingPatch.name)"]) // $masterLookup["any|\($existingPatch.name)"]) as $matched |
        
        if $matched and (.options | length > 0) and ($matched.options | length > 0) then
          ($matched.options | map({key: .key, value: .}) | from_entries) as $masterOpts |
          
          .options |= map(
            . as $opt |
            if $masterOpts[$opt.key] then
              .default = $masterOpts[$opt.key].default
            else . end
          )
        else . end
      )' "${oldPatchesJson}" > temp.json && mv temp.json "${oldPatchesJson}"
  fi
  rm -f "$patchesJson"
}