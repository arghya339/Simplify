#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

fetchAppsInfo() {
  echo -e "$running Fetching apps info from APKMirror.."
  patchesJson="$sourceDir/patches.json"
  if [ $cliv -ge 5 ]; then
    if [ "$cli" == "inotia00/revanced-cli" ]; then
      java -jar $cliPath patches $patchesPath -p $patchesJson
    else
      if [ "$patches" == "ReVanced/revanced-patches" ]; then
        [ "$prereleases" == true ] && patchesjson="$patchesjson?prerelease=true"
        curl -sL "$patchesjson" > $patchesJson
      else
        [ "$prereleases" == true ] && patchesjson=$(sed -E 's/(main|revanced-extended|arsclib-old|stable)/dev/g' <<< "$patchesjson")  # replace main, revanced-extended, arsclib-old, or stable with dev
        curl -sL "$patchesjson" | jq -r '.patches' > $patchesJson
      fi
      jq 'map(.compatiblePackages |= (if . == null then null else to_entries | map({name: .key, versions: .value}) end))' "$patchesJson" > "tmp.json" && mv "tmp.json" "$patchesJson"  # convert compatiblePackages into array of objects (containing name & versions) instead of a dictionary
    fi
  fi
  compatiblePackagesJson=$(jq '[.[] | select(.compatiblePackages != null) | .compatiblePackages[]] 
    | group_by(.name) 
    | map({
        package: .[0].name, 
        versions: ([.[].versions] | flatten | map(select(. != null)) | unique | sort | reverse | if length == 0 then null else . end)
    })' $patchesJson)
  totalPackages=$(jq length <<< "$compatiblePackagesJson")
  packages=($(jq -r ".[].package" <<< "$compatiblePackagesJson"))
  
  pnames=$(sed 's/ /", "/g; s/^/"/; s/$/"/' <<< "${packages[@]}")
  RESPONSE_JSON=$(curl -sL --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[$pnames]}")
  
  exists_pname=($(jq -r '.data[] | select(.exists == true) | .pname' <<< "$RESPONSE_JSON"))
  not_exists_pname=($(jq -r '.data[] | select(.exists == false) | .pname' <<< "$RESPONSE_JSON"))
  echo -e "$info totalApps: $totalPackages\n$good found: ${#exists_pname[@]}\n$notice not-found: ${#not_exists_pname[@]}"

  declare -a appName appLink versions
  for i in ${!exists_pname[@]}; do
    appName[i]="$(jq -r ".data[] | select(.pname == \"${exists_pname[i]}\") | .app.name" <<< "$RESPONSE_JSON")"
    versions[i]="$(jq -c ".[] | select(.package == \"${exists_pname[i]}\") | .versions" <<< "$compatiblePackagesJson")"
    appLink[i]="https://apkmirror.com$(jq -r ".data[] | select(.pname == \"${exists_pname[i]}\") | .app.link" <<< "$RESPONSE_JSON")"
  done

  appsJson="[]"
  for i in ${!exists_pname[@]}; do
    pname="${exists_pname[i]}"
    appName="${appName[i]}"
    versions="${versions[i]}"
    appLink="${appLink[i]}"
    newApp=$(jq -n --arg pkg "$pname" --argjson ver "$versions" --arg name "$appName" --arg link "$appLink" '{package: $pkg, versions: $ver, name: $name, link: $link}')
    appsJson=$(jq ". += [$newApp]" <<< "$appsJson")
  done
  echo "$appsJson" > $sourceDir/apps.json
  unset pname version appName appLink
  portSelection
}