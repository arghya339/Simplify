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
    https://github.com/arghya339/Simplify
      .------------------------------.
      | ▄▀▀ █ █▄ ▄█ █▀▄ █   █ █▀ ▀▄▀ |
      | ▄██ █ █ ▀ █ █▀  █▄▄ █ █▀  █  |
      |      >_𝒟𝑒𝓋𝑒𝓁𝑜𝓅𝑒𝓇: @𝒶𝓇𝑔𝒽𝓎𝒶𝟥𝟥𝟫 |
      '------------------------------'
EOF
)

<<comment
# Construct the simplify shape using string concatenation
print_simplify=$(cat <<'EOF'
   https://github.com/arghya339/Simplify\n       ▄▀▀ █ █▄ ▄█ █▀▄ █   █ █▀ ▀▄▀\n       ▄██ █ █ ▀ █ █▀  █▄▄ █ █▀  █\n            >_𝒟𝑒𝓋𝑒𝓁𝑜𝓅𝑒𝓇: @𝒶𝓇𝑔𝒽𝓎𝒶𝟥𝟥𝟫
EOF
)
comment

Android=$(getprop ro.build.version.release)  # Get Android version

# --- Storage Permission Check Logic ---
if [ ! -d "$HOME/storage/shared" ] || ! ls /sdcard/ 2>/dev/null | grep -q "^Android"; then
  echo -e "${notice} ${Yellow}Storage permission not granted!${Reset}\n$running ${Green}termux-setup-storage${Reset}.."
  if [ "$Android" -gt 5 ]; then  # for Android 5 storage permissions grant during app installation time, so Termux API termux-setup-storage command not required
    termux-setup-storage  # ask Termux Storage permissions
    if [ "$Android" -lt 8 ]; then
      exit 0  # Exit the script
    fi
  fi
fi
if ! ls /sdcard/ 2>/dev/null | grep -E -q "^(Android|Download)"; then
  termux-setup-storage
  if [ "$Android" -lt 8 ]; then
    exit 0
  fi
fi

# --- enabled allow-external-apps ---
if [ "$Android" -eq 6 ] && [ ! -f "$HOME/.termux/termux.properties" ]; then
  mkdir -p "$HOME/.termux" && echo "allow-external-apps = true" > "$HOME/.termux/termux.properties"
  echo -e "$notice 'termux.properties' file has been created successfully & 'allow-external-apps = true' line has been add (enabled) in Termux \$HOME/.termux/termux.properties."
  termux-reload-settings
fi
if [ "$Android" -ge 6 ]; then
  if grep -q "^# allow-external-apps" "$HOME/.termux/termux.properties"; then
    # other Android applications can send commands into Termux.
    # termux-open utility can send an Android Intent from Termux to Android system to open apk package file in pm.
    # other Android applications also can be Access Termux app data (files).
    sed -i '/allow-external-apps/s/# //' "$HOME/.termux/termux.properties"  # uncomment 'allow-external-apps = true' line
    echo -e "$notice 'allow-external-apps = true' line has been uncommented (enabled) in Termux \$HOME/.termux/termux.properties."
    if [ "$Android" -eq 6 ]; then
      termux-reload-settings  # reload (restart) Termux settings required for Android 6 after enabled allow-external-apps
    fi
  fi
fi

# --- Checking Internet Connection ---
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 ; then
  echo -e "${bad} ${Red} Oops! No Internet Connection available.\nConnect to the Internet and try again later."
  exit 1
fi

# --- Global Variables ---
cpuAbi=$(getprop ro.product.cpu.abi)  # Get Android arch
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
isPreRelease=0  # Default value (false/off/0) for isPreRelease, it's enabled latest release for Patches source
isRipLocale=1  # Default value (true/on/1) for RipLocale, it's delete locale from patched apk file except device specific locale by default
isRipDpi=1  # Default value (true/on/1) for RipDpi, it's delete dpi from patched apk file except device specific dpi by default
isRipLib=1  # Default value (true/on/1) for RipLib, it's delete lib dir from patched apk file except device specific arch lib by default
isChangeRVXSource=0  # Default value (false/off/0) for ChangeRVXSource, means patches source remain unchange ie. official source (inotia00) for RVX Patches
isReadPatchesFile=0  # Default value (false/off/0) for ReadPatchesFile, means recommended PatchesOptions loading from script.
branding="google_family"

# --- Checking Android Version ---
if [ $Android -le 4 ]; then
  echo -e "${bad} ${Red}Android $Android is not supported by RV Patches.${Reset}"
  return 1
fi

# --- pkg uninstall function ---
pkgUninstall() {
  local pkg=$1
  if echo "$installedPKG" | grep -q "^$pkg/" 2>/dev/null; then
    echo -e "$running Uninstalling $pkg pkg.."
    pkg uninstall "$pkg" -y > /dev/null 2>&1
  fi
}

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
  if echo "$installedPKG" | grep -q "^$pkg/" 2>/dev/null; then
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
pkgInstall "sed"  # sed update
pkgInstall "glow"  # glow install/update
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
  #termux-open-url "https://play.google.com/store/apps/details?id=moe.shizuku.privileged.api"
  termux-open-url "https://github.com/RikkaApps/Shizuku/releases/latest"
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
  curl -sL "https://github.com/arghya339/aapt2/releases/download/all/aapt2_$cpuAbi" --progress-bar -o "$HOME/aapt2" && chmod +x "$HOME/aapt2"
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
    while true; do
      nameList=()  # Clear nameList array first
      index=0  # This ensures sequential numbering
    
      # Build available apps list
      for i in "${!pkgArr[@]}"; do 
        if [ -e "/data/adb/revanced/${pkgArr[$i]}/" ]; then
          nameList[$index]="${nameArr[$i]}"
          ((index++))
        fi
      done

      # Exit if no apps available
      [ ${#nameList[@]} -eq 0 ] && { echo "No apps available!"; break; }
    
      # Display menu
      echo "Available apps:"
      for i in "${!nameList[@]}"; do
        echo "$i. ${nameList[$i]}"
      done

      # Get user input
      read -p "Enter index [0-$(( ${#nameList[@]} - 1 ))] or 'Q' to quit: " idx
    
      [[ "$idx" =~ [Qq] ]] && break
    
      # Validate and process selection
      if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -lt "${#nameList[@]}" ]; then
        for i in "${!nameArr[@]}"; do
          if [ "${nameArr[$i]}" = "${nameList[$idx]}" ]; then
            su -mm -c "/system/bin/sh /data/adb/post-fs-data.d/${pkgArr[$i]}.sh"
            break
          fi
        done
      else
        echo "Invalid selection!"
      fi
    done
  fi
  '\'''
}

config() {
  local key="$1"
  local value="$2"
  
  if [ ! -f "$simplifyJson" ]; then
    jq -n "{}" > "$simplifyJson"
  fi
  
  jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"
}
all_key=("FetchPreRelease" "RipLocale" "RipDpi" "RipLib" "ChangeRVXSource" "ReadPatchesFile" "Branding")
all_value=("$isPreRelease" "$isRipLocale" "$isRipDpi" "$isRipLib" "$isChangeRVXSource" "$isReadPatchesFile" "$branding")
# Loop through all keys and set values if they don't exist
for i in "${!all_key[@]}"; do
  if ! jq -e --arg key "${all_key[i]}" 'has($key)' "$simplifyJson" >/dev/null; then
    config "${all_key[i]}" "${all_value[i]}"
  fi
done

fetchPreRelease() {
  while true; do
    read -r -p "FetchPreRelease [T/f]: " opt
    case "$opt" in
      [Tt]*)
        isPreRelease=1  # FetchPreRelease  == true
        config "FetchPreRelease" "$isPreRelease"
        echo -e "$good ${Green}FetchPreRelease is True! Last Pre Release Patches will be fetched.${Reset}"
        break
        ;;
      [Ff]*)
        isPreRelease=0  # FetchPreRelease  == false
        config "FetchPreRelease" "$isPreRelease"
        echo -e "$good ${Green}FetchPreRelease is False! Latest Release Patches will be fetched.${Reset}"
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
        config "RipLocale" "$isRipLocale"
        echo -e "$good ${Green}RipLocale is Enabled! Device specific locale will be kept in patched apk file.${Reset}"
        break
        ;;
      [Dd]*)
        isRipLocale=0  # Disable RipLocale
        config "RipLocale" "$isRipLocale"
        echo -e "$good ${Green}RipLocale is Disabled! All locale will be kept in patched apk file.${Reset}"
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
        config "RipDpi" "$isRipDpi"
        echo -e "$good ${Green}RipDpi is Enabled! Device specific dpi will be kept in patched apk file.${Reset}"
        break
        ;;
      [Dd]*)
        isRipDpi=0  # Disable RipDpi
        config "RipDpi" "$isRipDpi"
        echo -e "$good ${Green}RipDpi is Disabled! All dpi will be kept in patched apk file.${Reset}"
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
        config "RipLib" "$isRipLib"
        echo -e "$good ${Green}RipLib is Enabled! Device specific arch lib will be kept in patched apk file.${Reset}"
        break
        ;;
      [Dd]*)
        isRipLib=0  # Disable RipLib
        config "RipLib" "$isRipLib"
        echo -e "$good ${Green}RipLib is Disabled! All lib dir will be kept in patched apk file.${Reset}"
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
        config "ChangeRVXSource" "$isChangeRVXSource"
        echo -e "$good ${Green}ChangeRVXSource == Yes! RVX Patches source will be changed to anddea.${Reset}"
        break
        ;;
      [Nn]*)
        isChangeRVXSource=0  # ChangeRVXSource: inotia00
        config "ChangeRVXSource" "$isChangeRVXSource"
        echo -e "$good ${Green}ChangeRVXSource == No! RVX Patches source will remain official (inotia00).${Reset}"
        break
        ;;
      *) echo -e "${info} Invalid input! Please enter Y or N." ;;
    esac
  done
}

pat() {
  while true; do
    if { [ -f "$HOME/.config/gh/hosts.yml" ] && ! grep -q "{}" "$HOME/.config/gh/hosts.yml" 2>/dev/null; } || { [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; }; then
      echo -e "${notice} You already have a GitHub token!"
      echo -e "${Yellow}[?] Do you want to delete it? [Y/n]${Reset} \c" && read userInput
      case "$userInput" in
        [Yy]*)
          if { [ -f "$HOME/.config/gh/hosts.yml" ] && ! grep -q "{}" "$HOME/.config/gh/hosts.yml" 2>/dev/null; } || gh auth status 2>/dev/null; then
            gh auth logout  # Logout from gh cli
          elif [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
            jq 'del(.PAT)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete PAT key from simplify.json
            termux-open-url "https://github.com/settings/tokens"
          fi
          echo -e "$good ${Green}Successfully deleted your GitHub token!${Reset}"
          ;;
        [Nn]*) break ;;
        *) echo -e "${info} Invalid input! Please enter Yes or No." ;;
      esac
    else
      echo -e "${Yellow}[?] Do you want to increase the GitHub API rate limit by adding a github token? [Y/n]${Reset} \c" && read userInput
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
                echo -e "$good ${Green}Successfully authenticated with GitHub CLI!${Reset}"
                echo -e "$notice ${Yellow}Your GitHub API rate limit has been increased.${Reset}"
                break
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
                config "PAT" "$pat"
                PAT=$(jq -r '.PAT' "$simplifyJson" 2>/dev/null)
                gh_api_response=$(auth="-H \"Authorization: Bearer $PAT\"" && owner="ReVanced" && repo="revanced-patches" && curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
                if [[ $gh_api_response == v* ]] && [ $gh_api_response != "null" ]; then
                  echo -e "$good ${Green}Successfully added your GitHub PAT!${Reset}"
                  echo -e "$notice ${Yellow}Your GitHub API rate limit has been increased.${Reset}"
                  break
                fi
              else
                echo -e "${bad} ${Red}Invalid PAT! Please try again.${Reset}"
                jq 'del(.PAT)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete PAT key from simplify.json
                termux-open-url "https://github.com/settings/tokens"
              fi
              ;;
            *) echo -e "${info} Invalid input! Please enter gh or pat." ;;
          esac
          ;;
        [Nn]*) break ;;
        *) echo -e "${info} Invalid input! Please enter Yes or No." ;;
      esac
    fi
  done
}

read_patches_file() {
  while true; do
    read -r -p "ReadPatchesFile [E/d]: " opt
    case "$opt" in
      [Ee]*)
        isReadPatchesFile=1  # Enable ReadPatchesFile
        config "ReadPatchesFile" "$isReadPatchesFile"
        echo -e "$good ${Green}ReadPatchesFile is Enabled! Custom PatchesOptions Loading from File.${Reset}"
        break
        ;;
      [Dd]*)
        isReadPatchesFile=0  # Disable ReadPatchesFile
        config "ReadPatchesFile" "$isReadPatchesFile"
        echo -e "$good ${Green}ReadPatchesFile is Disabled! Recommended PatchesOptions Loading from Script.${Reset}"
        break
        ;;
      *) echo -e "${info} Invalid input! Please enter E or D." ;;
    esac
  done
}

change_yt_ytm_app_icon_header() {
  while true; do
    echo -e "G. google_family\nP. pink\nV. vanced_light\nR. revancify_blue\n"
    read -r -p "changeYouTubeYTMusicAppIconHeader [G/P/V/R]: " opt
    case "$opt" in
      [Gg]*)
        branding="google_family"
        config "Branding" "$branding"
        echo -e "$good ${Green}appIconHeader successfully set to google_family!${Reset}"
        break
        ;;
      [Pp]*)
        branding=pink
        config "Branding" "$branding"
        echo -e "$good ${Green}appIconHeader successfully set to pink!${Reset}"
        break
        ;;
      [Vv]*)
        branding="vanced_light"
        config "Branding" "$branding"
        echo -e "$good ${Green}appIconHeader successfully set to vanced_light!${Reset}"
        break
        ;;
      [Rr]*)
        branding="revancify_blue"
        config "Branding" "$branding"
        echo -e "$good ${Green}appIconHeader successfully set to revancify_blue!${Reset}"
        break
        ;;
      *) echo -e "$info Invalid input! Please enter G or P or V or R." ;;
    esac
  done
}

overwriteVersion() {
  if jq -e '.AndroidVersion != null' "$simplifyJson" >/dev/null 2>&1; then
    Android=$(jq -r '.AndroidVersion' "$simplifyJson" 2>/dev/null)  # Get Android version from json
    echo -e "$info Android version spoofed to $Android!"
  else
    echo -e "$info Android version not spoofed yet!"
  fi
  while true; do
    echo -e "${Yellow}Enter the Android version you want to spoof or '0' to disabled spoof: ${Reset}\c" && read spoofVersion
    if [[ $spoofVersion =~ ^[0-9]+$ ]]; then  # Check if the input is a valid version format
      if [ $spoofVersion -eq 0 ]; then
        echo -e "$running Disabling Android version spoofing.."
        jq -e 'del(.AndroidVersion)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete AndroidVersion key from simplify.json
        echo -e "$good ${Green}Android version spoofing disabled successfully!${Reset}"
        break
      elif [ $spoofVersion -lt 4 ]; then
        echo -e "$notice Android version $spoofVersion is not supported by ReVanced patches! Please enter a valid version that is <= 4."
      elif [ $spoofVersion -ge 4 ]; then
        echo -e "$running Spoofing Android version to $spoofVersion.."
        config "AndroidVersion" "$spoofVersion"
        echo -e "$good ${Green}Android version spoofed successfully!${Reset}"
        break
      fi
    else
      echo -e "$info Invalid Android version format! Please enter a valid version."
    fi
  done
}

overwriteArch() {
  if jq -e '.DeviceArch != null' "$simplifyJson" >/dev/null 2>&1; then
    cpuAbi=$(jq -r '.DeviceArch' "$simplifyJson" 2>/dev/null)  # Get Device Architecture from json
    echo -e "$info Device architecture spoofed to $cpuAbi!"
  else
    echo -e "$info Device architecture not spoofed yet!"
  fi
  while true; do
    echo -e "0. Disabled spoofing\n8. arm64-v8a\n7. armeabi-v7a\n4. x86_64\n6. x86\n"
    read -r -p "Select: " arch
    case "$arch" in
      0)
        echo -e "$running Disabling device architecture spoofing.."
        jq -e 'del(.DeviceArch)' "$simplifyJson" > temp.json && mv temp.json "$simplifyJson"  # Delete DeviceArch key from simplify.json
        echo -e "$good ${Green}Device architecture spoofing disabled successfully!${Reset}"
        break
        ;;
      8)
        echo -e "$running Spoofing device architecture to arm64-v8a.."
        config "DeviceArch" "arm64-v8a"
        echo -e "$good ${Green}Device architecture spoofed to arm64-v8a successfully!${Reset}"
        break
        ;;
      7)
        echo -e "$running Spoofing device architecture to armeabi-v7a.."
        config "DeviceArch" "armeabi-v7a"
        echo -e "$good ${Green}Device architecture spoofed to armeabi-v7a successfully!${Reset}"
        break
        ;;
      4)
        echo -e "$running Spoofing device architecture to x86_64.."
        config "DeviceArch" "x86_64"
        echo -e "$good ${Green}Device architecture spoofed to x86_64 successfully!${Reset}"
        break
        ;;
      6)
        echo -e "$running Spoofing device architecture to x86.."
        config "DeviceArch" "x86"
        echo -e "$good ${Green}Device architecture spoofed to x86 successfully!${Reset}"
        break
        ;;
      *) echo -e "$info Invalid input! Please enter 0, 8, 7, 4, 6." ;;
    esac
  done
}

DeletePatchedApk() {
  local nameArr=("YouTube" "YT-Music" "Spotify" "TikTok" "Google Photos" "Instagram" "Facebook" "Facebook Messenger" "Reddit" "X" "Adobe Lightroom Mobile" "Photomath" "Duolingo" "RAR" "Amazon Prime Video" "Twitch" "Tumblr" "Threads" "Strava" "SoundCloud" "Proton Mail" "Calorie Counter MyFitnessPal" "NovaLauncher" "Tasker" "Crunchyroll" "Cricbuzz Cricket Scores and News")
  for app in "${nameArr[@]}"; do
    find "$SimplUsr" -type f -name "${app}-RV*_v[0-9.]*-${cpuAbi}.apk" \
      -exec echo "Deleting: {}" \; \
      -exec rm -f {} \; 2>/dev/null
  done
  echo "Cleanup complete!"
}

DeletePatchLog() {
  local nameArr=("YouTube" "YT-Music" "Spotify" "TikTok" "Google Photos" "Instagram" "Facebook" "Facebook Messenger" "Reddit" "X" "Adobe Lightroom Mobile" "Photomath" "Duolingo" "RAR" "Amazon Prime Video" "Twitch" "Tumblr" "Threads" "Strava" "SoundCloud" "Proton Mail" "Calorie Counter MyFitnessPal" "NovaLauncher" "Tasker" "Crunchyroll" "Cricbuzz Cricket Scores and News")
  for app in "${nameArr[@]}"; do
    find "$SimplUsr" -type f -name "${app}-RV*_patch-log.txt" \
      -exec echo "Deleting: {}" \; \
      -exec rm -f {} \; 2>/dev/null
  done
  echo "Cleanup complete!"
}

UninstallPatchedApp() {
  local pkgArr=(
    "app.revanced.android.youtube"
    "app.rvx.android.youtube"
    "app.rvx.android.apps.youtube.music"
    "com.spotify.music"
    "com.zhiliaoapp.musically"
    "app.revanced.android.photos"
    "com.instagram.android"
    "com.facebook.katana"
    "com.facebook.orca"
    "com.reddit.frontpage"
    "com.twitter.android"
    "com.adobe.lrmobile"
    "com.microblink.photomath"
    "com.duolingo"
    "com.rarlab.rar"
    "com.amazon.avod.thirdpartyclient"
    "tv.twitch.android.app"
    "com.tumblr"
    "com.instagram.barcelona"
    "com.strava"
    "com.soundcloud.android"
    "ch.protonmail.android"
    "com.myfitnesspal.android"
    "com.teslacoilsw.launcher"
    "net.dinglisch.android.taskerm"
    "com.crunchyroll.crunchyroid"
    "com.cricbuzz.android"
  )
  local nameArr=(
    "YouTube RV" "YouTube" "YT Music" "Spotify" "TikTok" "Google Photos" "Instagram" "Facebook" "Facebook Messenger" "Reddit" "X" "Adobe Lightroom Mobile" "Photomath" "Duolingo" "RAR" "Amazon Prime Video" 
    "Twitch" "Tumblr" "Threads" "Strava" "SoundCloud" "Proton Mail" "Calorie Counter MyFitnessPal" "NovaLauncher" "Tasker" "Crunchyroll" "Cricbuzz Cricket Scores and News"
  )
  
  while true; do
    
    # Display menu
    echo "Available apps:"
    for i in "${!nameArr[@]}"; do
      echo "$i. ${nameArr[i]}"
    done

    # Get user input
    read -p "Enter index [0-$(( ${#nameArr[@]} - 1 ))] or 'Q' to quit: " idx
    
    [[ "$idx" =~ [Qq] ]] && break
    
    # Validate and process selection
    if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -lt "${#nameArr[@]}" ]; then
      if su -c "id" >/dev/null 2>&1; then
        echo "Uninstalling: ${nameArr[idx]}"
        if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
          su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
          su -c "pm uninstall --user 0 ${pkgArr[idx]}"
          su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
        else
          su -c "pm uninstall --user 0 ${pkgArr[idx]}"
        fi
      elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
        echo "Uninstalling: ${nameArr[idx]}"
        ~/rish -c "pm uninstall --user 0 ${pkgArr[idx]}"
      else
        echo "Opening App info Activity for: ${nameArr[idx]}"
        am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:"${pkgArr[idx]}" > /dev/null 2>&1
      fi
    else
      echo "Invalid selection! Please enter a number between 0 and $((${#nameArr[@]} - 1))."
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
  echo -e "P. Download Patched App\nR. ReVanced\nX. ReVanced Extended\nT. Piko Twitter\nD. Dropped Patches\nL. LSPatch\nC. Configuration\nM. Miscellaneous\nF. Feature request\nB. Bug report\nS. Support\nA. About\nQ. Quit\n"
  echo -n "Select Patches source: " && read source
  case $source in
    [Pp])
      curl -sL -o "$Simplify/dlPatchedApp.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlPatchedApp.sh"
      bash "$Simplify/dlPatchedApp.sh"
      sleep 3
      ;;
    [Rr])
      curl -sL -o "$RV/RV.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RV.sh"
      bash "$RV/RV.sh"
      sleep 3
      ;;
    [Xx])
      curl -sL -o "$RVX/RVX.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RVX.sh"
      bash "$RVX/RVX.sh"
      sleep 3
      ;;
    [Tt])
      curl -sL -o "$pikoTwitter/pikoTwitter.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/pikoTwitter.sh"
      bash "$pikoTwitter/pikoTwitter.sh"
      sleep 3
      ;;
    [Dd])
      curl -sL -o "$Dropped/droppedPatches.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/droppedPatches.sh"
      bash "$Dropped/droppedPatches.sh"
      sleep 3
      ;;
    [Ll])
      curl -sL -o "$LSPatch/LSPatch.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/LSPatch.sh"
      if su -c "id" >/dev/null 2>&1; then
        curl -sL -o "$Simplify/apkMount.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkMount.sh"
      fi
      bash "$LSPatch/LSPatch.sh"
      sleep 3
      ;;
    [Cc]*)
      while true; do
        FetchPreRelease=$(jq -r '.FetchPreRelease' "$simplifyJson" 2>/dev/null)
        RipLocale="$(jq -r '.RipLocale' "$simplifyJson" 2>/dev/null)"
        RipDpi="$(jq -r '.RipDpi' "$simplifyJson" 2>/dev/null)"
        RipLib="$(jq -r '.RipLib' "$simplifyJson" 2>/dev/null)"
        ChangeRVXSource="$(jq -r '.ChangeRVXSource' "$simplifyJson" 2>/dev/null)"
        ReadPatchesFile="$(jq -r '.ReadPatchesFile' "$simplifyJson" 2>/dev/null)"
        Branding=$(jq -r '.Branding' "$simplifyJson" 2>/dev/null)
        echo -e "P. FetchPreRelease\nL. RipLocale\nD. RipDpi\nR. RipLib\nS. Change RVX Source\nT. Add gh PAT (increases gh api rate limit)\nO. Import Custom PatchesOptions from file\nB. Change YouTube & YT Music AppIcon & Header\nQ. Quit\n"
        read -r -p "Select: " opt
        case "$opt" in
          [Pp]*) if [ "$FetchPreRelease" == 0 ]; then echo "FetchPreRelease == false"; else echo "FetchPreRelease == true"; fi && fetchPreRelease ;;
          [Ll]*) if [ "$RipLocale" == 1 ]; then echo "RipLocale == Enabled"; else echo "RipLocale == Disabled"; fi && ripLocale ;;
          [Dd]*) if [ "$RipDpi" == 1 ]; then echo "RipDpi == Enabled"; else echo "RipDpi == Disabled"; fi && ripDpi ;;
          [Rr]*) if [ "$RipLib" == 1 ]; then echo "RipLib == Enabled"; else echo "RipLib == Disabled"; fi && ripLib ;;
          [Ss]*) if [ "$ChangeRVXSource" == 0 ]; then echo "ChangeRVXSource == No"; else echo "ChangeRVXSource == Yes"; fi && changeRVXSource ;;
          [Tt]*) 
            if { [ -f "$simplifyJson" ] && jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; } || { gh auth status > /dev/null 2>&1 && [ -f "$HOME/.config/gh/hosts.yml" ]; }; then
              if jq -e '.PAT' "$simplifyJson" >/dev/null 2>&1; then
                echo -e "$info ${Green}PAT: ghp_************************************${Reset}"
              else
                echo -e "$info ${Green}oauth_token: gho_************************************${Reset}"
              fi
            else
              echo -e "$notice ${Yellow}No GitHub token found!${Reset}"
            fi
            pat  # Call the pat function to create & add GitHub token
            ;;
          [Oo]*) if [ "$ReadPatchesFile" == 1 ]; then echo "ReadPatchesFile == Enabled"; else echo "ReadPatchesFile == Disabled"; fi && read_patches_file ;;
          [Bb]*) echo "changeYouTubeYTMusicAppIconHeader == $Branding" && change_yt_ytm_app_icon_header ;;
          [Qq]*) break ;;
          *) echo -e "$info Invalid input! Please enter P / L / D / R / S / T / O / B / Q." ;;
        esac
      done
      sleep 3
      ;;
    [Mm]*)
      while true; do
        echo -e "\nV. Spoof Android Version\nA. Spoof Device Architecture\nD. Delete patched apk file\nL. Delete Patch Log\nU. Uninstall Patched Apps\nM. Unmount Patched Apps\nS. Uninstall Simplify\nQ. Quit\n"
        read -r -p "Select: " misc
        case "$misc" in
          [Vv]*) overwriteVersion ;;
          [Aa]*) overwriteArch ;;
          [Dd]*) DeletePatchedApk ;;
          [Ll]*) DeletePatchLog ;;
          [Uu]*) UninstallPatchedApp ;;
          [Mm]*) Unmount && sleep 3 ;;
          [Ss]*)
            echo -ne "${Yellow}Are you sure you want to uninstall Simplify? [Y/n]${Reset}: " && read -r userInput
            case "$userInput" in
              [Yy]*)
                echo -ne "${Red}Type '://' to confirm uninstallation: ${Reset}" && read -r finalInput
                case "$finalInput" in
                  "://")
                    [ -d "$Simplify" ] && rm -rf "$Simplify"
                    [ -d "$SimplUsr" ] && rm -rf "$SimplUsr"
                    [ -f "$HOME/.Simplify.sh" ] && rm -f "$HOME/.Simplify.sh"
                    [ -f "$PREFIX/bin/simplify" ] && rm -f "$PREFIX/bin/simplify"
                    pkgUninstall "aria2"  # aria2 uninstall
                    pkgUninstall "jq"  # jq uninstall
                    pkgUninstall "pup"  # pup uninstall
                    pkgUninstall "openjdk-21"  # java uninstall
                    pkgUninstall "apksigner"  # apksigner uninstall
                    pkgUninstall "bsdtar"  # bsdtar uninstall
                    pkgUninstall "pv"  # pv uninstall
                    pkgUninstall "glow"  # glow uninstall
                    if su -c "id" >/dev/null 2>&1; then
                      if ! pip list 2>/dev/null | grep -q "apksigcopier"; then
                        pip uninstall apksigcopier > /dev/null 2>&1  # uninstall apksigcopier using pip
                      fi
                      pkgUninstall "python"  # python uninstall
                    fi
                    clear
                    echo -e "$good ${Green}Simplify has been uninstalled successfully :(${Reset}"
                    echo -e "💔 ${Blue}We're sorry to see you go. Feel free to reinstall anytime!${Reset}"
                    termux-open-url "https://github.com/arghya339/Simplify/"
                    exit 0
                    ;;
                esac
                ;;
              [Nn]*) echo -e "$notice ${Yellow}Uninstallation cancelled! Simplify will remain installed.${Reset}" ;;
              *) echo -e "$info ${Blue}Invalid input! Uninstallation skipped.${Reset}" ;;
            esac
            ;;
          [Qq]*) break ;;
          *) echo -e "$info Invalid input! Please enter V or A or D or L or U or M or S." ;;
        esac
      done
      sleep 3
      ;;
    [Ff]*) feature && sleep 3 ;;
    [Bb]*) bug && sleep 3 ;;
    [Ss]*) support && sleep 3 ;;
    [Aa]*) about && sleep 3 ;;
    [Qq]*) clear && break ;;
    *) echo -e "$info Invalid input! Please enter: P / R / X / T / D / L / C / M / F / B / S / A / Q" && sleep 3 ;;
  esac
done
####################################################################################################################
