#!/usr/bin/bash

# Colored log indicators
good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

# ANSI Color
Green="\033[92m"
Red="\033[91m"
Blue="\033[94m"
Cyan="\033[96m"
White="\033[37m"
Yellow="\033[93m"
Reset="\033[0m"

simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
if [ -f "$HOME/.config/gh/hosts.yml" ] && gh auth status > /dev/null 2>&1; then
  # oauth_token: gho_************************************
  token=$(grep -A2 "users:" ~/.config/gh/hosts.yml | grep -v "users:" | grep -A1 "oauth_token:" | awk '/oauth_token:/ {getline; print $2}')
  auth="-H \"Authorization: Bearer $token\""
elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
  # PAT: ghp_************************************
  token=$(jq -r '.PAT' "$simplifyJson" 2>/dev/null)
  auth="-H \"Authorization: Bearer $token\""
else
  auth=""
fi

# --- Download required file from GitHub ---
dlGitHub() {
  local owner=$1
  local repo=$2
  local releases=$3
  local ext=$4
  local dir=$5
  local assets=$6
  
  if [ -n "$assets" ]; then
    regex="$assets"
  elif [ -n "$ext" ] && [ -z "$assets" ]; then
    regex=".*\\${ext}$"  # Simplified regex pattern
  fi

  dl() {
    local dlUtility=$1
    local url=$2
    local output=$3
    
    assets_name=$(basename "$output")
    echo -e "$running Downloading $assets_name.."
    
    while true; do
      if [ "$dlUtility" == "curl" ]; then
        curl -L -C - --progress-bar -o "$output" "$url"
        exit_status=$?
      elif [ "$dlUtility" == "aria2" ]; then
        aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$(basename "$output")" -d "$(dirname "$output")" "$url"
        exit_status=$?
        echo  # White Space
      fi
      if [ $exit_status -eq 0 ]; then
        break  # Exit loop on success
      else
        echo -e "${bad} ${Red}Download failed! retrying in 5 seconds..${Reset}"
        sleep 5  # Wait 5 seconds
      fi
    done
  }

  if [ "$releases" == "latest" ]; then
    if [ "$repo" == "APKEditor" ]; then
      latestReleases=$(curl -s ${auth} https://api.github.com/repos/$owner/$repo/releases/latest | jq -r '.tag_name | sub("^V"; "")')  # 1.4.3
      echo -e "$info latestReleases: V$latestReleases"
    elif [ "$repo" == "FreeTubeAndroid" ] || [ "$repo" == "bundletool" ] || [ "$repo" == "twitter-apk" ] || [ "$repo" == "lawnchair" ] || [ "$repo" == "Nagram" ]; then
      latestReleases=$(curl -s ${auth} https://api.github.com/repos/$owner/$repo/releases/latest | jq -r '.tag_name')  # 0.23.5.17
      echo -e "$info latestReleases: $latestReleases"
    else
      latestReleases=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name | sub("^v"; "")' 2>/dev/null)
      if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
        echo -e "$info latestReleases: $latestReleases"
      else
        echo -e "$info latestReleases: v$latestReleases"
      fi
    fi
    if [ "$repo" == "VancedMicroG" ] || [ "$repo" == "LSPatch" ] || [ "$repo" == "YTPro" ] || [ "$repo" == "cloudstream" ]; then
      assetsName=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name' 2>/dev/null)
      if [ "$repo" == "cloudstream" ]; then
        fileName="$repo-${latestReleases}$regex"
      else
        assetsNameWithoutExt="${assetsName%.*}"
        fileName="$assetsNameWithoutExt-${latestReleases}$ext"
      fi
      echo -e "$info assetsName: $fileName"
      assetsNamePattern=$(echo "$fileName" | sed "s/$latestReleases/*/g")
    elif [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
      assetsName="$assets"
      echo -e "$info assetsName: $assetsName"
    else
      assetsName=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name' 2>/dev/null)
      echo -e "$info assetsName: $assetsName"
      if [ "$repo" == "Nagram" ]; then
        name=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.name')
        assetsNamePattern=$(echo "$assetsName" | sed "s/$name/*/g")
      else
        assetsNamePattern=$(echo "$assetsName" | sed "s/$latestReleases/*/g")
      fi
    fi
    
    if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
      findFile="$dir/$assetsName"
      fileBaseName=$(basename $findFile)
    else
      findFile=$(find "$dir" -type f -name "$assetsNamePattern" -print -quit)
      fileBaseName=$(basename $findFile)
    fi
    
    if [ "$repo" == "VancedMicroG" ] || [ "$repo" == "LSPatch" ] || [ "$repo" == "YTPro" ] || [ "$repo" == "cloudstream" ]; then
      if [ "$fileName" != "$fileBaseName" ]; then
        echo -e "$notice diffs: $fileName ~ $fileBaseName"
        [ -f "$findFile" ] && rm "$findFile"
        dlUrl="https://github.com/$owner/$repo/releases/download/v${latestReleases}/$assetsName"
        findFile="$dir/$fileName"
        if [ "$repo" == "cloudstream" ]; then
          dl "aria2" "$dlUrl" "$findFile"
        else
          dl "curl" "$dlUrl" "$findFile"
        fi
      fi
    elif [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ] || [ "$repo" == "FreeTubeAndroid" ] || [ "$repo" == "bundletool" ] || [ "$repo" == "twitter-apk" ] || [ "$repo" == "lawnchair" ] || [ "$repo" == "Nagram" ]; then
      [ -f "$findFile" ] && rm "$findFile"
      dlUrl="https://github.com/$owner/$repo/releases/download/${latestReleases}/$assetsName"
      findFile="$dir/$assetsName"
      if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ] || [ "$repo" == "bundletool" ] || [ "$repo" == "twitter-apk" ] || [ "$repo" == "Nagram" ]; then
        dl "aria2" "$dlUrl" "$findFile"
      else
        dl "curl" "$dlUrl" "$findFile"
      fi
    else 
      if [ "$assetsName" != "$fileBaseName" ]; then
        echo -e "$notice diffs: $assetsName ~ $fileBaseName"
        [ -f "$findFile" ] && rm "$findFile"
        # downloading assets
        findFile="$dir/$assetsName"
        if [ "$repo" == "APKEditor" ]; then
          dlUrl="https://github.com/$owner/$repo/releases/download/V${latestReleases}/$assetsName"
          dl "curl" "$dlUrl" "$findFile"
        else
          dlUrl="https://github.com/$owner/$repo/releases/download/v${latestReleases}/$assetsName"
          if [ "$repo" == "revanced-cli" ] || { [ "$repo" == "revanced-patches" ] && { [ "$owner" == "inotia00" ] || [ "$owner" == "anddea" ]; }; } || [ "$repo" == "Nekogram" ]; then
            dl "aria2" "$dlUrl" "$findFile"
          else
            dl "curl" "$dlUrl" "$findFile"
          fi
        fi
      fi
    fi
    echo -e "$info findFile: ${Cyan}$findFile${Reset}"
  else
    if [ "$repo" == "Seal" ]; then
      lastPreReleases=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r '.[].tag_name | sub("^v"; "") | select(contains("alpha"))' | head -n 1 2>/dev/null)
    elif [ "$repo" == "ytdlnis" ]; then
      lastPreReleases=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r '.[].tag_name | sub("^v"; "") | select(contains("beta"))' | head -n 1 2>/dev/null)
    elif [ "$repo" != "lawnchair" ] || [ "$repo" != "lawnicons" ] || [ "$repo" != "spotube" ]; then
      lastPreReleases=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r '.[].tag_name | sub("^v"; "") | select(contains("dev"))' | head -n 1 2>/dev/null)
    fi
    if [ -n "$lastPreReleases" ]; then
      echo -e "$info lastPreReleases: $lastPreReleases"
    fi
    
    # fetch assets from specific release tag
    if [ "$releases" == "nightly" ] || [ "$releases" == "pre-release" ]; then
      preAssetsName=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/tags/$releases" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name' 2>/dev/null)
    else
      preAssetsName=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/tags/v$lastPreReleases" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name' 2>/dev/null)
    fi
    if [ -z "$preAssetsName" ]; then
      if [ "$releases" == "nightly" ] || [ "$releases" == "pre-release" ]; then
        preAssetsName=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/tags/$releases" | jq -r --arg ext "$ext" '.assets[] | select(.name | endswith($ext)) | .name' 2>/dev/null)
      else
        preAssetsName=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/tags/v$lastPreReleases" | jq -r --arg ext "$ext" '.assets[] | select(.name | endswith($ext)) | .name' 2>/dev/null)
      fi
    fi
    echo -e "$info preAssetsName: $preAssetsName"
    
    if [ "$repo" == "lawnchair" ]; then
      preAssetsNamePattern="Lawnchair.Debug.*-dev.Nightly-CI_*.apk"
    elif [ "$repo" == "lawnicons" ]; then
      preAssetsNamePattern="Lawnicons.Nightly.*.apk"
    elif [ "$repo" == "spotube" ] || [ "$releases" == "pre-release" ]; then
      preAssetsNamePattern="$preAssetsName"
    else
      preAssetsNamePattern=$(echo "$preAssetsName" | sed "s/$lastPreReleases/*/g")
    fi
    findFile=$(find "$dir" -type f -name "$preAssetsNamePattern" -print -quit)
    preFileBaseName=$(basename $findFile)
    
    if [ "$preAssetsName" != "$preFileBaseName" ]; then
      echo -e "$notice diffs: $preAssetsName ~ $preFileBaseName"
      [ -f "$findFile" ] && rm "$findFile"
      # downloading assets
      if [ "$releases" == "nightly" ] || [ "$releases" == "pre-release" ]; then
        dlUrl="https://github.com/$owner/$repo/releases/download/$releases/$preAssetsName"
      else
        dlUrl="https://github.com/$owner/$repo/releases/download/v${lastPreReleases}/$preAssetsName"
      fi
      findFile="$dir/$preAssetsName"
      if [ "$repo" == "revanced-cli" ] || { [ "$repo" == "revanced-patches" ] && { [ "$owner" == "inotia00" ] || [ "$owner" == "anddea" ]; }; } || [ "$repo" == "spotube" ] || [ "$repo" == "cloudstream" ]; then
        dl "aria2" "$dlUrl" "$findFile"
      else
        dl "curl" "$dlUrl" "$findFile"
      fi
    fi
    echo -e "$info findFile: ${Cyan}$findFile${Reset}"
  fi
}

#dlGitHub "inotia00" "revanced-cli" "latest" ".jar" "$RVX"
#dlGitHub "anddea" "revanced-patches" "pre" ".rvp" "$RVX"
#dlGitHub "REAndroid" "APKEditor" "latest" ".jar" "$Simplify"
#dlGitHub "inotia00" "VancedMicroG" "latest" ".apk" "$SimplUsr"
#dlGitHub "YT-Advanced" "GmsCore" "latest" ".apk" "$SimplUsr"
dlGitHub "$@"
###############################################################
