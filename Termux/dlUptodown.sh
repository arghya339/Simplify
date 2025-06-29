#!/usr/bin/bash

# --- Colored log indicators ---
good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

# --- ANSI Color ---
Green="\033[92m"
Red="\033[91m"
Blue="\033[94m"
skyBlue="\033[38;5;117m"
Cyan="\033[96m"
White="\033[37m"
Yellow="\033[93m"
Orange="\e[38;5;208m"
Reset="\033[0m"

# --- Global Variables ---
Simplify="$HOME/Simplify"
Download="/sdcard/Download"
cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android architecture
locale=$(getprop persist.sys.locale | cut -d'-' -f1)  # Get System Languages
# Function to get the DPI category based on density using getprop
get_dpi() {
  # Get the device screen density using 'getprop ro.sf.lcd_density'
  density=$(getprop ro.sf.lcd_density)
  # Check and categorize the density
  if [ "$density" -le 160 ]; then
    echo "mdpi"  # Medium Density
  elif [ "$density" -le 240 ]; then
    echo "hdpi"  # High Density
  elif [ "$density" -le 320 ]; then
    echo "xhdpi"  # Extra High Density
  elif [ "$density" -le 440 ]; then
    echo "xxhdpi"  # Extra Extra High Density
  elif [ "$density" -gt 440 ]; then
    echo "xxxhdpi"  # Extra Extra Extra High Density
  else
    echo "*dpi"
  fi
}
dpi=$(get_dpi)  # Get the DPI Category

dlUptodown() {
  # --- local variables ---
  local appName=$1
  local appVersion=$2
  local Type=$3
  local -n ArchRef=$4
  
  if [ "$ArchRef" == "universal" ]; then
    ArchRef=("arm64-v8a, armeabi-v7a, x86, x86_64")
  fi
  
  # --- UPTODOWN SEARCH ---
  local searchHTML
  earchHTML=$(curl -s -X POST "https://en.uptodown.com/android/en/s" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -H "X-Requested-With: XMLHttpRequest" -H "Origin: https://en.uptodown.com" \
    -H "Referer: https://en.uptodown.com/android/search" --data "q=${appName,,}")

  if echo "$searchHTML" | jq -e '.success==1 and (.data|length>0)' >/dev/null 2>&1; then
    appUrl=$(jq -r '.data[] | select(.url | test("^https://[^/]+\\.uptodown\\.com/android$")) | .url' <<<"$searchHTML" | head -n1)
    echo -e "$info appUrl: ${Blue}$appUrl${Reset}"
    echo  # white space
  fi
  
  if [ -z $appUrl ]; then
    # Fallback: build a slug-based URL (web address with human-readable keyword) ie. "Spotify Lite" → spotify-lite.en.uptodown.com/android) & check if it exists
    local slug
    slug=$(echo "$appName" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')  # Convert: uppercase → lowercase letters. Replace: Spaces with hyphen
    local appUrl="https://$slug.en.uptodown.com/android"

    if curl -s --head --fail "$appUrl" >/dev/null; then
      echo -e "$info appUrl: ${Blue}$appUrl${Reset}"
      echo  # White Space
    else
      return 1  # return error (1): if nothing worked
    fi
  fi
  
  # --- SCRAPE VERSION URL ---
  data_code=$(curl -sL "$appUrl" | grep -i "data-code" | sed -n 's/.*data-code="\([0-9]*\)".*/\1/p')  # Get app ID on Uptodown
  echo -e "$info ${appName}'s appID (data_code): $data_code"

  page=1  # Start Uptodown’s OLDER VERSIONS Page from 1
  fileID=""  # initializes variable with empty value
  while true ; do
    versions_json=$(curl -s "$appUrl/apps/$data_code/versions/$page")  # Uptodown’s OLDER VERSIONS Page Url
    # Stop if the API is out of pages
    if [ "$(jq '.data | length' <<<"$versions_json")" -eq 0 ]; then
      echo -e "$notice Version $appVersion not found!" >&2
      exit 1
    fi

    hit=$(jq -r --arg v "$appVersion" '.data[] | select(.version == $v) | [.fileID, .version, .sdkVersion, .kindFile, .versionURL] | @tsv' <<<"$versions_json")  # Check if versions page contain target appVersion
    # if $hit is non-empty, means found target appVersion then extract variables fields & break ∞ while loop
    if [ -n "$hit" ]; then
      IFS=$'\t' read -r fileID version sdkVersion kindFile versionURL <<<"$hit"
      echo -e "$info fileID (versionID)         : $fileID\n$info version                    : $version\n$info sdkVersion (minAndroid)    : $sdkVersion\n$info kindFile (fileType)        : $kindFile\n$good versionURL                 : ${Blue}$versionURL${Reset}"
      echo  # Space
      break  # brake the loop
    fi

    page=$((page + 1))  # if $hit is empty then increase Page value +1
  done

  # --- SCRAPE DOWNLOAD URL ---
  button_variants=$(curl -sL "$versionURL" | grep -oP '<button class="button variants"')  # 'ALL VARIANTS' BUTTON
  if [ -z "$button_variants" ] && [ "$kindFile" == "apk" ]; then
    data_url=$(curl -sL "$versionURL" | grep -oP 'data-url="\K[^"]+' | head -n1)
    echo -e "$info data_url: ${Cyan}$data_url${Reset}"

    dlUrl="https://dw.uptodown.com/dwn/${data_url}"
    echo -e "$info dlUrl: ${Blue}$dlUrl${Reset}"
  else
   data_version=$(curl -sL "$versionURL" | grep -oP '<button class="button variants" data-version="\K[^"]+')  # 'ALL VARIANTS' BUTTON ID
    echo -e "$info data_version (ALL VARIANTS BUTTON ID): $data_version"

    appLink=$(dirname $appUrl)  # https://app.en.uptodown.com/~~android~~
    echo -e "$info appLink: ${Blue}$appLink${Reset}"

    files_json=$(curl -sL "$appLink/app/${data_code}/version/${data_version}/files" | jq -r '.content')  # 'ALL VARIANTS' NETWORK RESPONSE HEADERS
    #echo -e "$notice files_json (ALL VARIANTS RESPONSE): $files_json"  # for debug

    versionLink=$(dirname $versionURL)  # https://app.en.uptodown.com/android/download/~~fileID~~
    echo -e "$info versionLink: ${Blue}$versionLink${Reset}"

    variant_count=$(echo "$files_json" | pup 'div.variant' | grep -c 'class="variant"')  # Count variants from 'ALL VARIANTS' Response
    echo -e "$notice Found $variant_count variants!"
    
    # if $data_version (not empty) populated then..
    if [ -n "$data_version" ]; then
      # Loops through variant for print all list of variant info
      for ((n = 1; n <=variant_count; n += 1)); do
        arch=$(pup ".content > p:nth-child($n) text{}" <<<"$files_json" | xargs)  # Get variant arch(arm64-v8a) form 'ALL VARIANTS' Response
        type=$(pup "div.variant:nth-child($((n + 1))) div.v-file span text{}" <<<"$files_json" | xargs)  # Get variant type(xapk/apk) form 'ALL VARIANTS' Response
        data_file_id=$(pup "div.variant:nth-child($((n + 1))) > .v-report attr{data-file-id}" <<<"$files_json")  # Get variant ID form 'ALL VARIANTS' Response
        echo -e "[$n] ${Blue}arch: $arch | type: $type | file_id: $data_file_id${Reset}"
      done
      # Loops through variant for extract location Url of target Arch & Type
      for ((n = 1; n <=variant_count; n += 1)); do
        arch=$(pup ".content > p:nth-child($n) text{}" <<<"$files_json" | xargs)
        type=$(pup "div.variant:nth-child($((n + 1))) div.v-file span text{}" <<<"$files_json" | xargs)
        if [ "${ArchRef[0]}" == "$arch" ] && [ "$Type" == "$type" ]; then
          data_file_id=$(pup "div.variant:nth-child($((n + 1))) > .v-report attr{data-file-id}" <<<"$files_json")
          location_url="$versionLink/${data_file_id}-x"
          data_url=$(curl -sL "$location_url" | grep -oP 'data-url="\K[^"]+' | head -n1)
          dlUrl="https://dw.uptodown.com/dwn/${data_url}"
          echo -e "$info Auto Selected: [$n]"
          echo "arch     : $arch"
          echo "type     : $type"
          echo "file_id  : $data_file_id"
          echo -e "file_url : ${Blue}$location_url${Reset}"
          echo -e "data_url : ${Cyan}$data_url${Reset}"
          echo -e "dlUrl    : ${Blue}$dlUrl${Blue}"
          break  # break loop if found taget Arch & Type
        fi
      done
    fi
  fi
  echo  # White Space
  
  # --- Extract app info ---
  if [ "$kindFile" == "apk" ]; then
    local raw_info=$(curl -s -L "$versionLink")  # Get raw info
  else
    local raw_info=$(curl -s -L "$location_url")
  fi
  
  # Extract each field individually
  local package_name=$(echo "$raw_info" | grep -A1 "Package Name" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local size=$(echo "$raw_info" | grep -A1 "Size" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local downloads=$(echo "$raw_info" | grep -A1 "Downloads" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local file_type=$(echo "$raw_info" | grep -A1 "File type" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local architecture=$(echo "$raw_info" | grep -A1 "Architecture" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local sha256=$(echo "$raw_info" | grep -A1 "SHA256" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local requirements=$(echo "$raw_info" | awk '/<th[^>]*>Requirements<\/th>/{flag=1;next} flag && /<li>/{gsub(/.*<li>|<\/li>.*/,"");print;exit}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Print app info
  echo -e "${info} pkgName   : ${Reset}${package_name:-N/A}"
  echo -e "${info} fileSize  : ${Reset}${size:-N/A}"
  echo -e "${info} Downloads : ${Reset}${downloads:-N/A}"
  echo -e "${info} fileType  : ${Reset}${file_type:-N/A}"
  echo -e "${info} reqArch   : ${Reset}${architecture:-N/A}"
  echo -e "${info} fileSHA256: ${Reset}${sha256:-N/A}"
  echo -e "${info} reqOS     : ${Reset}${requirements:-N/A}\n"
  
  # Set varible for later use the sh
  pkgName="${package_name:-N/A}"
  Type="${file_type:-N/A}"
  Arch="${architecture:-N/A}"
  SHA256="${sha256:-N/A}"
  
  # --- DOWNLOAD FILE USING ARIA2 ---
  if [ "$Type" == "XAPK" ]; then
    file_ext="apks"
  else
    file_ext="apk"
  fi
  
  if [ ! -f "$Download/${appName}_v${appVersion}-$cpuAbi.apk" ] || [ ! -f "$Download/${appName}_v${appVersion}-$Arch.apks" ]; then
    echo -e "$running Downloading.."
    aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "${appName}_v${appVersion}-$Arch.$file_ext" -d "$Download" "$dlUrl"
    dlStatus=$?
    echo  # White Space
    outputPath="$Download/${appName}_v${appVersion}-$Arch.$file_ext"
    if [ $dlStatus == 0 ]; then
      echo -e "$good Download complete. file saved to ${Cyan}$outputPath${Reset}"
    fi
  
    sha256sum=$(sha256sum "$outputPath" | cut -d' ' -f1)
    if [ "$sha256sum" == "$SHA256" ]; then
      echo -e "$good Downloaded file appears in the original state."
    else
      echo -e "$notice Look like downloaded file appears corrupted!"
    fi
    echo  # Space

    if [ $file_ext == apks ]; then
      bash $Simplify/dlGitHub.sh "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
      APKEditor=$(find "$HOME/Simplify" -type f -name "APKEditor-*.jar" -print -quit)
      mkdir -p "/sdcard/Download/${appName}_v${appVersion}-${cpuAbi}"
      echo -e "$running Extracting APKS content.."
      pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${appVersion}-${cpuAbi}/" --include "$pkgName.apk" "config.${cpuAbi//-/_}.apk" "config.${locale}.apk" "config.$dpi.apk"
      rm "$outputPath"
      echo -e "$running Merge splits apks to standalone lite apk.."
      $PREFIX/lib/jvm/java-21-openjdk/bin/java -jar $APKEditor m -i "$Download/${appName}_v${appVersion}-${cpuAbi}" -o "$Download/${appName}_v${appVersion}-${cpuAbi}.apk"
      rm -rf "$Download/${appName}_v${appVersion}-${cpuAbi}"
    fi
    echo  # White Space
  else
    if [ "$Type" == "APK" ]; then
      echo -e "$notice Download skiped! '${appName}_v${appVersion}-${Arch}.apk' already exist."
    else
      echo -e "$notice Download skiped! '${appName}_v${appVersion}-${cpuAbi}.apk' already exist."
    fi
    echo  # Space
  fi
}

#Arch=("universal")
#dlUptodown "Spotify" "8.6.98.900" "apk" "Arch"
#dlUptodown "Spotify" "9.0.28.630" "apk" "Arch"
#dlUptodown.sh "Spotify" "8.6.98.900" "apk" "Arch"

dlUptodown "$@"  # call the function with arguments
###################################################