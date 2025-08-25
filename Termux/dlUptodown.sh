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
Download="/sdcard/Download"  # Download dir
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
    dpi="ldpi"  # Low Density
  elif [ "$density" -le 160 ]; then
    dpi="mdpi"  # Medium Density
  elif [ "$density" -le 240 ]; then
    dpi="hdpi"  # High Density
  elif [ "$density" -le 320 ]; then
    dpi="xhdpi"  # Extra High Density
  elif [ "$density" -le 480 ]; then
    dpi="xxhdpi"  # Extra Extra High Density
  elif [ "$density" -gt 480 ] || [ "$density" -ge 640 ]; then
    dpi="xxxhdpi"  # Extra Extra Extra High Density
  else
    dpi="*dpi"
  fi
elif [ $RipDpi -eq 0 ]; then
  dpi="*dpi"
fi

dlUptodown() {
  # --- local variables ---
  local appName=$1
  local appVersion=$2
  local Type=$3
  local Arch=$4
  
  if [ "$Arch" == "universal" ]; then
    Arch=("arm64-v8a,armeabi-v7a,x86,x86_64")
  fi
  
  universal=("arm64-v8a, armeabi-v7a, x86, x86_64")
  # Normalize Arch string
  Arch=$(echo "$Arch" | tr -d ' ')  # rm spaces
  
  # --- UPTODOWN SEARCH ---
  # Build a slug-based URL (web address with human-readable keyword) ie. "Spotify Lite" → spotify-lite.en.uptodown.com/android) & check if it exists
  local slug
  slug=$(echo "$appName" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')  # Convert: uppercase → lowercase letters. Replace: Spaces with hyphen
  local appUrl="https://$slug.en.uptodown.com/android"
  
  if curl -s --head --fail "$appUrl" >/dev/null; then
    actualAppName=$(curl -sL "$appUrl" | pup 'h1#detail-app-name json{}' | jq -r '.[0].text' | xargs)
    echo -e "$info actualAppName: $actualAppName"
    echo -e "$info appUrl: ${Blue}$appUrl${Reset}"
    echo  # White Space
  else
    echo -e "$notice ${Red}404 Whoops!${Reset} The requested URL ${Blue}$appUrl${Reset} could not be found."
    exit 1
  fi
  
  # --- SCRAPE VERSION URL ---
  data_code=$(curl -sL "$appUrl" | grep -i "data-code" | sed -n 's/.*data-code="\([0-9]*\)".*/\1/p')  # Get app ID on Uptodown
  echo -e "$info ${appName}'s appID (data_code): $data_code"
  
  if [ $data_code ]; then
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
  fi
  
  # --- SCRAPE DOWNLOAD URL ---
  data_version=$(curl -sL "$versionURL" | grep -oP '<button class="button variants" data-version="\K[^"]+')  # 'ALL VARIANTS' BUTTON ID
  if [ -z "$data_version" ]; then
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
        arch=$(pup "div.content > p:nth-of-type($n) text{}" <<<"$files_json" | xargs)  # Get variant arch(arm64-v8a) form 'ALL VARIANTS' Response
        type=$(pup "div.variant:nth-of-type($n) div.v-file span text{}" <<<"$files_json" | xargs)  # Get variant type(xapk/apk) form 'ALL VARIANTS' Response
        data_file_id=$(pup "div.variant:nth-of-type($n) > .v-report attr{data-file-id}" <<<"$files_json")  # Get variant ID form 'ALL VARIANTS' Response
        echo -e "[$n] ${Blue}arch: $arch | type: $type | file_id: $data_file_id${Reset}"
      done
      # Loops through variant for extract location Url of target Arch & Type
      for ((n = 1; n <=variant_count; n += 1)); do
        arch=$(pup "div.content > p:nth-of-type($n) text{}" <<<"$files_json" | xargs)
        type=$(pup "div.variant:nth-of-type($n) div.v-file span text{}" <<<"$files_json" | xargs)
        # Normalize arch string: remove spaces
        arch_clean=$(echo "$arch" | tr -d ' ')
        if [ "$Arch" == "$arch_clean" ] && [ "$Type" == "$type" ]; then
          data_file_id=$(pup "div.variant:nth-of-type($n) > .v-report attr{data-file-id}" <<<"$files_json")
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
  if [ -z "$data_version" ]; then
    local raw_info=$(curl -s -L "$versionURL")  # Get raw info
  else
    local raw_info=$(curl -s -L "$location_url")
  fi
  
  # Extract each field individually
  local version=$(echo "$raw_info" | pup 'div.version json{}' | jq -r '.[0].text')
  local package_name=$(echo "$raw_info" | grep -A1 "Package Name" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local size=$(echo "$raw_info" | grep -A1 "Size" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local downloads=$(echo "$raw_info" | grep -A1 "Downloads" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local file_type=$(echo "$raw_info" | grep -A1 "File type" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local architecture=$(echo "$raw_info" | grep -A1 "Architecture" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local sha256=$(echo "$raw_info" | grep -A1 "SHA256" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  local requirements=$(echo "$raw_info" | awk '/<th[^>]*>Requirements<\/th>/{flag=1;next} flag && /<li>/{gsub(/.*<li>|<\/li>.*/,"");print;exit}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Print app info
  echo -e "Information about $actualAppName $version"
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
  SHA256="${sha256:-N/A}"
  
  if [ -z "$data_version" ]; then
    Arch="${architecture:-N/A}"
  else
    Arch="$arch"
  fi

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
      mkdir -p "$Download/${appName}_v${appVersion}-${cpuAbi}"
      echo -e "$running Extracting APKS content.."
      if [ -f $simplifyJson ]; then
        if [ $RipLib -eq 1 ]; then
          pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${appVersion}-${cpuAbi}/" --include "$pkgName.apk" "config.${cpuAbi//-/_}.apk" "config.${locale}.apk" "config.${dpi}.apk"
        elif [ $RipLib -eq 0 ]; then
          pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${appVersion}-${cpuAbi}/" --include "$pkgName.apk" "config.arm64_v8a.apk" "config.armeabi_v7a.apk" "config.x86_64.apk" "config.x86.apk" "config.${locale}.apk" "config.${dpi}.apk"
        fi
      else
        pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${appVersion}-${cpuAbi}/" --include "$pkgName.apk" "config.${cpuAbi//-/_}.apk" "config.${locale}.apk" "config.${dpi}.apk"
        if [ ! -e "$Download/${appName}_v${appVersion}-${cpuAbi}/config.${dpi}.apk" ] || [ ! -e "$Download/${appName}_v${VERSION}-${cpuAbi}/config.${locale}.apk" ] || [ ! -e "$Download/${appName}_v${VERSION}-${cpuAbi}/config.${cpuAbi//-/_}.apk" ]; then  # check if file exists
          pv "$outputPath" | bsdtar -xf - -C "$Download/${appName}_v${appVersion}-${cpuAbi}/"
        fi
      fi
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

#Arch=("arm64-v8a")
#dlUptodown "Adobe Lightroom Mobile" "10.0.2" "apk" "Arch"

#Arch=("arm64-v8a, armeabi-v7a, x86, x86_64")
#dlUptodown "Spotify" "8.6.98.900" "apk" "Arch"
#dlUptodown "Spotify" "9.0.28.630" "apk" "Arch"

#dlUptodown.sh "Spotify" "8.6.98.900" "apk" "Arch"

dlUptodown "$@"  # call the function with arguments
###################################################