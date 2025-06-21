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

# --- Download required file from GitHub ---
dlGitHub() {
  local owner=$1
  local repo=$2
  local releases=$3
  local ext=$4
  local dir=$5
  
  regex=".*\\${ext}$"  # Simplified regex pattern
  if [ "$releases" == "latest" ]; then
    if [ "$repo" == "APKEditor" ]; then
      latestReleases=$(curl -s https://api.github.com/repos/$owner/$repo/releases/latest | jq -r '.tag_name | sub("^V"; "")')  # 1.4.3
      echo -e "$info latestReleases: V$latestReleases"
    else
      latestReleases=$(curl -s "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name | sub("^v"; "")' 2>/dev/null)
      echo -e "$info latestReleases: v$latestReleases"
    fi
    if [ "$repo" == "VancedMicroG" ]; then
      assetsName=$(curl -s "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name' 2>/dev/null)
      assetsNameWithoutExt="${assetsName%.*}"
      fileName="$assetsNameWithoutExt-${latestReleases}$ext"
      echo -e "$info assetsName: $fileName"
      assetsNamePattern=$(echo "$fileName" | sed "s/$latestReleases/*/g")
    else
      assetsName=$(curl -s "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r --arg regex "$regex" '.assets[] | select(.name | test($regex)) | .name' 2>/dev/null)
      echo -e "$info assetsName: $assetsName"
      assetsNamePattern=$(echo "$assetsName" | sed "s/$latestReleases/*/g")
    fi
    
    findFile=$(find "$dir" -type f -name "$assetsNamePattern" -print -quit)
    fileBaseName=$(basename $findFile)
    
    if [ "$assetsName" != "$fileBaseName" ]; then
      echo -e "$notice diffs: $assetsName ~ $fileBaseName"
      rm $findFile
      # downloading assets
      if [ "$repo" == "VancedMicroG" ]; then
        echo -e "$running Downloading $fileName.."
        curl -L -C - --progress-bar -o "$dir/$fileName" "https://github.com/$owner/$repo/releases/download/v${latestReleases}/$assetsName"
        findFile="$dir/$fileName"
      else
        echo -e "$running Downloading $assetsName.."
        if [ "$repo" == "APKEditor" ]; then
          curl -L -C - --progress-bar -o "$dir/$assetsName" "https://github.com/$owner/$repo/releases/download/V${latestReleases}/$assetsName"
        else
          curl -L -C - --progress-bar -o "$dir/$assetsName" "https://github.com/$owner/$repo/releases/download/v${latestReleases}/$assetsName"
        fi
        findFile="$dir/$assetsName"
      fi
    fi
    echo -e "$info findFile: ${Cyan}$findFile${Reset}"
  else
    lastPreReleases=$(curl -s "https://api.github.com/repos/$owner/$repo/releases" | jq -r '.[].tag_name | sub("^v"; "") | select(contains("dev"))' | head -n 1 2>/dev/null)
    echo -e "$info lastPreReleases: $lastPreReleases"
    
    # fetch assets from specific release tag
    preAssetsName=$(curl -s "https://api.github.com/repos/$owner/$repo/releases/tags/v$lastPreReleases" | jq -r --arg ext "$ext" '.assets[] | select(.name | endswith($ext)) | .name' 2>/dev/null)
    echo -e "$info preAssetsName: $preAssetsName"
    
    preAssetsNamePattern=$(echo "$preAssetsName" | sed "s/$lastPreReleases/*/g")
    findFile=$(find "$dir" -type f -name "$preAssetsNamePattern" -print -quit)
    preFileBaseName=$(basename $findFile)
    
    if [ "$preAssetsName" != "$preFileBaseName" ]; then
      echo -e "$notice diffs: $preAssetsName ~ $preFileBaseName"
      rm $findPreFile
      # downloading assets
      echo -e "$running Downloading $preAssetsName.."
      curl -L -C - --progress-bar -o "$dir/$preAssetsName" "https://github.com/$owner/$repo/releases/download/v${lastPreReleases}/$preAssetsName"
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