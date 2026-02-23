#!/usr/bin/bash
  
fetchAppsInfo() {
  unset appLink
  echo -e "$running Fetching app info from APKMirror.."
  RESPONSE_JSON=$(curl -sS --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[\"$PKG_NAME\"]}")
  if jq -e ".data[] | select(.pname == \"$PKG_NAME\") | .exists == true" <<< "$RESPONSE_JSON" > /dev/null 2>&1; then
    appName="$(jq -r ".data[] | select(.pname == \"$PKG_NAME\") | .app.name" <<< "$RESPONSE_JSON")"
    baseDeveloperLink=$(basename "$(jq -r ".data[] | select(.pname == \"$PKG_NAME\") | .developer.link" <<< "$RESPONSE_JSON")")
    appLink="https://www.apkmirror.com$(jq -r ".data[] | select(.pname == \"$PKG_NAME\") | .app.link" <<< "$RESPONSE_JSON")"
    releaseLink="https://www.apkmirror.com$(jq -r ".data[] | select(.pname == \"$PKG_NAME\") | .release.link" <<< "$RESPONSE_JSON")"
    echo -e "$info appLink: ${Blue}$appLink${Reset}"
  else
    echo -e "$bad ${Blue}$PKG_NAME${Reset} not found on APKMirror!" >&2
  fi
  [ -n "$appLink" ] && return || return 1
}

cf_chl_error() {
  echo -e "$bad ${Red}Cloudflare security challenge detected!${Reset}\n$notice ${Yellow}This webpage is protected by Cloudflare's anti-bot system.${Reset}\n ${Blue}Solutions${Reset}:\n   ${Blue}1${Reset}. ${Yellow}Please try again after some time.${Reset}\n   ${Blue}2${Reset}. ${Yellow}Disable your VPN if you are connected to one.${Reset}\n   ${Blue}3${Reset}. ${Yellow}Connect to a Cloudflare WARP proxy and try again.${Reset}"
  am start -n com.cloudflare.onedotonedotonedotone/com.cloudflare.app.presentation.main.SplashActivity &> /dev/null || termux-open-url "https://play.google.com/store/apps/details?id=com.cloudflare.onedotonedotonedotone"
  echo; read -p "Press Enter to continue..."
}

breadcrumbsMenu() {
  appPageHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$appLink")
  if ! grep -q "_cf_chl_" <<< "$appPageHtml"; then
    hasBreadcrumbsMenu=$(pup '.breadcrumbs-menu json{}' <<< "$appPageHtml" | jq 'length > 0')
    if [ "$hasBreadcrumbsMenu" == "true" ]; then
      breadcrumbsMenuJson=$(pup 'ul.breadcrumbs-menu li a json{}' <<< "$appPageHtml" | jq 'map({name: [..|.text?]|add|sub("^ +| +$";""), link: ("https://www.apkmirror.com"+.href)})')
      if [[ "$INDEX" == [0-9] ]]; then
        breadcrumbsMenuAppLink=$(jq -r ".[$INDEX].link" <<< "$breadcrumbsMenuJson")
      else
        breadcrumbsMenuAppName=$(jq <<< "$breadcrumbsMenuJson" | jq -r '.[] | select(.name | test("[()]") | not).name')
        breadcrumbsMenuAppLink=$(jq <<< "$breadcrumbsMenuJson" | jq -r '.[] | select(.name | test("[()]") | not).link')
      fi
      #[ -z "$breadcrumbsMenuAppLink" ] && breadcrumbsMenuAppLink=$(jq -r ".[0].link" <<< "$breadcrumbsMenuJson")
      [ -n "$breadcrumbsMenuAppLink" ] && appLink="$breadcrumbsMenuAppLink"
      echo -e "appLink: ${Blue}$appLink${Reset}"
    else
      echo "hasBreadcrumbsMenu: $hasBreadcrumbsMenu"
    fi
  else
    cf_chl_error
  fi
}

fetchVersionURL() {
  unset versionLink
  echo -e "$running Searching for target app version in APKMirror's Latest Uploads page.."
  breadcrumbsMenu
  appPageHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$appLink")
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
      versionLink=$(jq -r --arg version "$VERSION" '.[] | select(.title | test($version)) | .link' <<< "$latestUploadsJson" | head -1)
      if [ -n "$versionLink" ]; then
        echo -e "$good Found target version $VERSION on page $page. Version page URL: ${Blue}$versionLink${Reset}"
        break
      else
        echo -e "$notice Target version $VERSION not found on page $page! moving to next page.."
        ((page++))
      fi
    done
  else
    cf_chl_error
  fi
  [ -n "$versionLink" ] && return || return 1
}

mkVersionURL() {
  unset versionLink
  breadcrumbsMenu
  appPageHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$appLink")
  if ! grep -q "_cf_chl_" <<< "$appPageHtml"; then
    latestUploadsUrl="https://www.apkmirror.com$(pup '#primary a:contains("See more uploads...") attr{href}' <<< "$appPageHtml")"
    appCategoryValue="${latestUploadsUrl##*=}"
    if [ "$VERSION" == "Any" ] || [ "$VERSION" == "null" ] || [ -z "$VERSION" ]; then
      versionLink="$releaseLink"
    else
      echo -e "$info baseDeveloperLink/appCategoryValue: $baseDeveloperLink/$appCategoryValue"
      VERSION=$(tr '.' '-' <<< "$VERSION")
      versionLinks=("${appLink}${appCategoryValue}-${VERSION}-release/")  # {applink}{appCategoryValue}-{version}-release/
      versionLinks+=("${appLink}${baseDeveloperLink}-${VERSION}-release/")  # {applink}{baseDeveloperLink}-{version}-release/
      versionLinks+=("${appLink}${baseDeveloperLink}-${appCategoryValue}-${VERSION}-release/")  # {applink}{baseDeveloperLink}-{appCategoryValue}-{version}-release/
      VERSION=$(tr '-' '.' <<< "$VERSION")
      for ((i=0; i<${#versionLinks[@]}; i++)); do
        vlink="${versionLinks[i]}"
        echo -e "$info versionLinkPattern$((i+1)): $vlink"
        curl -L --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" --head --silent --fail "$vlink" >/dev/null 2>&1 && versionLink="$vlink" && break
      done
    fi
    [ -z "$versionLink" ] && fetchVersionURL  # Fallback to fetchVersionURL if hardcoded pattern fails (inefficient for old versions)
    [ -n "$versionLink" ] && echo -e "$info appName: $appName \n$info appLink: ${Blue}$appLink${Reset}"
  else
    cf_chl_error
  fi
  [ -n "$versionLink" ] && return || return 1
  unset VERSION
}

fetchVariant() {
  unset variantLink
  echo -e "$running Fetching variant list from APKMirror.."
  variantHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" "$versionLink")
  if ! grep -q "_cf_chl_" <<< "$variantHtml"; then
    variantsJson=$(pup 'div.table-row json{}' <<< "$variantHtml")
    unset found_type found_arch found_link

    mapfile -t parsed_rows < <(jq -r '.[] | select((.children | type) == "array" and (.children | length) == 5)
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
          .children[0].children[1].text, # Type (BUNDLE/APK)
          .children[1].text, # Arch
          .children[2].text, # OS
          .children[3].text, # DPI
          ("https://www.apkmirror.com" + .children[4].children[0].href) # Link
        ] | join("\t")
    ' <<< "$variantsJson")
  
    if [ ${#parsed_rows[@]} -eq 0 ]; then
      echo -e "$bad No valid variants found!"
      return 1
    elif [ ${#parsed_rows[@]} -eq 1 ]; then
      # Automatically select the single variant found
      IFS=$'\t' read -r version type arch os dpi link <<< "${parsed_rows[0]}"
      echo -e "[0] ${Blue}Version: $version | Type: $type | Arch: $arch | OS: $os | DPI: $dpi{Reset}"
      found_version="$version"
      found_type="$type"
      found_arch="$arch"
      found_os="$os"
      found_dpi="$dpi"
      found_link="$link"
      echo -e "$notice Only one variant found! auto selected: [0]"
      echo -e "Version : $found_version\nType    : $found_type\nArch    : $found_arch\nOS      : $found_os\nDPI     : $found_dpi\nLink    : ${Blue}$found_link${Reset}"
    else
      # Filter variants based on both TYPE and ARCH parameters
      for i in "${!parsed_rows[@]}"; do
        IFS=$'\t' read -r version type arch os dpi link <<< "${parsed_rows[$i]}"
        echo -e "[$i] ${Blue}Version: $version | Type: $type | Arch: $arch | OS: $os | DPI: $dpi${Reset}"
      
        if [ -n "$OS" ] && [ -n "$DPI" ]; then
          if [ "$type" == "$TYPE" ] && [ "$arch" == "$ARCH" ] && [ "$os" == "$OS" ] && [ "$dpi" == "$DPI" ]; then
            found_version="$version"
            found_type="$type"
            found_arch="$arch"
            found_os="$os"
            found_dpi="$dpi"
            found_link="$link"
            echo -e "$info autoSelectedVariant: [$i]"
            echo -e "Version : $found_version\nType    : $found_type\nArch    : $found_arch\nOS      : $found_os\nDPI     : $found_dpi\nLink    : ${Blue}$found_link${Reset}"
            break
          fi
        elif [[ "$type" == "$TYPE" ]] && [[ "$arch" == "$ARCH" ]]; then
          found_version="$version"
          found_type="$type"
          found_arch="$arch"
          found_os="$os"
          found_dpi="$dpi"
          found_link="$link"
          echo -e "$info autoSelectedVariant: [$i]"
          echo -e "Version : $found_version\nType    : $found_type\nArch    : $found_arch\nOS      : $found_os\nDPI     : $found_dpi\nLink    : ${Blue}$found_link${Reset}"
          break
        fi
      done
    fi
    VERSION="$found_version"
    Type="$found_type"
    Arch="$found_arch"
    variantLink="$found_link"
  else
    cf_chl_error
  fi
  [ -n "$variantLink" ] && return || return 1
}

fetchDownloadURL() {
  unset dlLink
  echo -e "$running Scraping Download Button Link.."
  downloadPageHtml=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" "$variantLink")
  if ! grep -q "_cf_chl_" <<< "$downloadPageHtml"; then
    or=$(pup -p --charset utf-8 'a.downloadButton text{}, p:contains("- or -") text{}' <<< "$downloadPageHtml" 2>/dev/null)
    if [ -n "$or" ]; then
      if [ "$OR" == "Download APK" ] || [ -z "$OR" ]; then
        SHA256=$(<<<"$downloadPageHtml" sed -n '/APK certificate fingerprints/,+10 { s/.*SHA-256:.*<a[^>]*>\([0-9a-fA-F]\{64\}\)<\/a>.*/\1/p; }' | head -n1)
        downloadButtonLink="https://www.apkmirror.com$(pup -p --charset utf-8 'a.downloadButton attr{href}' <<< "$downloadPageHtml" | head -1 2>/dev/null)"
        file_ext=".apk"
      elif [ "$OR" == "Download APK Bundle" ]; then
        SHA256=$(<<<"$downloadPageHtml" awk '/<h4>APK bundle file hashes<\/h4>/,/<h5>Verify the APK bundle file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
        downloadButtonLink="https://www.apkmirror.com$(pup -p --charset utf-8 'a.downloadButton attr{href}' <<< "$downloadPageHtml" | tail -1 2>/dev/null)"
        file_ext=".apkm"
      fi
    else
      downloadButtonLink="https://www.apkmirror.com$(pup -p --charset utf-8 'a.downloadButton attr{href}' <<< "$downloadPageHtml" 2>/dev/null)"
      if [ "$Type" == "APK" ]; then
        file_ext=".apk"
        SHA256=$(<<<"$downloadPageHtml" awk '/<h4>APK file hashes<\/h4>/,/<h5>Verify the file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
      else
        file_ext=".apkm"
        SHA256=$(<<<"$downloadPageHtml" awk '/<h4>APK bundle file hashes<\/h4>/,/<h5>Verify the APK bundle file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
      fi
    fi
  
    if [ -n "$downloadButtonLink" ]; then
      echo -e "$good Found download button Link: ${Blue}$downloadButtonLink${Reset}"
      echo -e "$running Scraping Download Link.."
      downloadButtonHtml=$(curl -sL --doh-url $cloudflareDOH -A "$USER_AGENT" -H "Referer: $variantLink" "$downloadButtonLink")
      if ! grep -q "_cf_chl_" <<< "$downloadButtonHtml"; then
        downloadLink="https://www.apkmirror.com$(pup -p --charset UTF-8 'a:contains("here") attr{href}' <<< "$downloadButtonHtml" | head -1 2>/dev/null)"
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
  [ -n "$dlLink" ] && return || return 1
}

antisplitApp() {   
  bash $Simplify/dlGitHub.sh "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
  APKEditor=$(find "$Simplify" -type f -name "APKEditor-*.jar" -print -quit)
  mkdir -p "$Download/${appName}_v${VERSION}-${cpuAbi}"
  echo -e "$running Extracting APKM content.."
  termux-wake-lock
  if [ $RipLib -eq 1 ]; then
    pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${VERSION}-${cpuAbi}/" --include "base.apk" "split_config.${cpuAbi//-/_}.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
    bsdtar_exit_code=$?
  elif [ $RipLib -eq 0 ]; then
    pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${VERSION}-${cpuAbi}/" --include "base.apk" "split_config.arm64_v8a.apk" "split_config.armeabi_v7a.apk" "split_config.x86_64.apk" "split_config.x86.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
    bsdtar_exit_code=$?
  fi
  if [ $bsdtar_exit_code -ne 0 ]; then  # check if bsdtar return exit code 1 (error)
    pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${VERSION}-${cpuAbi}/"
  fi
  rm -f "$outputPath"
  echo -e "$running Merge splits apk to standalone apk.."
  $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $APKEditor m -i "$Download/${appName}_v${VERSION}-${cpuAbi}" -o "$Download/${appName}_v${VERSION}-${cpuAbi}.apk"
  termux-wake-unlock
  rm -rf "$Download/${appName}_v${VERSION}-${cpuAbi}"
}

rmPreDownloadApp() {
  if [ "$file_ext" == ".apkm" ]; then
    fileNamePattern="${appName}_v*-${cpuAbi}.apk"
    apkName="${appName}_v${VERSION}-${cpuAbi}.apk"
  else
    fileNamePattern="${appName}_v*-${Arch}.apk"
    apkName="${appName}_v${VERSION}-${Arch}.apk"
  fi
  findFile=$(find "$Download" -type f -name "${fileNamePattern}" -print -quit)
  
  if [ -f "$findFile" ]; then
    fileBaseName=$(basename "$findFile" 2>/dev/null)
    if [ "$fileBaseName" != "${apkName}" ]; then
      rm -f "$findFile"  # remove previous version apk
    fi
  fi
}

downloadApp() {
  #appName="${appName//[\*\\\/:\?\|<>]/}"
  appName=$(echo "${appName%%[:—(]*}" | xargs)
  FileName="${appName}_v${VERSION}-${Arch}${file_ext}"
  outputPath="${Download}/${FileName}"
  rmPreDownloadApp
  if [ ! -f "$Download/${appName}_v${VERSION}-${cpuAbi}.apk" ] || [ ! -f "$outputPath" ]; then
    echo -e "$running Downloading $appName from ${Blue}$dlLink${Reset}.."
    while true; do
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$FileName" -U "User-Agent: $USER_AGENT" -U "Referer: $downloadButtonLink" --async-dns=true --async-dns-server="$cloudflareIP" "$dlLink"
      exitStatus=$?
      echo  # Space
      [ $exitStatus -eq 0 ] && { echo -e "$good Download Complete. Saved to ${Cyan}$outputPath${Reset}"; break; } || { echo -e "$bad Download failed! retrying in 5 secons.." && sleep 5; }
    done
    sha256sum=$(sha256sum "$outputPath" | cut -d' ' -f1)
    if [ "$sha256sum" == "$SHA256" ]; then
      echo -e "$good Downloaded file appears in the original state."
    else
      echo -e "$bad Look like downloaded file appears corrupted!"
      echo -e "$notice SHA-256 SUM Diffs - Expected: ${Cyan}$SHA256${Reset} ~ Result: ${Cyan}$sha256sum${Reset}"
    fi
  else
    [ "$file_ext" == ".apk" ] && echo -e "$notice Download skiped! ${Cyan}${appName}_v${VERSION}-${Arch}.apk${Reset} already exist." || echo -e "$notice Download skiped! ${Cyan}${appName}_v${VERSION}-${cpuAbi}.apk${Reset} already exist."
  fi
  [ "$file_ext" == ".apkm" ] && antisplitApp
}

APKMdl() {
  PKG_NAME=$1
  INDEX=${2:-0}  # breadcrumbsMenuIndex
  VERSION=$3
  TYPE=$4
  ARCH=$5
  OS=$6
  DPI=$7
  OR=$8
  
  fetchAppsInfo && mkVersionURL && fetchVariant && fetchDownloadURL && downloadApp
}
##################################################################################
