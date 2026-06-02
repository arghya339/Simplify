#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

fetchAppsInfo() {
  echo -e "$running Fetching apps info from APKMirror.."
  compatiblePackagesJson=$(jq '[.[] | select(.compatiblePackages != null) | .compatiblePackages | if type == "array" then .[] else empty end | {package: (if (.name | type) == "string" then .name else .versions.packageName end), versions: (if (.name | type) == "string" then (if (.versions | type) == "array" then .versions else [] end) else [.versions.targets[]?.version] end)}] | group_by(.package) | map({package: .[0].package, versions: (map(.versions) | flatten | unique | sort | if length == 0 then null else . end)}) | map(select(.package != null))' $patchesJson)
  totalPackages=$(jq length <<< "$compatiblePackagesJson")
  packages=($(jq -r ".[].package" <<< "$compatiblePackagesJson"))
  
  pnames=$(sed 's/ /", "/g; s/^/"/; s/$/"/' <<< "${packages[@]}")
  RESPONSE_JSON=$(curl -sL --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[$pnames]}")
  
  exists_pname=($(jq -r '.data[] | select(.exists == true) | .pname' <<< "$RESPONSE_JSON"))
  not_exists_pname=($(jq -r '.data[] | select(.exists == false) | .pname' <<< "$RESPONSE_JSON"))
  echo -e "$info totalApps: $totalPackages\n$good found: ${#exists_pname[@]}\n$notice not-found: ${#not_exists_pname[@]}"

  declare -a appName appLink versions
  for i in ${!exists_pname[@]}; do
    appName[i]="$(jq -r ".data[] | select(.pname == \"${exists_pname[i]}\") | .app.name" <<< "$RESPONSE_JSON" | html2text)"
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