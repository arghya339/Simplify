#!/bin/bash

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

# --- Global variables ---
milestone=$(curl -sL "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Android&num=1" | jq -r '.[0].milestone') || milestone=140; milestone=${milestone:-"140"}
USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${milestone}.0.0.0 Mobile Safari/537.36"  # HTML User Agent: chrome://version/
CONTENT_TYPE="application/octet-stream"  # octet-stream = binary data being sent
ACCEPT_LANGUAGE="en-US,en;q=0.9"  # client language prefers US-English with 90% quality rating
CONNECTION="keep-alive"  # requests to keep TCP connection open for multiple requests
UPGRADE_INSECURE_REQUESTS="1"  # client prefers HTTPS connections over HTTP
CACHE_CONTROL="max-age=0"  # tells intermediaries not to use cached versions, forces fresh request
ACCEPT="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"  # Accept header: Specifies what content types the client can handle, with quality preferences
ALL_HEADER=(
  --header="User-Agent: $USER_AGENT"
  --header="Content-Type: $CONTENT_TYPE"
  --header="Accept-Language: $ACCEPT_LANGUAGE"
  --header="Connection: $CONNECTION"
  --header="Upgrade-Insecure-Requests: $UPGRADE_INSECURE_REQUESTS"
  --header="Cache-Control: $CACHE_CONTROL"
  --header="Accept: $ACCEPT"
)

cloudflareIP="1.1.1.1,1.0.0.1"  # Cloudflare DNS-over-TLS
Download="/sdcard/Download"  # Download directory
Simplify="$HOME/Simplify"
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
  cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
else  
  cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android architecture
fi
if jq -e '.openjdk != null' "$simplifyJson" >/dev/null 2>&1; then
  jdkVersion=$(jq -r '.openjdk' "$simplifyJson" 2>/dev/null)  # Get openjdk value (verison) from json
else
  jdkVersion="21"
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
  echo -e "$notice RipLocale Disabled!"
fi
if [ $RipDpi -eq 1 ]; then
  density=$(getprop ro.sf.lcd_density)  # Get the device screen density
  # Check and categorize the density
  if [ "$density" -le "120" ]; then
    dpi="ldpi"  # Low Density
  elif [ "$density" -le "160" ]; then
    dpi="mdpi"  # Medium Density
  elif [ "$density" -le "213" ]; then
    dpi="tvdpi"  # TV Density
  elif [ "$density" -le "240" ]; then
    dpi="hdpi"  # High Density
  elif [ "$density" -le "320" ]; then
    dpi="xhdpi"  # Extra High Density
  elif [ "$density" -le "480" ]; then
    dpi="xxhdpi"  # Extra Extra High Density
  elif [ "$density" -gt "480" ] || [ "$density" -ge "640" ]; then
    dpi="xxxhdpi"  # Extra Extra Extra High Density
  else
    dpi="*dpi"
  fi
elif [ $RipDpi -eq 0 ]; then
  dpi="*dpi"
  echo -e "$notice RipDpi Disabled!"
fi

#######################
appName="${1}"  # actual appName on APKPure
pkgName="$2"  # if this optional parameter is provided, this script can more accurately find appUrl
targetVersion="$3"  # define Target Version to download it
targetVersionCode="$4"  # Target Version Code (optional), required only if version page has multiple variants
#######################

app_name=$(echo "$appName" | tr '[:upper:]' '[:lower:]' | sed 's/ /+/g')  # Convert appName into lower+case letters with replace space with + | YouTube → youtube | YouTube Music → youtube+music

# --- APKPure Search ---
# aria2c docs: https://aria2.github.io/manual/en/html/aria2c.html#options
# --connect-timeout=30 = sets a 30-seconds timeout for entire html page scraping operation
if [ -n "$pkgName" ]; then
  apiUrl="https://apkpure.com/api/v1/search_suggestion_new?key=${app_name}&limit=20"
  aria2c -q -o response.json "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --check-certificate=false --referer="https://apkpure.com" --async-dns=true --async-dns-server="$cloudflareIP" "$apiUrl"
  appUrl=$(jq -r --arg pkgName "$pkgName" '.[] | select(.packageName? == $pkgName) | .fullUrl' response.json) && rm -f response.json || { rm -f response.json; appUrl=""; }
  [ "$appUrl" == "null" ] && appUrl=""
else
  appUrl=""
fi
if [ -z "$appUrl" ]; then
  searchUrl="https://apkpure.com/search?q=$app_name"  # APKPure search url pattern
  aria2c -q -o apkpure_page.html -d "$HOME" "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --check-certificate=false --referer="https://apkpure.com" --async-dns=true --async-dns-server="$cloudflareIP" "$searchUrl" && search_html_content=$(cat "$HOME/apkpure_page.html") && rm -f ~/apkpure_page.html
  #echo "$search_html_content" > ~/apkpure_page.html  # for debug
  appUrl=$(pup 'div.first-info.brand-info json{}' <<< "$search_html_content" | jq -r '{name: .[0].children[1].children[0].children[0].text, url: .[0].children[0].href} | .url')
  [ "$appUrl" == "null" ] && appUrl=""
  [ -z "$appUrl" ] && appUrl=$(pup '#search-app-list li:first-child a attr{href}' <<< "$search_html_content")  # extract first result from search-app-list
fi
echo -e "$info appUrl: ${Blue}$appUrl${Reset}\n"

AllVersions="$appUrl/versions"  # APKPure app versions page url pattern

# --- Get list of all app version with url ---
aria2c -q -o apkpure_page.html -d "$HOME" "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --load-cookies=cookies.txt --check-certificate=false --referer="$appUrl" --async-dns=true --async-dns-server="$cloudflareIP" "$AllVersions" && all_version_html_content=$(cat "$HOME/apkpure_page.html") && rm -f ~/apkpure_page.html
#echo "$all_version_html_content" > ~/apkpure_page.html  # for debug
# get version + versioCode + url + variant + size list in json from
all_version_url_list=$(pup 'ul.ver-wrap li json{}' <<< "$all_version_html_content" | jq -r '.[] | select(.children[0].tag == "a") | {version: (.children[0]."data-dt-version" // ""), url: (.children[0].href // ""), versioncode: (.children[0]."data-dt-versioncode" // ""), variant: (.children[0]."data-dt-variant" // ""), size: (.children[0].children[]? | select(.tag=="div" and .class=="ver-item") | .children[]? | select(.tag=="div" and .class=="ver-item-info") | .children[]? | select(.tag=="span" and .class=="ver-item-s") | .text // "")}' | jq -s .)  # li:not(.ver_item_hidden) = filtering out hidden versions

#echo -e "$notice DEBUG - all_version_url_list: $all_version_url_list\n"  # for debug
all_version_list=$(jq -r '.[].version' <<< "$all_version_url_list")
#echo -e "all_version_list:\n$all_version_list\n"  # for debug
versionUrl=$(echo "$all_version_url_list" | jq -r --arg ver "$targetVersion" '.[] | select(.version == $ver) | .url' 2>/dev/null)
variant=$(echo "$all_version_url_list" | jq -r --arg ver "$targetVersion" '.[] | select(.version == $ver) | .variant' 2>/dev/null)
size=$(echo "$all_version_url_list" | jq -r --arg ver "$targetVersion" '.[] | select(.version == $ver) | .size' 2>/dev/null)
# echo -e "$notice variant: $variant, size: $size\n"  # for debug

if [[ -n "$versionUrl" && "$versionUrl" != "null" ]]; then
  echo -e "$info versionUrl: ${Blue}$versionUrl${Reset}\n"
else
  versionUrl="$appUrl/download/$targetVersion"  # build custom version url pattern
  aria2c -q -o apkpure_page.html -d "$HOME" "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --load-cookies=cookies.txt --check-certificate=false --referer="$appUrl" --async-dns=true --async-dns-server="$cloudflareIP" "$versionUrl"
  if grep -q "Free Online APK Downloader" "$HOME/apkpure_page.html" 2>/dev/null; then
    echo -e "$bad Target version $targetVersion not found!"
    echo -e "$notice Available Version:\n$all_verison_list"
    rm -f "$HOME/apkpure_page.html"; rm -f cookies.txt; exit 1
  fi
  rm -f ~/apkpure_page.html
fi

# --- Extract real APK Download link from version page ---
if [ "$variant" == "true" ]; then
  # if variant is true means has multiple variant in target version page so need to select secific variant to download it
  aria2c -q -o apkpure_page.html -d "$HOME" "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --load-cookies=cookies.txt --check-certificate=false --referer="$AllVersions" --async-dns=true --async-dns-server="$cloudflareIP" "$versionUrl" && version_html_content=$(cat "$HOME/apkpure_page.html") && rm -f ~/apkpure_page.html
  #echo "$version_html_content" > ~/apkpure_page.html  # for debug
  pkgName=$(pup 'div.info.pkg-name-info a.value text{}' <<< "$version_html_content")
  #echo -e "$notice pkgName: $pkgName"  # for debug
  variants_list_html_content=$(pup 'div.apk json{}' <<< "$version_html_content" | jq -r '.[] | {version: (.children[] | select(.class? == "info")?.children[]? | select(.class? == "info-top")?.children[]? | select(.class? == "name one-line")?.text?), versionCode: (.children[] | select(.class? == "info")?.children[]? | select(.class? == "info-top")?.children[]? | select(.class? == "code one-line")?.text? | gsub("[()]"; "")), fileType: (.children[] | select(.class? == "info")?.children[]? | select(.class? == "info-top")?.children[]? | select(.class? == "tag one-line")?.text?), downloadUrl: (.children[] | select(.class? == "download-btn")?.href?), size: (.children[] | select(.class? == "info")?.children[]? | select(.class? == "info-bottom one-line")?.children[]? | select(.class? == "size")?.text?), minAndroid: (.children[] | select(.class? == "info")?.children[]? | select(.class? == "info-bottom one-line")?.children[]? | select(.class? == "sdk")?.text?), SHA1: (.children[] | select(.class? == "info")?."data-dialog"? | sub("^variant-"; ""))}')
  FileSHA1=$(echo "$variants_list_html_content" | jq -s -r --arg ver "$targetVersionCode" '.[] | select((.versionCode | tostring | gsub("\\s";"")) == $ver) | .SHA1' | head -1)
  #echo -e "$notice FileSHA1: $FileSHA1\n"  # for debug
  type=$(echo "$variants_list_html_content" | jq -s -r --arg ver "$targetVersionCode" '.[] | select((.versionCode | tostring | gsub("\\s";"")) == $ver) | .fileType' | head -1)
  #echo -e "$notice fileType: $type\n"  # for debug
  [ "$type" == "APK" ] && ext="apk" || ext="apks"
  dlUrl=$(echo "$variants_list_html_content" | jq -s -r --arg ver "$targetVersionCode" '.[] | select((.versionCode | tostring | gsub("\\s";"")) == $ver) | .downloadUrl' | head -1)  # -s = stream of objects into a single array
else
  aria2c -q -o apkpure_page.html -d "$HOME" "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --load-cookies=cookies.txt --check-certificate=false --referer="$AllVersions" --async-dns=true --async-dns-server="$cloudflareIP" "$versionUrl" && version_html_content=$(cat "$HOME/apkpure_page.html") && rm -f ~/apkpure_page.html
  #echo "$version_html_content" > ~/apkpure_page.html  # for debug
  pkgName=$(pup 'div.info.pkg-name-info a.value text{}' <<< "$version_html_content")
  #echo -e "$notice pkgName: $pkgName"  # for debug
  versionCode=$(pup 'div.apk json{}' <<< "$version_html_content" | jq -r '.. | objects | select(.class? == "code one-line") | .text | select(. != null) | gsub("[()]"; "")') #&& targetVersionCode="$versionCode" ;echo -e "$notice versionCode: $targetVersionCode\n"  # for debug
  type=$(pup 'div.apk json{}' <<< "$version_html_content" | jq -r '.. | objects | select(.class? == "tag one-line") | .text | select(. != null) | gsub("[()]"; "")')
  #echo -e "$notice fileType: $type\n"  # for debug
  [ "$type" == "APK" ] && ext="apk" || ext="apks"
  #variants_desc=$(pup 'div.apk json{}' <<< "$version_html_content" | jq -r '.. | objects | select(.class? == "label" or .class? == "value") | {class: .class, text: .text}')  # variants description
  #echo -e "$notice variants_desc: $variants_desc\n"  # for debug
  FileSHA1=$(pup 'div.apk json{}' <<< "$version_html_content" | jq -r '[.. | objects | select(.class? == "label" or .class? == "value")] | reduce .[] as $item ({last_label: null, result: null}; if $item.class == "label" then .last_label = $item.text else if .last_label == "File SHA1" then .result = $item.text else . end end) | .result')
  #echo -e "$notice FileSHA1: $FileSHA1\n"  # for debug
  dlUrl=$(pup 'a#download_link attr{href}' <<< $version_html_content)
fi
echo -e "$info dlUrl: ${Blue}$dlUrl${Reset}\n"

[ -n "$targetVersionCode" ] && { fileName="${appName}_v$targetVersion-$targetVersionCode.$ext"; dirName="${appName}_v$targetVersion-$targetVersionCode"; } || { fileName="${appName}_v$targetVersion.$ext"; dirName="${appName}_v$targetVersion"; }  # Download apk file name pattern
output="$Download/$fileName"

if [ ! -f "$Download/$dirName.apk" ]; then
  # --- Download APK with the same headers ---
  if [ -n "$dlUrl" ]; then
    echo -e "$running Downloading $appName.."
    while true; do
      aria2c  -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --load-cookies=cookies.txt --check-certificate=false --referer="$versionUrl" --async-dns=true  --async-dns-server="$cloudflareIP" "$dlUrl"
      [ $? -eq 0 ] && { rm -f cookies.txt; echo -e "\n$good ${Green}Download complete:${Reset} ${Cyan}$output${Reset}"; break; } || { echo -e "$bad Download failed! retrying in 5 secons.."; sleep 5; }
    done
  else
    echo -e "$bad Could not find APK Download link!"
    exit 1
  fi
  [ "$FileSHA1" == "$(sha1sum "$output" | cut -d' ' -f1)" ] && echo -e "$good Downloaded file appears in the original state.\n" || echo -e "$notice Look like downloaded file appears corrupted!"
  
  # --- Merge splits apks to standalone apk ---
  if [ "$ext" == "apks" ]; then
    bash $Simplify/dlGitHub.sh "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
    APKEditor=$(find "$HOME/Simplify" -type f -name "APKEditor-*.jar" -print -quit)
    mkdir -p "$Download/${dirName}"
    echo -e "$running Extracting APKS content.."
    termux-wake-lock
    if [ -f $simplifyJson ]; then
      if [ $RipLib -eq 1 ]; then
        pv "$output" | bsdtar -xf - -C "$Download/${dirName}/" --include "$pkgName.apk" "config.${cpuAbi//-/_}.apk" "config.${locale}.apk" "config.${dpi}.apk"
        bsdtar_exit_code=$?
      elif [ $RipLib -eq 0 ]; then
        pv "$output" | bsdtar -xf - -C "$Download/${dirName}/" --include "$pkgName.apk" "config.arm64_v8a.apk" "config.armeabi_v7a.apk" "config.x86_64.apk" "config.x86.apk" "config.${locale}.apk" "config.${dpi}.apk"
        bsdtar_exit_code=$?
      fi
    else
      pv "$output" | bsdtar -xf - -C "$Download/${dirName}/" --include "$pkgName.apk" "config.${cpuAbi//-/_}.apk" "config.${locale}.apk" "config.${dpi}.apk"
      bsdtar_exit_code=$?
    fi
    if [ $bsdtar_exit_code -ne 0 ]; then  # check if bsdtar return exit code 1 (error)
      pv "$output" | bsdtar -xf - -C "$Download/${dirName}/"
    fi
    rm "$output"
    echo -e "$running Merge splits apks to standalone lite apk.."
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $APKEditor m -i "$Download/${dirName}" -o "$Download/${dirName}.apk"
    termux-wake-unlock
    rm -rf "$Download/${dirName}"
  fi
else
  echo -e "$notice Download skiped! '${dirName}.apk' already exist."
fi
###############################################################################################################################