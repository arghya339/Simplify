#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

fetchAppsInfo() {
  echo -e "$running Fetching apps info from APKMirror.."
  compatiblePackagesJson=$(jq '[.[] | select(.compatiblePackages != null) | .compatiblePackages | if type == "array" then .[] else empty end | {package: (if (.name | type) == "string" then .name else .versions.packageName end), versions: (if (.name | type) == "string" then (if (.versions | type) == "array" then .versions else [] end) else [.versions.targets[]?.version] end)}] | group_by(.package) | map({package: .[0].package, versions: (map(.versions) | flatten | unique | sort | if length == 0 then null else . end)}) | map(select(.package != null))' $patchesJson)
  totalPackages=$(jq length <<< "$compatiblePackagesJson")
  packages=($(jq -r ".[].package" <<< "$compatiblePackagesJson"))
  
  maxItems=100  # APKMirror rest api pnames parameters support max 100 items, if pnames contain more than 100 items rest response rest_too_many_items with 400 error code.
  declare -a exists_pname not_exists_pname itemsName appLink
  for ((i=0; i<${#packages[@]}; i+=maxItems)); do
    hundredItems=("${packages[@]:i:maxItems}")
    pnames=$(sed 's/ /", "/g; s/^/"/; s/$/"/' <<< "${hundredItems[@]}")
    RESPONSE_JSON=$(curl -sL --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[$pnames]}")
    if jq -e '.data? | has("status")' <<< "$RESPONSE_JSON" &>/dev/null; then
      RESPONSE_STATUS=$(jq -r '.data.status' <<< "$RESPONSE_JSON")
      [ $RESPONSE_STATUS -ne 200 ] && { jq <<< "$RESPONSE_JSON"; echo; read -p "Press Enter to continue..."; }
    fi
    exists_pname+=($(jq -r '.data[] | select(.exists == true) | .pname' <<< "$RESPONSE_JSON"))
    not_exists_pname+=($(jq -r '.data[] | select(.exists == false) | .pname' <<< "$RESPONSE_JSON"))
    mapfile -t -O "${#itemsName[@]}" itemsName < <(jq -r '.data[] | select(.exists == true) | .app.name' <<< "$RESPONSE_JSON")
    mapfile -t -O "${#appLink[@]}" appLink < <(jq -r '.data[] | select(.exists == true) | "https://apkmirror.com\(.app.link)"' <<< "$RESPONSE_JSON")
  done
  echo -e "$info totalApps: $totalPackages\n$good found: ${#exists_pname[@]}\n$notice not-found: ${#not_exists_pname[@]}"

  declare -a appName versions
  for i in ${!exists_pname[@]}; do
    appName[i]="$(html2text <<< "${itemsName[i]}")"
    versions[i]="$(jq -c ".[] | select(.package == \"${exists_pname[i]}\") | .versions" <<< "$compatiblePackagesJson")"
  done
  for i in ${!not_exists_pname[@]}; do
    exists_pname+=("${not_exists_pname[i]}")
    appName+=("${not_exists_pname[i]}")
    versions+=("$(jq -c ".[] | select(.package == \"${not_exists_pname[i]}\") | .versions" <<< "$compatiblePackagesJson")")
    appLink+=("null")
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