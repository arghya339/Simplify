#!/usr/bin/bash

# --- Downloading latest Simplify.sh file from GitHub ---
curl -fsSL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/Simplify.sh"

# Check if symlink doesn't already exist
if [ ! -f "$PREFIX/bin/simplify" ]; then
  ln -s "$HOME/.Simplify.sh" "$PREFIX/bin/simplify"  # symlink (shortcut of Simplify.sh)
fi
chmod +x "$HOME/.Simplify.sh"  # give execute permission to the Simplify.sh

# Colored log indicators
good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

<<comment
# --- dash supports ANSI escape codes for terminal text formatting ---
Color Forground_Color_Code Background_Color_Code
Black 30 40
Red 31 41
Green 32 42
Yellow 33 43
Blue 34 44
Magenta 35 45
Cyan 36 46
White 37 47

Gray_Background_Code 48
Default_background_Code 49

Color Bright_Color_Code
Bright-Black(Gray) 90
Bright-Red 91
Bright-Green 92
Bright-Yellow 93
Bright-Blue 94
Bright-Magenta 95
Bright-Cyan 96
Bright-White 97

Text_Format Code
Reset 0
Bold 1
Dim 2
Italic 3
Underline 4
Bold 5
Less Bold 6
Text with Background 7
invisible 8
Strikethrough 9

Examples
echo -e "\e[32mThis is green text\e[0m"
echo -e "\e[47mThis is a white background\e[0m"
echo -e "\e[32;47mThis is green text on white background\e[0m"
echo -e "\e[1;32;47mThis is bold green text on white background\e[0m"
comment

# ANSI color code
Green="\033[92m"
BoldGreen="\033[92;1m"
Red="\033[91m"
Blue="\033[94m"
White="\033[37m"
Yellow="\033[93m"
Reset="\033[0m"

# Construct the simplify shape using string concatenation
print_simplify=$(cat <<'EOF'
     .------------------------------.
     | ▄▀▀ █ █▄ ▄█ █▀▄ █   █ █▀ ▀▄▀ |
     | ▄██ █ █ ▀ █ █▀  █▄▄ █ █▀  █  |
     |      >_𝒟𝑒𝓋𝑒𝓁𝑜𝓅𝑒𝓇: @𝒶𝓇𝑔𝒽𝓎𝒶𝟥𝟥𝟫 |
     '------------------------------'\n    https://github.com/arghya339/Simplify
EOF
)

<<comment
# Construct the simplify shape using string concatenation
print_simplify=$(cat <<'EOF'
 ▄▀▀ █ █▄ ▄█ █▀▄ █   █ █▀ ▀▄▀\n ▄██ █ █ ▀ █ █▀  █▄▄ █ █▀  █\n      >_𝒟𝑒𝓋𝑒𝓁𝑜𝓅𝑒𝓇: @𝒶𝓇𝑔𝒽𝓎𝒶𝟥𝟥𝟫\n https://github.com/arghya339/Simplify
EOF
)
comment

# --- Storage Permission Check Logic ---
if [ ! -d "$HOME/storage/shared" ]; then
  # Attempt to list /storage/emulated/0 to trigger the error
  error=$(ls /storage/emulated/0 2>&1)
  expected_error="ls: cannot open directory '/storage/emulated/0': Permission denied"

  if echo "$error" | grep -qF "$expected_error" || ! echo "$error" | grep -q "^Android"; then
    echo -e "${notice} Storage permission not granted. Running ${Green}termux-setup-storage${Reset}.."
    termux-setup-storage
    exit 1  # Exit the script after handling the error
  else
    echo -e "${bad} Unknown error: ${Red}$error${Reset}"
    exit 1  # Exit on any other error
  fi
fi

# --- Checking Internet Connection ---
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 ; then
  echo -e "${bad} ${Red} Oops! No Internet Connection available.\nConnect to the Internet and try again later."
  exit 1
fi

# --- Global Variables ---
Android=$(getprop ro.build.version.release)  # Get Android version
arch=$(getprop ro.product.cpu.abi)  # Get Android arch
serial=$(su -c 'getprop ro.serialno')  # Get Serial Number required root
model=$(getprop ro.product.model)  # Get Device Model
outdatedPKG=$(apt list --upgradable 2>/dev/null)  # list of outdated pkg
installedPKG=$(pkg list-installed 2>/dev/null)  # list of installed pkg
SimplUsr="/sdcard/Simplify"
Simplify="$HOME/Simplify"
RV="$Simplify/RV"
RVX="$Simplify/RVX"
pikoTwitter="$Simplify/pikoTwitter"
Dropped="$Simplify/Dropped"
LSPatch="$Simplify/LSPatch"
mkdir -p "$Simplify" "$RV" "$RVX" "$pikoTwitter" "$Dropped" "$LSPatch" "$SimplUsr"
Download="/sdcard/Download"
simplifyJson="$Simplify/simplify.json"  # Configuration file to store simplify settings
FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null)
RipLocale="$(jq -r '.RipLocale' "$simplifyJson" 2>/dev/null)"
RipDpi="$(jq -r '.RipDpi' "$simplifyJson" 2>/dev/null)"
RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
ChangeRVXSource="$(jq -r '.ChangeRVXSource' "$simplifyJson" 2>/dev/null)"
isPreRelease=0  # Default value (false/off/0) for isPreRelease, it's enabled latest release for Patches source
isRipLocale=1  # Default value (true/on/1) for RipLocale, it's delete locale from patches apk file except device specific locale by default
isRipDpi=1  # Default value (true/on/1) for RipDpi, it's delete dpi from patches apk file except device specific dpi by default
isRipLib=1  # Default value (true/on/1) for RipLib, it's delete lib dir from patches apk file except device specific arch lib by default
isChangeRVXSource=0  # Default value (false/off/0) for ChangeRVXSource, means patches source remain unchange ie. official source (inotia00) for RVX Patches

# --- Checking Android Version ---
if [ $Android -le 4 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by RV Patches.${Reset}"
  return 1
fi

# --- pkg upgrade function ---
pkgUpdate() {
  local pkg=$1
  if echo $outdatedPKG | grep -q "^$pkg/" 2>/dev/null; then
    echo -e "$running Upgrading $pkg pkg.."
    pkg upgrade "$pkg" -y > /dev/null 2>&1
  fi
}

# --- pkg install/update function ---
pkgInstall() {
  local pkg=$1
  if echo "$installedPKG" | grep -q "$pkg" 2>/dev/null; then
    pkgUpdate "$pkg"
  else
    echo -e "$running Installing $pkg pkg.."
    pkg install "$pkg" -y > /dev/null 2>&1
  fi
}

pkgInstall "apt"  # apt update
pkgInstall "dpkg"  # dpkg update
pkgInstall "bash"  # bash update
pkgInstall "curl"  # curl update
pkgInstall "aria2"  # aria2 install/update
pkgInstall "jq"  # jq install/update
pkgInstall "pup"  # pup install/update
pkgInstall "openjdk-21"  # java install/update
pkgInstall "apksigner"  # apksigner install/update
pkgInstall "bsdtar"  # bsdtar install/update
pkgInstall "pv"  # pv install/update
pkgInstall "grep"  # grep update
if su -c "id" >/dev/null 2>&1; then
  pkgInstall "openssl"  # openssl install/update
  pkgInstall "python"  # python install/update
  if ! pip list 2>/dev/null | grep -q "apksigcopier"; then
    pip install apksigcopier > /dev/null 2>&1  # install apksigcopier using pip
  fi
fi

# --- Shizuku Setup first time ---
if [ ! -f "$HOME/rish" ] || [ ! -f "$HOME/rish_shizuku.dex" ]; then
  echo -e "$info Please manually install Shizuku from Google Play Store." && sleep 1
  termux-open-url "https://play.google.com/store/apps/details?id=moe.shizuku.privileged.api"
  am start -n com.android.settings/.Settings\$MyDeviceInfoActivity > /dev/null 2>&1  # Open Device Info

  curl -o "$HOME/rish" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Termux/Shizuku/rish" &> /dev/null && chmod +x "$HOME/rish"
  sleep 0.5 && curl -o "$HOME/rish_shizuku.dex" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Termux/Shizuku/rish_shizuku.dex" > /dev/null 2>&1
  
  echo -e "$info Please start Shizuku by following guide." && sleep 1
  if [ $Android -le 10 ]; then
    am start -n com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity > /dev/null 2>&1  # Open Developer options
    termux-open-url "https://youtu.be/ZxjelegpTLA"  # YouTube/@MrPalash360: Start Shizuku using Computer
  else
    am start -n com.android.settings/.Settings\$WirelessDebuggingActivity > /dev/null 2>&1  # Open Wireless Debugging Settings
    termux-open-url "https://youtu.be/YRd0FBfdntQ"  # YouTube/@MrPalash360: Start Shizuku Android 11+
  fi
fi

# --- Download and give execute (--x) permission to AAPT2 Binary ---
if [ ! -f "$HOME/aapt2" ]; then
  echo -e "$running Downloading aapt2 binary from GitHub.."
  curl -sL "https://github.com/arghya339/aapt2/releases/download/all/aapt2_$arch" --progress-bar -o "$HOME/aapt2" && chmod +x "$HOME/aapt2"
fi

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlGitHub.sh" --progress-bar -o $Simplify/dlGitHub.sh

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/APKMdl.sh" --progress-bar -o $Simplify/APKMdl.sh

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlUptodown.sh" --progress-bar -o $Simplify/dlUptodown.sh

curl -sL "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkInstall.sh" --progress-bar -o $Simplify/apkInstall.sh

# --- Download branding.zip ---
if [ ! -d "$SimplUsr/.branding" ] && [ ! -f "$SimplUsr/branding.zip" ]; then
  echo -e "$running Downloading ${Red}branding.zip${Reset} from GitHub.."
  curl -sL "https://github.com/arghya339/Simplify/releases/download/all/branding.zip" --progress-bar -o "$SimplUsr/branding.zip"
fi
# --- Extrct branding.zip ---
if [ -f "$SimplUsr/branding.zip" ] && [ ! -d "$SimplUsr/.branding" ]; then
  echo -e "$running Extrcting ${Red}branding.zip${Reset} to $SimplUsr dir.."
  pv "$SimplUsr/branding.zip" | bsdtar -xof - -C "$SimplUsr/" --no-same-owner --no-same-permissions
  mv "$SimplUsr/branding" "$SimplUsr/.branding"  # Rename branding dir to .branding to hide it from file Gallery
fi
# --- Remove branding.zip ---
if [ -d "$SimplUsr/.branding" ] && [ -f "$SimplUsr/branding.zip" ]; then
  rm "$SimplUsr/branding.zip"
fi

# --- Create a ks.keystore for Signing apk ---
if [ ! -f "$Simplify/ks.keystore" ]; then
  echo -e "$running Create a 'ks.keystore' for Signing apk.."
  $PREFIX/lib/jvm/java-21-openjdk/bin/keytool -genkey -v -storetype pkcs12 -keystore $Simplify/ks.keystore -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456
  $PREFIX/lib/jvm/java-21-openjdk/bin/keytool -list -v -keystore $Simplify/ks.keystore -storepass 123456 | grep -oP '(?<=Owner:).*' | xargs
fi

Unmount() {
  su -c '/data/data/com.termux/files/usr/bin/bash -c '\''
  pkgArr=("com.google.android.youtube" "com.google.android.apps.youtube.music" "com.google.android.apps.photos")
  nameArr=("YouTube" "YouTube Music" "Google Photos")
  if [ -d "/data/adb/revanced" ]; then
    for i in "${!pkgArr[@]}"; do 
        DIR="/data/adb/revanced/${pkgArr[$i]}/"
        if [ -e "$DIR" ]; then
          if [ "$i" == "0" ]; then
            nameList[$i]="${nameArr[0]}"
          elif [ "$i" == "1" ]; then
            nameList[$i]="${nameArr[1]}"
          elif [ "$i" == "2" ]; then
            nameList[$i]="${nameArr[2]}"
          fi
        fi
    done

    while true; do
      # Display the list
      echo -e "$info Available apps:"
      for i in "${!nameList[@]}"; do
        printf "%d. %s\n" "$i" "${nameList[$i]}"
      done

      # Ask for an index, showing the valid range
      max=$(( ${#nameList[@]} - 1 ))  # highest legal index
      read -rp "Enter the index [0-${max}] of apps you want to unmount or 'Q' to Quit: " idx

      # Validate and respond
      if [[ "$idx" == [Qq]* ]]; then
        break  # break the while loop
      elif [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 0 && idx <= max )); then
        echo -e "$notice You chose: ${nameList[$idx]}"
      else
        echo -e "$info \"$idx\" is not a valid index! Please select index [0-${max}]." >&2
      fi
  
      case "${nameList[$idx]}" in
        YouTube)
          pkgName="com.google.android.youtube"
          su -mm -c "/system/bin/sh /data/adb/post-fs-data.d/$pkgName.sh"
          ;;
        "YouTube Music")
          pkgName="com.google.android.apps.youtube.music"
          su -mm -c "/system/bin/sh /data/adb/post-fs-data.d/$pkgName.sh"
          ;;
        "Google Photos")
          pkgName="com.google.android.apps.photos"
          su -mm -c "/system/bin/sh /data/adb/post-fs-data.d/$pkgName.sh"
          ;;
        *) echo -e "$info Invalid selection! Please select a valid app." ;;
      esac
    done
  fi
  '\'''
}

if [ ! -f "$simplifyJson" ]; then
  echo -e "$running Creating Configuration file.."
  jq -n "{ \"FetchPreRelease\": "$isPreRelease" }" > "$simplifyJson"  # Create new json file with {data} using jq null flags
  jq ".RipLocale = $isRipLocale" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
  jq ".RipDpi = $isRipDpi" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
  jq ".RipLib = $isRipLib" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
  jq ".ChangeRVXSource = $isChangeRVXSource" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
fi

fetchPreRelease() {
  while true; do
    read -r -p "FetchPreRelease [T/f]: " opt
    case "$opt" in
      [Tt]*)
        isPreRelease=1  # FetchPreRelease  == true
        jq ".FetchPreRelease = $isPreRelease" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
        echo -e "$info FetchPreRelease is True. Last Pre Release Patches will be fetched."
        break
        ;;
      [Ff]*)
        isPreRelease=0  # FetchPreRelease  == false
        jq ".FetchPreRelease = $isPreRelease" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
        echo -e "$info FetchPreRelease is False. Latest Release Patches will be fetched."
        break
        ;;
      *) echo -e "${info} Invalid input! Please enter T or F." ;;
    esac
  done
}

ripLocale() {
  while true; do
    read -r -p "RipLocale [E/d]: " opt
    case "$opt" in
      [Ee]*)
        isRipLocale=1  # Enable RipLocale
        jq ".RipLocale = $isRipLocale" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
        echo -e "$info RipLocale is Enabled! Device specific locale will be kept in patches apk file."
        break
        ;;
      [Dd]*)
        isRipLocale=0  # Disable RipLocale
        jq ".RipLocale = $isRipLocale" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
        echo -e "$info RipLocale is Disabled! All locale will be kept in patches apk file."
        break
        ;;
      *) echo -e "${info} Invalid input! Please enter E or D." ;;
    esac
  done
}

ripDpi() {
  while true; do
    read -r -p "RipDpi [E/d]: " opt
    case "$opt" in
      [Ee]*)
        isRipDpi=1  # Enable RipDpi
        jq ".RipDpi = $isRipDpi" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
        echo -e "$info RipDpi is Enabled! Device specific dpi will be kept in patches apk file."
        break
        ;;
      [Dd]*)
        isRipDpi=0  # Disable RipDpi
        jq ".RipDpi = $isRipDpi" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
        echo -e "$info RipDpi is Disabled! All dpi will be kept in patches apk file."
        break
        ;;
      *) echo -e "${info} Invalid input! Please enter E or D." ;;
    esac
  done
}

ripLib() {
  while true; do
    read -r -p "RipLib [E/d]: " opt
    case "$opt" in
      [Ee]*)
        isRipLib=1  # Enable RipLib
        jq ".RipLib = $isRipLib" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
        echo -e "$info RipLib is Enabled. Device specific arch lib will be kept in patches apk file."
        break
        ;;
      [Dd]*)
        isRipLib=0  # Disable RipLib
        jq ".RipLib = $isRipLib" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
        echo -e "$info RipLib is Disabled. All lib dir will be kept in patches apk file."
        break
        ;;
      *) echo -e "${info} Invalid input! Please enter E or D." ;;
    esac
  done
}

changeRVXSource() {
  while true; do
    read -r -p "ChangeRVXSource [Y/n]: " opt
    case "$opt" in
      [Yy]*)
        isChangeRVXSource=1  # ChangeRVXSource: anddea
        jq ".ChangeRVXSource = $isChangeRVXSource" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
        echo -e "$info ChangeRVXSource == Yes. RVX Patches source will be changed to anddea."
        break
        ;;
      [Nn]*)
        isChangeRVXSource=0  # ChangeRVXSource: inotia00
        jq ".ChangeRVXSource = $isChangeRVXSource" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
        echo -e "$info ChangeRVXSource == No. RVX Patches source will remain official (inotia00)."
        break
        ;;
      *) echo -e "${info} Invalid input! Please enter Y or N." ;;
    esac
  done
}

pat() {
  while true; do
    if { [ -f "$HOME/.config/gh/hosts.yml" ] && ! grep -q "{}" "$HOME/.config/gh/hosts.yml" 2>/dev/null; } || { [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; }; then
      echo -e "${info} You already have a GitHub token!"
      echo -e "${Yellow}Do you want to delete it? [Y/n]${Reset} \c" && read userInput
      case "$userInput" in
        [Yy]*)
          if { [ -f "$HOME/.config/gh/hosts.yml" ] && ! grep -q "{}" "$HOME/.config/gh/hosts.yml" 2>/dev/null; } || ! gh auth status 2>/dev/null; then
            gh auth logout  # Logout from gh cli
          elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
            jq 'del(.PAT)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete PAT key from simplify.json
            termux-open-url "https://github.com/settings/tokens"
          fi
          echo -e "${Green}Successfully deleted your GitHub token!${Reset}"
          ;;
        [Nn]*) break ;;
        *) echo -e "${info} ${Blue}Invalid input! Please enter Yes or No.${Reset}" ;;
      esac
    else
      echo -e "${Yellow}Do you want to increase the GitHub API rate limit by adding a github token? [Y/n]${Reset} \c" && read userInput
      case "$userInput" in
        [Yy]*)
          echo -e "${Yellow}Select a method to create a GitHub access token: (gh) GitHub CLI or (pat) Personal Access Token? [gh/pat]${Reset} \c" && read method
          case "$method" in
            [Gg]*)
              pkgInstall "gh"  # gh install/update
              echo -e "${running} Creating GitHub access token using GitHub CLI.."
              gh auth login  # Authenticate gh cli with GitHub account
              gh_api_response=$(owner="ReVanced" && repo="revanced-patches" && gh api "repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
              if [[ $gh_api_response == v* ]] && [ $gh_api_response != "null" ]; then
                echo -e "${Green}Successfully authenticated with GitHub CLI!${Reset}"
                echo -e "${Yellow}Your GitHub API rate limit has been increased.${Reset}"
              else
                echo -e "${bad} ${Red}Failed to authenticate with GitHub CLI! Please try again.${Reset}"
                gh auth logout  # Logout from gh cli
              fi
              ;;
            [Pp]*)
              echo -e "${running} Creating Personal Access Token.."
              termux-open-url "https://github.com/settings/tokens/new?scopes=public_repo&description=Simplify"  # Create a PAT with the scope `public_repo`
              echo -e "${Yellow}Please copy the generated Simplify PAT & paste it here:${Reset} \c" && read -r pat
              if [[ $pat == ghp_* ]] && [ $pat != "" ]; then
                jq ".PAT = \"$pat\"" "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Change key value: Reads content of existing json and assigns key new value then redirect new json data to temp.json then rename it to simplify.json
                PAT=$(jq -r '.PAT' "$simplifyJson" 2>/dev/null)
                gh_api_response=$(auth="-H \"Authorization: Bearer $PAT\"" && owner="ReVanced" && repo="revanced-patches" && curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
                if [[ $gh_api_response == v* ]] && [ $gh_api_response != "null" ]; then
                  echo -e "${Green}Successfully added your GitHub PAT!${Reset}"
                  echo -e "${Yellow}Your GitHub API rate limit has been increased.${Reset}"
                fi
              else
                echo -e "${bad} ${Red}Invalid PAT! Please try again.${Reset}"
                jq 'del(.PAT)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete PAT key from simplify.json
                termux-open-url "https://github.com/settings/tokens"
              fi
              ;;
            *) echo -e "${info} ${Blue}Invalid input! Please enter gh or pat.${Reset}" ;;
          esac
          ;;
        [Nn]*) break ;;
        *) echo -e "${info} ${Blue}Invalid input! Please enter Yes or No.${Reset}" ;;
      esac
    fi
  done
}

# --- Feature request prompt ---
feature() {
  echo -e "${Yellow}Do you want any new feature in this script? [Y/n]${Reset}: \c" && read userInput
  case "$userInput" in
    [Yy]*)
      echo -e "${running} Creating feature request template using your key words.."
      echo -e "Describe the new feature: \c" && read feature_description
      termux-open-url "https://github.com/arghya339/Simplify/issues/new?title=Feature&body=$feature_description"
      echo -e "${Green}❤️ Thanks for your suggestion!${Reset}"
      ;;
    [Nn]*) echo -e "${running} Proceeding.." ;;
    *) echo -e "${info} ${Blue}Invalid input! Please enter Yes or No.${Reset}" ;;
  esac
}

# --- Bug report prompt ---
bug() {
  echo -e "${Yellow}Did you find any bugs? [Y/n]${Reset}: \c" && read userInput
  case "$userInput" in
    [Yy]*)
      echo -e "${running} Creating bug report template uisng your keywords.."
      echo -e "Describe the bug: \c" && read issue_description
      termux-open-url "https://github.com/arghya339/Simplify/issues/new?title=Bug&body=$issue_description"
      echo -e "${Green}🖤 Thanks for the report!${Reset}"
      ;;
    [Nn]*) echo -e "${Green}💐 Thanks for chosing Simplify!${Reset}" ;;
    *) echo -e "${info} ${Blue}Invalid input! Please enter Yes or No.${Reset}" ;;
  esac
}

# --- Open support URL in the default browser ---
support() {
  echo -e "${Yellow}⭐ Star & 🍻 Fork me.."
  termux-open-url "https://github.com/arghya339/Simplify"
  echo -e "${Yellow}💲 Donation: PayPal/@arghyadeep339"
  termux-open-url "https://www.paypal.com/paypalme/arghyadeep339"
  echo -e "${Yellow}🔔 Subscribe: YouTube/@MrPalash360"
  termux-open-url "https://www.youtube.com/channel/UC_OnjACMLvOR9SXjDdp2Pgg/videos?sub_confirmation=1"
  #echo -e "${Yellow}📣 Follow: Telegram"
  #termux-open-url "https://t.me/MrPalash360"
  #echo -e "${Yellow}💬 Join: Telegram"
  #termux-open-url "https://t.me/MrPalash360Discussion"
}

# --- Show developer info ---
about() {
  echo -e "${Green}✨ Powered by ReVanced (revanced.app)"
  termux-open-url "https://revanced.app/"
  echo -e "${Green}🧑‍💻 Author arghya339 (github.com/arghya339)"
  echo
}

while true; do
  clear  # Clear
  # Apply the eye color to the simplify shape and print it
  echo -e "${BoldGreen}$print_simplify${Reset}" && echo ""  # Space
  echo -e "D   : Download Patches App\nRV  : ReVanced\nRVS : RV SuperUser\nRVX : ReVanced Extended\nRVXS: RVX SuperUser\nPiko: Piko Twitter\nDrop: Dropped Patches\nLS  : LSPatch\nC   : Configuration\nU   : Unmount Apps\nF   : Feature request\nB   : Bug report\nS   : Support\nA   : About\nQ   : Quit\n"
  echo -n "Select Patches source: " && read source
  case $source in
    D|d)
      curl -sL -o "$Simplify/dlPatchesApp.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlPatchesApp.sh"
      bash "$Simplify/dlPatchesApp.sh"
      sleep 3
      ;;
    RV|rv)
      curl -sL -o "$RV/RV.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RV.sh"
      bash "$RV/RV.sh"
      sleep 3
      ;;
    RVS*|rvs*)
      if su -c "id" >/dev/null 2>&1; then
        curl -sL -o "$RV/RVSU.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RVSU.sh"
        curl -sL -o "$Simplify/apkMount.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkMount.sh"
        bash "$RV/RVSU.sh"
      else
        echo -e "$notice SuperUser permission is not granted! RV SuperUser required SU permission."
      fi
      sleep 3
      ;;
    RVX|rvx)
      curl -sL -o "$RVX/RVX.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RVX.sh"
      bash "$RVX/RVX.sh"
      sleep 3
      ;;
    RVXS*|rvxs*)
      if su -c "id" >/dev/null 2>&1; then
        curl -sL -o "$RVX/RVXSU.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RVXSU.sh"
        curl -sL -o "$Simplify/apkMount.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkMount.sh"
        bash "$RVX/RVXSU.sh"
      else
        echo -e "$notice SuperUser permission is not granted! RVX SuperUser required SU permission."
      fi
      sleep 3
      ;;
    PIKO*|piko*)
      curl -sL -o "$pikoTwitter/pikoTwitter.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/pikoTwitter.sh"
      bash "$pikoTwitter/pikoTwitter.sh"
      sleep 3
      ;;
    DROP*|drop*)
      curl -sL -o "$Dropped/droppedPatches.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/droppedPatches.sh"
      bash "$Dropped/droppedPatches.sh"
      sleep 3
      ;;
    LS*|ls*)
      curl -sL -o "$LSPatch/LSPatch.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/LSPatch.sh"
      if su -c "id" >/dev/null 2>&1; then
        curl -sL -o "$Simplify/apkMount.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkMount.sh"
      fi
      bash "$LSPatch/LSPatch.sh"
      sleep 3
      ;;
    [Cc]*)
      while true; do
        echo -e "P. FetchPreRelease\nL. RipLocale\nD. RipDpi\nR. RipLib\nS. Change RVX Source\nT. Add gh PAT (increases gh api rate limit)\nQ. Quit\n"
        read -r -p "Select: " opt
        case "$opt" in
          [Pp]*) if [ "$FetchPreRelease" == 0 ]; then echo "FetchPreRelease == false"; else echo "FetchPreRelease == true"; fi && fetchPreRelease ;;
          [Ll]*) if [ "$RipLocale" == 1 ]; then echo "RipLocale == Enabled"; else echo "RipLocale == Disabled"; fi && ripLocale ;;
          [Dd]*) if [ "$RipDpi" == 1 ]; then echo "RipDpi == Enabled"; else echo "RipDpi == Disabled"; fi && ripDpi ;;
          [Rr]*) if [ "$RipLib" == 1 ]; then echo "RipLib == Enabled"; else echo "RipLib == Disabled"; fi && ripLib ;;
          [Ss]*) if [ "$ChangeRVXSource" == 0 ]; then echo "ChangeRVXSource == No"; else echo "ChangeRVXSource == Yes"; fi && changeRVXSource ;;
          [Tt]*) 
            if { [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; } || { ! gh auth status 2>/dev/null && [ -f "$HOME/.config/gh/hosts.yml" ]; }; then
              if jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
                echo -e "$info ${Green}PAT: ghp_************************************${Reset}"
              else
                echo -e "$info ${Green}oauth_token: gho_************************************${Reset}"
              fi
            else
              echo -e "$notice ${Yellow}No GitHub token found!${Reset}"
              pat  # Call the pat function to create & add GitHub token
            fi
            ;;
          [Qq]*) break ;;
          *) echo -e "$info Invalid input! Please enter P / L / D / R / S / T." ;;
        esac
      done
      sleep 3
      ;;
    [Uu]*) Unmount && sleep 3 ;;
    [Ff]*) feature && sleep 3 ;;
    [Bb]*) bug && sleep 3 ;;
    [Ss]*) support && sleep 3 ;;
    [Aa]*) about && sleep 3 ;;
    [Qq]*) clear && break ;;
    *) echo -e "$info Invalid input! Please enter: D / RV / RVS / RVX / RVXS / Piko / Drop / LS / C / U / F / B / S / A / Q" && sleep 3 ;;
  esac
done
##########################################################################################################################################