#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

fetchReleaseURL() {
  unset versionLink
  RESPONSE_JSON=$(curl -sS --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[\"$package\"]}")
  versionLink="https://www.apkmirror.com$(jq -r ".data[] | select(.pname == \"$package\") | .release.link" <<< "$RESPONSE_JSON")"
  fetchVariant
}

cf_chl_error() {
  echo -e "$bad ${Red}Cloudflare security challenge detected!${Reset}\n$notice ${Yellow}This webpage is protected by Cloudflare's anti-bot system.${Reset}\n ${Blue}Solutions${Reset}:\n   ${Blue}1${Reset}. ${Yellow}Please try again after some time.${Reset}\n   ${Blue}2${Reset}. ${Yellow}Disable your VPN if you are connected to one.${Reset}\n   ${Blue}3${Reset}. ${Yellow}Connect to a Cloudflare WARP proxy and try again.${Reset}"
  if [ $isAndroid == true ]; then
    am start -n com.cloudflare.onedotonedotonedotone/com.cloudflare.app.presentation.main.SplashActivity &> /dev/null || termux-open-url "https://play.google.com/store/apps/details?id=com.cloudflare.onedotonedotonedotone"
  elif [ $isMacOS == true ]; then
    [ -d "/Applications/Cloudflare WARP.app" ] && open -a "Cloudflare WARP" || { formulaeInstall "cloudflare-warp"; open -a "Cloudflare WARP"; }
  else
    #gtk-launch $(xdg-settings get default-web-browser) &>/dev/null
    xdg-open "https://pkg.cloudflareclient.com/" &>/dev/null
  fi
  echo; read -p "Press Enter to continue..."
}

breadcrumbsMenu() {
  appPageHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$link")
  if ! grep -q "_cf_chl_" <<< "$appPageHtml"; then
    hasBreadcrumbsMenu=$(pup '.breadcrumbs-menu json{}' <<< "$appPageHtml" | jq 'length > 0')
    if [ "$hasBreadcrumbsMenu" == "true" ]; then
      breadcrumbsMenuJson=$(pup 'ul.breadcrumbs-menu li a json{}' <<< "$appPageHtml" | jq 'map({name: [..|.text?]|add|sub("^ +| +$";""), link: ("https://www.apkmirror.com"+.href)})')
      mapfile -t names < <(jq -r '.[].name' <<< "$breadcrumbsMenuJson")
      links=($(jq -r '.[].link' <<< "$breadcrumbsMenuJson"))
      if menu names bButtons links; then
        breadcrumbsMenuAppName="${names[selected]}"
        breadcrumbsMenuAppLink="${links[selected]}"
        echo "selected: $breadcrumbsMenuAppName"
      else
        breadcrumbsMenuAppName=$(jq <<< "$breadcrumbsMenuJson" | jq -r '.[] | select(.name | test("[()]") | not).name')
        breadcrumbsMenuAppLink=$(jq <<< "$breadcrumbsMenuJson" | jq -r '.[] | select(.name | test("[()]") | not).link')
      fi
      [ -z "$breadcrumbsMenuAppLink" ] && { breadcrumbsMenuAppLink=$(jq -r ".[0].link" <<< "$breadcrumbsMenuJson"); breadcrumbsMenuAppName=$(jq -r ".[0].name" <<< "$breadcrumbsMenuJson"); }
      [ -n "$breadcrumbsMenuAppLink" ] && { link="$breadcrumbsMenuAppLink"; appName="$breadcrumbsMenuAppName"; }
      echo -e "appLink: ${Blue}$link${Reset}"
    else
      echo "hasBreadcrumbsMenu: $hasBreadcrumbsMenu"
    fi
  else
    cf_chl_error
  fi
}

scrapeVersionsList() {
  unset versionLink
  echo -e "$running Fetching latest $appName uploads list from APKMirror.."
  page=1
  breadcrumbsMenu
  appPageHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$link")
  if ! grep -q "_cf_chl_" <<< "$appPageHtml"; then
    latestUploadsUrl="https://www.apkmirror.com$(pup '#primary a:contains("See more uploads...") attr{href}' <<< "$appPageHtml")"
    latestUploadsQueryString=$(basename "$latestUploadsUrl" 2>/dev/null)
    latestUploadsHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$latestUploadsUrl")
    if ! grep -q "_cf_chl_" <<< "$latestUploadsHtml"; then
      lastPage=$(pup 'a.last[aria-label="Last Page"] attr{href}' <<< "$latestUploadsHtml" | grep -oE '[0-9]+')
      while true; do
        [ $page -eq 1 ] && echo -e "$info Latest $appName Uploads" || echo -e "$info Latest $appName Uploads - Page $page"
        latestUploadsUrl="https://www.apkmirror.com/uploads/page/$page/$latestUploadsQueryString"
        latestUploadsHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$latestUploadsUrl")
        grep -q "_cf_chl_" <<< "$latestUploadsHtml" && cf_chl_error && break
        latestUploadsJson=$(pup 'a.fontBlack json{}' <<< "$latestUploadsHtml" | jq '.[0:30] | map({title: .text, link: ("https://www.apkmirror.com" + .href)})')
        mapfile -t availableVersions < <(jq -r '.[] | .title' <<< "$latestUploadsJson" | grep -o '[0-9].*')
        if [ -n "$version" ]; then
          for i in "${!availableVersions[@]}"; do
            versionName=$(grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' <<< "${availableVersions[$i]}")
            [ "$versionName" == "$version" ] && availableVersions[$i]="${availableVersions[$i]} (Recommended)"
          done
        fi
        [ $page -ge 3 ] && availableVersions+=(First)
        [ $page -ge 2 ] && availableVersions+=(Prev)
        [ $page -ne $lastPage ] && { availableVersions+=(Next); availableVersions+=(Last); }
        mapfile -t versionUrls < <(jq -r '.[] | .link' <<< "$latestUploadsJson")
        menu availableVersions bButtons versionUrls || break
        if [ "${availableVersions[$selected]}" == "First" ]; then
          page=1
        elif [ "${availableVersions[$selected]}" == "Prev" ]; then
          ((page--))
        elif [ "${availableVersions[$selected]}" == "Next" ]; then
          ((page++))
        elif [ "${availableVersions[$selected]}" == "Last" ]; then
          page=$lastPage
        else
          selectedVersion="${availableVersions[$selected]}"
          selectedVersion="${selectedVersion%% (Recommended)}"
          versionLink="${versionUrls[$selected]}"
          echo -e "$info versionLink: ${Blue}$versionLink${Reset} of $selectedVersion"
          break
        fi
      done
    else
      cf_chl_error
    fi
  else
    cf_chl_error
  fi
  [ -n "$versionLink" ] && fetchVariant
}

fetchVersionURL() {
  unset versionLink
  echo -e "$running Searching for target app version in APKMirror's Latest Uploads page.."
  breadcrumbsMenu
  appPageHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$link")
  if ! grep -q "_cf_chl_" <<< "$appPageHtml"; then
    latestUploadsUrl="https://www.apkmirror.com$(pup '#primary a:contains("See more uploads...") attr{href}' <<< "$appPageHtml")"
    latestUploadsQueryString=$(basename "$latestUploadsUrl" 2>/dev/null)
    page=1
    while true; do
      [ $page -eq 1 ] && echo -e "$info Latest $appName Uploads" || echo -e "$info Latest $appName Uploads - Page $page"
      latestUploadsUrl="https://www.apkmirror.com/uploads/page/$page/$latestUploadsQueryString"
      latestUploadsHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$latestUploadsUrl")
      grep -q "_cf_chl_" <<< "$latestUploadsHtml" && cf_chl_error && break
      pup 'span.infoSlide-name:contains("Version:") + span.infoSlide-value text{}' <<< $latestUploadsHtml
      latestUploadsJson=$(pup 'a.fontBlack json{}' <<< "$latestUploadsHtml" | jq -c '[.[] | select(.text != null) | {title: .text, link: ("https://www.apkmirror.com" + .href)}]')
      versionLink=$(jq -r --arg version "$version" '.[] | select(.title | test($version)) | .link' <<< "$latestUploadsJson" | head -1)
      if [ -n "$versionLink" ]; then
        echo -e "$good Found target version $version on page $page. Version page URL: ${Blue}$versionLink${Reset}"
        break
      else
        echo -e "$notice Target version $version not found on page $page! moving to next page.."
        ((page++))
      fi
    done
  else
    cf_chl_error
  fi
  [ -n "$versionLink" ] && fetchVariant
}

fetchVariant() {
  unset variantLink
  echo -e "$running Fetching variant list from APKMirror.."
  variantHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$versionLink")
  if ! grep -q "_cf_chl_" <<< "$variantHtml"; then
    variantJson=$(pup 'div.table-row json{}' <<< "$variantHtml")
    mapfile -t variantsTableRow < <(jq -r '.[] | select((.children | type) == "array" and (.children | length) == 5)
      | select(
        (.children[0].children[0].text | type) == "string" and # Version text
        (.children[0].children[1].text | type) == "string" and # Type text (BUNDLE/APK)
        (.children[1].text | type) == "string" and # Arch text
        (.children[2].text | type) == "string" and # OS text
        (.children[3].text | type) == "string" and # DPI text
        (.children[4].children[0].href | type) == "string" # Link href
      )
      | [
          (.children[0].text // .children[0].children[0].text), # Version (fallback)
          (try (.children[0].children | map(select(.class? == "colorLightBlack")) | .[0].text // "") catch ""), # Version code from colorLightBlack class
          .children[0].children[1].text, # Type (BUNDLE/APK)
          .children[1].text, # Arch
          .children[2].text, # OS
          .children[3].text, # DPI
          ("https://www.apkmirror.com" + .children[4].children[0].href) # Link
        ] | join("\t")
    ' <<< "$variantJson")
    variantList=(); variantLinks=()
    for i in "${!variantsTableRow[@]}"; do
      IFS=$'\t' read -r version vcode type arch os dpi link <<< "${variantsTableRow[$i]}"
      if [ -n "$cpuAbi" ]; then
        if [ "$arch" == "$cpuAbi" ]; then
          variantList+=("Version: $version ($vcode) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi (Recommended)")
        else
          variantList+=("Version: $version ($vcode) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi")
        fi
      else
        variantList+=("Version: $version ($vcode) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi")
      fi
      variantLinks+=("$link")
    done
    if menu variantList bButtons variantLinks; then
      IFS=$'\t' read -r version vcode type arch os dpi link <<< "${variantsTableRow[selected]}"
      variantLink="$link"
      echo -e "$notice Selected Variant: \n$info versionCode: $vcode | Type: $type | Arch: $arch | OS: $os | DPI: $dpi | Link: ${Blue}$variantLink${Reset}"
    fi
  else
    cf_chl_error
  fi
  [ -n "$variantLink" ] && fetchDownloadURL
}

antisplitApp() {
  hasBeenAntisplit=true
  filePath="${1}"
  pkgName=$2
  parentPath="$(dirname "$filePath" 2>/dev/null)"
  fileName="$(basename "$filePath" 2>/dev/null)"
  fileExt="${fileName##*.}"
  fileNameWOExt="${fileName%.*}"
  dlgh "REAndroid/APKEditor" "false" ".jar" "$simplifyNext"
  APKEditorPath="$assetsPath"
  [ $isMacOS == true ] && archiveUtility="tar" || archiveUtility="bsdtar"
  [ $isAndroid == true ] && termux-wake-lock
  if [ -n "$cpuAbi" ]; then
    mkdir -p "$parentPath/$fileNameWOExt"
    if [ $RipLib == true ]; then
      if [ "$fileExt" == "apks" ]; then
        includeFile=("splits/base-master.apk" "splits/base-${cpuAbi//-/_}.apk" "splits/base-${locale}.apk" "splits/base-${lcd_dpi}.apk")
      elif [ "$fileExt" == "xapk" ]; then
        includeFile=("$pkgName.apk" "config.${cpuAbi//-/_}.apk" "config.${locale}.apk" "config.${lcd_dpi}.apk")
      elif [ "$fileExt" == "apkm" ]; then
        includeFile=("base.apk" "split_config.${cpuAbi//-/_}.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk")
      fi
    elif [ $RipLib == false ]; then
      if [ "$fileExt" == "apks" ]; then
        includeFile=("splits/base-master.apk" "splits/base-arm64_v8a.apk" "splits/base-armeabi_v7a.apk" "splits/base-x86_64.apk" "splits/base-x86.apk" "splits/base-${locale}.apk" "splits/base-${lcd_dpi}.apk")
      elif [ "$fileExt" == "xapk" ]; then
        includeFile=("$pkgName.apk" "config.arm64_v8a.apk" "config.armeabi_v7a.apk" "config.x86_64.apk" "config.x86.apk" "config.${locale}.apk" "config.${lcd_dpi}.apk")
      elif [ $fileExt == "apkm" ]; then
        includeFile=("base.apk" "split_config.arm64_v8a.apk" "split_config.armeabi_v7a.apk" "split_config.x86_64.apk" "split_config.x86.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk")
      fi
    fi
    echo -e "$running Extracting $fileName"
    pv "$filePath" | ${archiveUtility} -xf - -C "$parentPath/$fileNameWOExt/" --include "${includeFile[@]}"
    archiveExitStatus=$?
    echo -e "$running Merge splits apk to standalone apk.."
    if [ $archiveExitStatus -eq 0 ]; then
      rm -f "$filePath"
      $java -jar $APKEditorPath m -i "$parentPath/$fileNameWOExt" -o "$parentPath/$fileNameWOExt.apk" && rm -rf "$parentPath/$fileNameWOExt"
    else
      rm -rf "$parentPath/$fileNameWOExt"
      $java -jar $APKEditorPath m -i "$filePath" -o "$parentPath/$fileNameWOExt.apk" && rm -f "$filePath"
    fi
  else
    echo -e "$running Merge splits apk to standalone apk.."
    $java -jar $APKEditorPath m -i "$filePath" -o "$parentPath/$fileNameWOExt.apk" && rm -f "$filePath"
  fi
  [ $isAndroid == true ] && termux-wake-unlock
  fileName="$fileNameWOExt.apk"
  filePath="$Download/$fileName"
}

downloadApp() {
  dlUtility=$1
  dlLink=$2
  filePath="${3}"
  fileName="$(basename "$filePath" 2>/dev/null)"
  
  echo -e "$running Downloading $fileName from ${Blue}$dlLink${Reset}"
  while true; do
    if [ "$dlUtility" == "curl" ]; then
      curl -L -C - --progress-bar -o "$filePath" "$dlLink"
      dlExitStatus=$?
    elif [ "$dlUtility" == "aria2" ]; then
      ariaCmd=(aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -d "$(dirname "$filePath" 2>/dev/null)" -o "$fileName" -U "User-Agent: $USER_AGENT" --header="Referer: $variantLink" --async-dns=true --async-dns-server=$cloudflareIP "$dlLink")
      [ $isMacOS == true ] && ariaCmd+=(--ca-certificate="/etc/ssl/cert.pem")
      "${ariaCmd[@]}"
      dlExitStatus=$?
      echo
    fi
    [ $dlExitStatus -eq 0 ] && break || { echo -e "$bad ${Red}Download failed! retrying in 5 seconds..${Reset}"; sleep 5; }
  done
  
  if [ $isMacOS == true ]; then
    sha256sum=$(shasum -a 256 "$filePath" | cut -d' ' -f1)  # perl-Digest-SHA
  else
    sha256sum=$(sha256sum "$filePath" | cut -d' ' -f1)  # coreutils
  fi
  if [ "$sha256sum" == "$SHA256" ]; then
    echo -e "$good Downloaded file appears in the original state."
  else
    echo -e "$bad Look like downloaded file appears corrupted!"
    echo -e "$notice SHA-256 SUM Diffs - Expected: ${Cyan}$SHA256${Reset} ~ Result: ${Cyan}$sha256sum${Reset}"
  fi
  [ "$file_ext" == ".apkm" ] && antisplitApp "$filePath"
}

fetchDownloadURL() {
  unset dlLink
  echo -e "$running Scraping Download Button Link.."
  downloadPageHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" "$variantLink")
  if ! grep -q "_cf_chl_" <<< "$downloadPageHtml"; then
    or=$(pup -p --charset utf-8 'a.downloadButton text{}, p:contains("- or -") text{}' <<< "$downloadPageHtml")
    downloadPageJson=$(pup 'a.downloadButton json{}' <<< "$downloadPageHtml" | jq '
      [.[] | {
        type: (if (.children[2].text | test("splits")) then "Download APK Bundle" else "Download APK" end),
        size: (.children[2].text | split(", ")[-1]),
        url: .href
      }]
    ')
    if [ -n "$or" ]; then
      jsonLength=$(jq '. | length' <<< "$downloadPageJson")
      downloadButtonTypes=()
      for ((i=0; i<jsonLength; i++)); do
        types[i]=$(jq -r ".[$i].type" <<< "$downloadPageJson")
        sizes[i]=$(jq -r ".[$i].size" <<< "$downloadPageJson")
        urls[i]=$(jq -r ".[$i].url" <<< "$downloadPageJson")
        downloadButtonTypes+=("${types[i]} | ${sizes[i]}")
      done
      if menu downloadButtonTypes bButtons urls; then
        fileType="${types[selected]}"
        fileSize="${sizes[selected]}"
        downloadButtonLink="${urls[selected]}"
      fi
    else
      fileType=$(jq -r ".[0].type" <<< "$downloadPageJson")
      fileSize=$(jq -r ".[0].size" <<< "$downloadPageJson")
      downloadButtonLink=$(jq -r ".[0].url" <<< "$downloadPageJson")
    fi
    dlSizeM=${fileSize%%[ .]*}
    ! grep -q "https://www.apkmirror.com" <<< "$downloadButtonLink" && downloadButtonLink="https://www.apkmirror.com$downloadButtonLink"
    downloadButtonLink="${downloadButtonLink//amp;/}"
    echo -e "Selected download type:\n$info fileType: $fileType\n$info fileSize: $fileSize\n$info downloadButtonLink: ${Blue}$downloadButtonLink${Reset}"
    if [ "$fileType" == "Download APK" ]; then
      file_ext=".apk"
      CERTIFICATE=$(<<< "$downloadPageHtml" awk '/<h4>APK certificate fingerprints<\/h4>/,/<h5>The cryptographic signature guarantees/' | sed -n 's/.*Certificate: *<span[^>]*>\([^<]*\)<\/span.*/\1/p' | head -n1)
      SHA256=$(<<<"$downloadPageHtml" awk '/<h4>APK file hashes<\/h4>/,/<h5>Verify the file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
    else
      file_ext=".apkm"
      CERTIFICATE=$(<<< "$downloadPageHtml" awk '/<h4>APK certificate fingerprints<\/h4>/,/<h5>The cryptographic signature of each APK/' | sed -n 's/.*Certificate: *<span[^>]*>\([^<]*\)<\/span.*/\1/p' | head -n1)
      SHA256=$(<<<"$downloadPageHtml" awk '/<h4>APK bundle file hashes<\/h4>/,/<h5>Verify the APK bundle file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
    fi
    if [ -n "$downloadButtonLink" ]; then
      echo -e "$running Scraping Download Link.."
      downloadButtonHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: $variantLink" "$downloadButtonLink")  # Referer required
      if ! grep -q "_cf_chl_" <<< "$downloadButtonHtml"; then
        downloadLink=$(pup -p --charset UTF-8 'a:contains("here") attr{href}' <<< "$downloadButtonHtml" | head -1 2>/dev/null)
          # https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=XXXXXXX&key=XxX 
          # https://www.androidpolice.com/2020/07/04/how-to-download-apps-without-the-play-store-and-why-apkmirror-is-the-best-place-to-get-them/
          # https://github.com/illogical-robot/apkmirror-public/issues
        if [ -n "$downloadLink" ]; then
          ! grep -q "https://www.apkmirror.com" <<< "$downloadLink" && downloadLink="https://www.apkmirror.com$downloadLink"
          dlLink=$(curl -sL -I --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: $variantLink" "$downloadLink" | grep -i "location:" | head -1 | sed 's/location: //i' | tr -d '\r')
          echo -e "$good Found download Link: ${Blue}$downloadLink${Reset}"
        fi
      else
        cf_chl_error
      fi
    fi
  else
    cf_chl_error
  fi
  appName="$(xargs <<< "${appName%%[:—(]*}")"
  fileName="${appName}_v${version}-${arch}${file_ext}"
  filePath="$Download/$fileName"
  [ $dlSizeM -le 25 ] && dlUtility="curl" || dlUtility="aria2"
  [ -n "$dlLink" ] && downloadApp "$dlUtility" "$dlLink" "$filePath"
}