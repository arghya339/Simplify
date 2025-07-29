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
if [ -f "$HOME/.config/gh/hosts.yml" ] && gh auth status 2>/dev/null; then
  # oauth_token: gho_************************************
  token=$(grep -A2 "users:" ~/.config/gh/hosts.yml | grep -v "users:" | grep -A1 "oauth_token:" | awk '/oauth_token:/ {getline; print $2}')
elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
  # PAT: ghp_************************************
  token=$(jq -r '.PAT' "$simplifyJson" 2>/dev/null)
else
  token=""
fi
if [ -z "$token" ]; then
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

  if [ "$releases" == "latest" ]; then
    if [ "$repo" == "APKEditor" ]; then
      latestReleases=$(curl -s ${auth} https://api.github.com/repos/$owner/$repo/releases/latest | jq -r '.tag_name | sub("^V"; "")')  # 1.4.3
      echo -e "$info latestReleases: V$latestReleases"
    else
      latestReleases=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name | sub("^v"; "")' 2>/dev/null)
      if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
        echo -e "$info latestReleases: $latestReleases"
      else
        echo -e "$info latestReleases: v$latestReleases"
      fi
    fi
    if [ "$repo" == "VancedMicroG" ] || [ "$repo" == "LSPatch" ]; then
      assetsName=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name' 2>/dev/null)
      assetsNameWithoutExt="${assetsName%.*}"
      fileName="$assetsNameWithoutExt-${latestReleases}$ext"
      echo -e "$info assetsName: $fileName"
      assetsNamePattern=$(echo "$fileName" | sed "s/$latestReleases/*/g")
    elif [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
      assetsName="$assets"
      echo -e "$info assetsName: $assetsName"
    else
      assetsName=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name' 2>/dev/null)
      echo -e "$info assetsName: $assetsName"
      assetsNamePattern=$(echo "$assetsName" | sed "s/$latestReleases/*/g")
    fi
    
    if [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
      findFile="$dir/$assetsName"
      fileBaseName=$(basename $findFile)
    else
      findFile=$(find "$dir" -type f -name "$assetsNamePattern" -print -quit)
      fileBaseName=$(basename $findFile)
    fi
    
    if [ "$repo" == "VancedMicroG" ] || [ "$repo" == "LSPatch" ]; then
      if [ "$fileName" != "$fileBaseName" ]; then
        echo -e "$notice diffs: $fileName ~ $fileBaseName"
        [ -f "$findFile" ] && rm "$findFile"
        echo -e "$running Downloading $fileName.."
        curl -L -C - --progress-bar -o "$dir/$fileName" "https://github.com/$owner/$repo/releases/download/v${latestReleases}/$assetsName"
        findFile="$dir/$fileName"
      fi
    elif [ "$repo" == "ReVancedApp-Actions" ] || [ "$repo" == "Revanced-And-Revanced-Extended-Non-Root" ]; then
      [ -f "$findFile" ] && rm "$findFile"
      echo -e "$running Downloading $assetsName.."
      aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$assetsName" -d "$dir" "https://github.com/$owner/$repo/releases/download/${latestReleases}/$assetsName"
      echo  # White Space
      findFile="$dir/$assetsName"
    else 
      if [ "$assetsName" != "$fileBaseName" ]; then
        echo -e "$notice diffs: $assetsName ~ $fileBaseName"
        [ -f "$findFile" ] && rm "$findFile"
        # downloading assets
        echo -e "$running Downloading $assetsName.."
        if [ "$repo" == "APKEditor" ]; then
          curl -L -C - --progress-bar -o "$dir/$assetsName" "https://github.com/$owner/$repo/releases/download/V${latestReleases}/$assetsName"
        else
          if [ "$repo" == "revanced-cli" ]; then
            aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$assetsName" -d "$dir" "https://github.com/$owner/$repo/releases/download/v${latestReleases}/$assetsName"
            echo  # White Space
          else
            curl -L -C - --progress-bar -o "$dir/$assetsName" "https://github.com/$owner/$repo/releases/download/v${latestReleases}/$assetsName"
          fi
        fi
        findFile="$dir/$assetsName"
      fi
    fi
    echo -e "$info findFile: ${Cyan}$findFile${Reset}"
  else
    lastPreReleases=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r '.[].tag_name | sub("^v"; "") | select(contains("dev"))' | head -n 1 2>/dev/null)
    echo -e "$info lastPreReleases: $lastPreReleases"
    
    # fetch assets from specific release tag
    preAssetsName=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/tags/v$lastPreReleases" | jq -r --arg ext "$ext" '.assets[] | select(.name | endswith($ext)) | .name' 2>/dev/null)
    echo -e "$info preAssetsName: $preAssetsName"
    
    preAssetsNamePattern=$(echo "$preAssetsName" | sed "s/$lastPreReleases/*/g")
    findFile=$(find "$dir" -type f -name "$preAssetsNamePattern" -print -quit)
    preFileBaseName=$(basename $findFile)
    
    if [ "$preAssetsName" != "$preFileBaseName" ]; then
      echo -e "$notice diffs: $preAssetsName ~ $preFileBaseName"
      [ -f "$findFile" ] && rm "$findFile"
      # downloading assets
      echo -e "$running Downloading $preAssetsName.."
      if [ "$repo" == "revanced-cli" ]; then
        aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$preAssetsName" -d "$dir" "https://github.com/$owner/$repo/releases/download/v${lastPreReleases}/$preAssetsName"
        echo  # White Space
      else
        curl -L -C - --progress-bar -o "$dir/$preAssetsName" "https://github.com/$owner/$repo/releases/download/v${lastPreReleases}/$preAssetsName"
      fi
      findFile="$dir/$preAssetsName"
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