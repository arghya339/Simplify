#!/usr/bin/bash

# --- Colored log indicators ---
good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

Green="\033[92m"
Red="\033[91m"
Blue="\033[94m"
skyBlue="\033[38;5;117m"
Cyan="\033[96m"
White="\033[37m"
Yellow="\033[93m"
Orange="\e[38;5;208m"
Reset="\033[0m"

# --- Global Variable ---
APKM_REST_API_URL="https://www.apkmirror.com/wp-json/apkm/v1/app_exists/"
USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Mobile Safari/537.36"  # HTML User Agent: chrome://version/
AUTH_TOKEN="YXBpLXRvb2xib3gtZm9yLWdvb2dsZS1wbGF5OkNiVVcgQVVMZyBNRVJXIHU4M3IgS0s0SCBEbmJL"
cloudflareDOH="https://cloudflare-dns.com/dns-query"
cloudflareIP="1.1.1.1,1.0.0.1"
Download="/sdcard/Download"  # Download dir
jdkVersion="21"
Simplify="$HOME/Simplify"
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
  cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
else
  cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android architecture
fi
RipLocale="$(jq -r '.RipLocale' "$simplifyJson" 2>/dev/null)"
RipDpi="$(jq -r '.RipDpi' "$simplifyJson" 2>/dev/null)"
RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
if [ $RipLocale -eq 1 ]; then
  locale=$(getprop persist.sys.locale | cut -d'-' -f1)  # Get System Languages
  if [ -z $locale ]; then
    locale=$(getprop ro.product.locale | cut -d'-' -f1)  # Get Languages
  fi
elif [ $RipLocale -eq 0 ]; then
  locale="[a-z][a-z]"
fi
if [ $RipDpi -eq 1 ]; then
  density=$(getprop ro.sf.lcd_density)  # Get the device screen density
  # Check and categorize the density
  if [ "$density" -le 120 ]; then
    lcd_dpi="ldpi"  # Low Density
  elif [ "$density" -le 160 ]; then
    lcd_dpi="mdpi"  # Medium Density
  elif [ "$density" -le 240 ]; then
    lcd_dpi="hdpi"  # High Density
  elif [ "$density" -le 320 ]; then
    lcd_dpi="xhdpi"  # Extra High Density
  elif [ "$density" -le 480 ]; then
    lcd_dpi="xxhdpi"  # Extra Extra High Density
  elif [ "$density" -gt 480 ] || [ "$density" -ge 640 ]; then
    lcd_dpi="xxxhdpi"  # Extra Extra Extra High Density
  else
    lcd_dpi="*dpi"
  fi
elif [ $RipDpi -eq 0 ]; then
  lcd_dpi="*dpi"
fi

APKMdl() {
  local PKG_NAME=$1
  local VERSION=$2
  local TYPE=$3
  local ARCH=$4
  local OS=$5
  local DPI=$6
  local OR=$7
  local RESPONSE_JSON
  local html_content
  local HTML_CONTENT
  local final_apk_link_content
  local FileName
  
  RESPONSE_JSON=$(curl -sS --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[\"$PKG_NAME\"]}")
  
  if [ $? -ne 0 ]; then
      echo -e "$bad Error: API request failed for ${Blue}apkmirror.com${Reset}.\nTry again later..." >&2
    return 1
  fi
  
  if ! echo "$RESPONSE_JSON" | jq -e ".data[] | select(.pname == \"$PKG_NAME\") | .exists == true" > /dev/null 2>&1; then
    echo -e "$bad Error: ${Blue}$PKG_NAME${Reset} pkgName not found on APKMirror!" >&2
    return 1
  fi
  #echo "$RESPONSE_JSON" | jq -e ".data[]"  # for debug
  appLink="https://www.apkmirror.com$(jq -r ".data[] | select(.pname == \"$PKG_NAME\") | .app.link" <<< "$RESPONSE_JSON")"
  appLink=$(echo "$appLink" | sed 's/-android-automotive//g; s/-wear-os//g; s/-daydream//g')
  second_last_segment=$(basename "$appLink")  # chrome
  appName=$(jq -r ".data[] | select(.pname == \"$PKG_NAME\") | .app.name" <<< "$RESPONSE_JSON")
  appName=$(echo "$appName" | sed 's/(Android Automotive)//g; s/(Wear OS)//g; s/(Daydream)//g' | xargs)
  versionLink=$(jq -r ".data[] | select(.pname == \"$PKG_NAME\") | .release.link" <<< "$RESPONSE_JSON" | grep -Eo "/apk/[^\"']+" | grep "/apk/.*$second_last_segment" | head -n 1 | sed -E 's/-[0-9].*//')
  selectedApp=$(basename "$versionLink" | sed 's/-android-automotive//g; s/-wear-os//g; s/-daydream//g')  # google-chrome
  if [ "$VERSION" != "Any" ] || [ "$VERSION" != "null" ] && [ -n "$VERSION" ]; then
    VERSION=$(echo "$VERSION" | tr '.' '-')
    version_link="${appLink}${selectedApp}-${VERSION}-release/"
    if ! curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" --head --silent --fail "$version_link" >/dev/null 2>&1; then
      version_link="${appLink}${second_last_segment}-${VERSION}-release/"
    fi
    if ! curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" --head --silent --fail "$version_link" >/dev/null 2>&1; then
      version_link="${appLink}${selectedApp}-${second_last_segment}-${VERSION}-release/"
    fi
    if ! curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" --head --silent --fail "$version_link" >/dev/null 2>&1; then
      echo -e "${notice} Version link could not be generated! Falling back to latest version."
      version_link="https://www.apkmirror.com$(jq -r ".data[] | select(.pname == \"$PKG_NAME\") | .release.link" <<< "$RESPONSE_JSON")"
    fi
    VERSION=$(echo "$VERSION" | tr '-' '.')
  elif [ "$VERSION" == "Any" ] || [ "$VERSION" == "null" ] || [ -z "$VERSION" ]; then
    version_link="https://www.apkmirror.com$(jq -r ".data[] | select(.pname == \"$PKG_NAME\") | .release.link" <<< "$RESPONSE_JSON")"
  fi
  
  if [ -z "$appLink" ] || [ -z $second_last_segment ] || [ -z "$appName" ] || [ -z $selectedApp ]; then
    echo -e "$bad Error: Could not retrieve appInfo!" >&2
    return 1
  else
    echo -e "$info appName: $appName \n$info appLink: ${Blue}$appLink${Reset} \n$info second_last_segment: $second_last_segment \n$info selectedApp: $selectedApp \n$info version_link: ${Blue}$version_link${Reset}\n"
  fi
  
  echo -e "$running Scraping variant details from: ${Blue}$version_link${Reset}"
  html_content=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" "$version_link")
  if [ $? -ne 0 ]; then
    echo -e "$bad Error: Scraping variant info failed for ${Blue}apkmirror.com${Reset}.\nTry again later..."
    return 1
  fi
  
  variantsJson=$(echo "$html_content" | pup 'div.table-row json{}')

  # Use local variables to hold the found variant's details
  local found_type=""
  local found_arch=""
  local found_link=""

  mapfile -t parsed_rows < <(echo "$variantsJson" | jq -r '.[] | select((.children | type) == "array" and (.children | length) == 5)
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
  ')
  
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
    echo "Version : $found_version"
    echo "Type    : $found_type"
    echo "Arch    : $found_arch"
    echo "OS      : $found_os"
    echo "DPI     : $found_dpi"
    echo -e "Link    : ${Blue}$found_link${Reset}"
  else
    # Filter variants based on both TYPE and ARCH parameters
    # Use a loop with indices to print the row number
    for i in "${!parsed_rows[@]}"; do
      IFS=$'\t' read -r version type arch os dpi link <<< "${parsed_rows[$i]}"
      # Print the row number here (using $i)
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
          echo "Version : $found_version"
          echo "Type    : $found_type" # Print selected Type
          echo "Arch    : $found_arch"
          echo "OS      : $found_os"
          echo "DPI     : $found_dpi"
          echo -e "Link    : ${Blue}$found_link${Reset}"
          break # Exit the loop once a match is found
        fi
      elif [[ "$type" == "$TYPE" ]] && [[ "$arch" == "$ARCH" ]]; then
        found_version="$version"
        found_type="$type"
        found_arch="$arch"
        found_os="$os"
        found_dpi="$dpi"
        found_link="$link"
        echo -e "$info autoSelectedVariant: [$i]"
        echo "Version : $found_version"
        echo "Type    : $found_type" # Print selected Type
        echo "Arch    : $found_arch"
        echo "OS      : $found_os"
        echo "DPI     : $found_dpi"
        echo -e "Link    : ${Blue}$found_link${Reset}"
        break # Exit the loop once a match is found
      fi
    done
  fi

  # Check if a variant was found
  if [ -z "$found_type" ]; then
    echo -e "$bad No $TYPE variant found for architecture $ARCH!"
    return 1
  fi
  
  # Assign the found values to the variables used later in the script
  VERSION="$found_version"
  Type="$found_type"
  Arch="$found_arch"
  Link="$found_link"
  echo  # Space
  
  echo -e "$running Scraping actual download button from: ${Blue}$Link${Reset}"
  # Fetch the HTML of the download page
  HTML_CONTENT=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" "$Link")
  if [ $? -ne 0 ] || [ -z "$HTML_CONTENT" ]; then
    echo -e "$bad Error: Scraping download url failed for ${Blue}apkmirror.com${Reset}.\nTry again later..."
    return 1
  fi
  
  or=$(echo "$HTML_CONTENT" | pup -p --charset utf-8 'a.downloadButton text{}, p:contains("- or -") text{}' 2>/dev/null)
  if [ -n "$or" ]; then
    # This selector looks for an <a> tag with 'downloadButton' in its class list and extracts its href.
    if [ "$OR" == "Download APK" ] || [ -z "$OR" ]; then
      SHA256=$(<<<"$HTML_CONTENT" sed -n '/APK certificate fingerprints/,+10 { s/.*SHA-256:.*<a[^>]*>\([0-9a-fA-F]\{64\}\)<\/a>.*/\1/p; }' | head -n1)
      final_apk_link="https://www.apkmirror.com$(echo "$HTML_CONTENT" | pup -p --charset utf-8 'a.downloadButton attr{href}' | head -1 2>/dev/null)"
      file_ext=".apk"
    elif [ "$OR" == "Download APK Bundle" ]; then
      SHA256=$(<<<"$HTML_CONTENT" awk '/<h4>APK bundle file hashes<\/h4>/,/<h5>Verify the APK bundle file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
      final_apk_link="https://www.apkmirror.com$(echo "$HTML_CONTENT" | pup -p --charset utf-8 'a.downloadButton attr{href}' | tail -1 2>/dev/null)"
      file_ext=".apkm"
    fi
  else
    final_apk_link="https://www.apkmirror.com$(echo "$HTML_CONTENT" | pup -p --charset utf-8 'a.downloadButton attr{href}' 2>/dev/null)"
    if [ "$Type" == "APK" ]; then
      file_ext=".apk"
      SHA256=$(<<<"$HTML_CONTENT" awk '/<h4>APK file hashes<\/h4>/,/<h5>Verify the file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
    else
      file_ext=".apkm"
      SHA256=$(<<<"$HTML_CONTENT" awk '/<h4>APK bundle file hashes<\/h4>/,/<h5>Verify the APK bundle file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
    fi
  fi
  
  if [ -n "$final_apk_link" ]; then
    echo -e "$running Fetching intermediate download button content from: ${Blue}$final_apk_link${Reset}"
    final_apk_link_content=$(curl -sL --doh-url $cloudflareDOH -A "$USER_AGENT" -H "Referer: $Link" "$final_apk_link")
    if [ $? -ne 0 ]; then
      echo -e "$bad Error: failed to fetch content for intermediate download page ${Blue}$final_apk_link${Reset}!" >&2
      return 1
    fi
    if [ -z "$final_apk_link_content" ]; then
      echo -e "$bad Error: Fetched empty content from intermediate download page ${Blue}$final_apk_link${Reset}!" >&2
      return 1
    fi
    
    # An <a> tag with an href attribute that 'contains("here")' or similar patterns.
    final_app_url="https://www.apkmirror.com$(echo "$final_apk_link_content" | pup -p --charset UTF-8 'a:contains("here") attr{href}' | head -1 2>/dev/null)"
      # https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=XXXXXXX&key=XxX 
      # https://www.androidpolice.com/2020/07/04/how-to-download-apps-without-the-play-store-and-why-apkmirror-is-the-best-place-to-get-them/
      # https://github.com/illogical-robot/apkmirror-public/issues
    if [ -z "$final_app_url" ]; then
      echo -e "$bad Error: Could not find the final download URL in the content of ${Blue}$final_apk_link${Reset} using pup!" >&2
      return 1
    else
      echo -e "$good Found final download URL: ${Blue}$final_app_url${Reset}"
    fi
  else
    echo -e "$bad Error: Could not find the final download button link on ${Blue}$Link${Reset}!" >&2
    return 1
  fi
  echo  # Space
    
  #appName="${appName//[\*\\\/:\?\|<>]/}"
  appName=$(echo "${appName%%[:—(]*}" | xargs)
  FileName="${appName}_v${VERSION}-${Arch}${file_ext}"
  outputPath="${Download}/${FileName}" 
  if [ ! -f "$Download/${appName}_v${VERSION}-${cpuAbi}.apk" ] && [ ! -f "$outputPath" ]; then
    echo -e "$running Attempting to download APK from: ${Blue}$final_app_url${Reset}"
    while true; do
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$FileName" -U "User-Agent: $USER_AGENT" -U "Referer: $final_apk_link" --async-dns=true --async-dns-server="$cloudflareIP" "$final_app_url"
      exitStatus=$?
      echo  # Space
      if [ "$exitStatus" == "0" ]; then
        echo -e "$good Download Complete with aria2. Saved to ${Cyan}$outputPath${Reset}"
        break
      else
        echo -e "$bad Download failed! retrying in 5 secons.." && sleep 5
      fi
    done
    
    sha256sum=$(sha256sum "$outputPath" | cut -d' ' -f1)
    if [ "$sha256sum" == "$SHA256" ]; then
      echo -e "$good Downloaded file appears in the original state."
    else
      echo -e "$bad Look like downloaded file appears corrupted!"
      echo -e "$notice SHA-256 SUM Diffs - Expected: ${Cyan}$SHA256${Reset} ~ Result: ${Cyan}$sha256sum${Reset}"
    fi
    echo  # Space
    
    if [ "$file_ext" == ".apkm" ]; then
      bash $Simplify/dlGitHub.sh "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
      APKEditor=$(find "$Simplify" -type f -name "APKEditor-*.jar" -print -quit)
      mkdir -p "$Download/${appName}_v${VERSION}-${cpuAbi}"
      echo -e "$running Extracting APKM content.."
      if [ -f $simplifyJson ]; then
        if [ $RipLib -eq 1 ]; then
          pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${VERSION}-${cpuAbi}/" --include "base.apk" "split_config.${cpuAbi//-/_}.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
        elif [ $RipLib -eq 0 ]; then
          pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${VERSION}-${cpuAbi}/" --include "base.apk" "split_config.arm64_v8a.apk" "split_config.armeabi_v7a.apk" "split_config.x86_64.apk" "split_config.x86.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
        fi
      else
        pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${VERSION}-${cpuAbi}/" --include "base.apk" "split_config.${cpuAbi//-/_}.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
        if [ ! -e "$Download/${appName}_v${VERSION}-${cpuAbi}/split_config.${lcd_dpi}.apk" ] || [ ! -e "$Download/${appName}_v${VERSION}-${cpuAbi}/split_config.${locale}.apk" ] || [ ! -e "$Download/${appName}_v${VERSION}-${cpuAbi}/split_config.${cpuAbi//-/_}.apk" ]; then  # check if file exists
          pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${VERSION}-${cpuAbi}/"
        fi
      fi
      rm "$outputPath"
      echo -e "$running Merge splits apkm to standalone lite apk.."
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $APKEditor m -i "$Download/${appName}_v${VERSION}-${cpuAbi}" -o "$Download/${appName}_v${VERSION}-${cpuAbi}.apk"
      rm -rf "$Download/${appName}_v${VERSION}-${cpuAbi}"
      echo
    fi
  else
    if [ "$file_ext" == ".apkm" ]; then
      echo -e "$notice Download skiped! '${appName}_v${VERSION}-${cpuAbi}.apk' already exist."
    else
      echo -e "$notice Download skiped! '${appName}_v${VERSION}-${Arch}.apk' already exist."
    fi
    echo  # Space
  fi
}
#APKMdl "com.google.android.youtube" "20.21.37" "BUNDLE" "universal"
#APKMdl "com.google.android.apps.youtube.music" "8.18.51" "APK" "$cpuAbi"
APKMdl "$@"  # call the function with arguments
#########################################################################