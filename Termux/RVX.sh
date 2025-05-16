#!/usr/bin/bash

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

# Set the color for the eye (green in this case)
Green="\033[92m"
Red="\033[91m"
Blue="\033[94m"
White="\033[37m"
Yellow="\033[93m"
Reset="\033[0m"

# Construct the eye shape using string concatenation
eye=$(cat <<'EOF'
     .------------------------------.
     | ▄▀▀ █ █▄ ▄█ █▀▄ █   █ █▀ ▀▄▀ |
     | ▄██ █ █ ▀ █ █▀  █▄▄ █ █▀  █  |
     |      >_𝒟𝑒𝓋𝑒𝓁𝑜𝓅𝑒𝓇: @𝒶𝓇𝑔𝒽𝓎𝒶𝟥𝟥𝟫 |
     '------------------------------'\n    https://github.com/arghya339/Simplify
EOF
)

<<comment
# Construct the eye shape using string concatenation
eye=$(cat <<'EOF'
 ▄▀▀ █ █▄ ▄█ █▀▄ █   █ █▀ ▀▄▀\n ▄██ █ █ ▀ █ █▀  █▄▄ █ █▀  █\n      >_𝒟𝑒𝓋𝑒𝓁𝑜𝓅𝑒𝓇: @𝒶𝓇𝑔𝒽𝓎𝒶𝟥𝟥𝟫\n https://github.com/arghya339/Simplify
EOF
)
comment

# Apply the eye color to the eye shape and print it
BoldGreen="\033[92;1m"
echo "${BoldGreen}$eye${Reset}"
echo ""  # Space

# Colored log indicators with color codes
echo "--- Colored log indicators ---"
echo "$good - good"
echo "$bad - bad"
echo "$info - info"
echo "$running - running"
echo "$notice - notice"
echo ""  # Space

# --- Permission Check Logic ---
if [ -d "$HOME/storage/shared" ]; then
    echo "${good} Storage permission already granted via Termux API."
else
    # Attempt to list /storage/emulated/0 to trigger the error
    error=$(ls /storage/emulated/0 2>&1)
    expected_error="ls: cannot open directory '/storage/emulated/0': Permission denied"

    if echo "$error" | grep -qF "$expected_error"; then
        echo "${notice} Storage permission not granted. Running termux-setup-storage.."
        termux-setup-storage
        exit 1  # Exit the script after handling the error
    elif echo "$error" | grep -q "^Android"; then
        echo "$good Storage permission already granted via system Settings."
    else
        echo "${bad} Unknown error: $error"
        exit 1  # Exit on any other error
    fi
fi

# --- Checking Internet Connection ---
echo "$running Checking internet Connection.."
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 ; then
  echo "${bad} ${Red} Oops! No Internet Connection available.\nConnect to the Internet and try again later."
  return 1
else
  echo "${good} ${Green}Internet connection is available."
fi

# --- Update Termux pkg ---
# echo "${running} Updating Termux pkg.."
# pkill pkg && { pkg update && pkg upgrade -y; } > /dev/null 2>&1  # discarding output

# --- local Veriable ---
bin="$PREFIX/bin"  # /data/data/com.termux/files/usr/bin dir
InternalStorage="/storage/emulated/0"  # usr Root dir
Download="$InternalStorage/Download"  # Download dir
Simplify="$HOME/Simplify"  # /data/data/com.termux/files/home/Simplify dir
SimplUsr="$InternalStorage/Simplify"  # /storage/emulated/0/Simplify dir
Android=$(getprop ro.build.version.release)  # Get Android version
arch=$(getprop ro.product.cpu.abi)  # Get Android arch
# serial=$(su -c 'getprop ro.serialno')  # Get Serial Number required root
model=$(getprop ro.product.model)  # Get Device Model

# Function to get the DPI category based on density using getprop
get_dp_category() {
    # Get the device screen density using 'getprop ro.sf.lcd_density'
    density=$(getprop ro.sf.lcd_density)
    # Ensure the density value is numeric
    if [ -z "$density" ] || ! echo "$density" | grep -q '^[0-9]\+$'; then
        echo "Unknown DPI Category"
        return
    fi
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
        echo "Unknown DPI Category"
    fi
}
# Get the DPI Category
dp_category=$(get_dp_category)
echo "${info} ${Blue}Device DPI Category:${Reset} $dp_category"
# Get the device language code (e.g., 'en')
language_code=$(getprop persist.sys.locale | cut -d'-' -f1)
echo "${info} ${Blue}Device Language Code:${Reset} $language_code"

echo "${info} ${Blue}Target device:${Reset} $model"  # $serial

# Colored prompt function
Write_ColoredPrompt() {
    local message="$1"
    local color="$2"
    local prompt_message="$3"
    
    local color_code reset_code
    reset_code=$(printf '\033[0m')
    
    case "$color" in
        red) color_code=$(printf '\033[31m') ;;
        green) color_code=$(printf '\033[32m') ;;
        yellow) color_code=$(printf '\033[33m') ;;
        blue) color_code=$(printf '\033[34m') ;;
        *) color_code="$reset_code" ;;
    esac

    printf "%s%s %s%s" "$color_code" "$message" "$prompt_message" "$reset_code" >&2
    read -r input
    printf "%s" "$input"
}
question_mark="[?]"

# --- Checking Android Version ---
echo "${running} Checking Android Version.."
if [ $Android -le 4 ]; then
  echo "${bad} ${Red}Android $Android is not supported by RVX Patches.${Reset}"
  return 1
else
  echo "${good} ${Green}This device compatible with RVX Patches.${Reset}"
fi

pkill apt  # Forcefully kill apt process
pkill dpkg && sleep 0.5 && yes | dpkg --configure -a && dpkg --configure -a # Forcefully kill dpkg process and configure dpkg

upgrade_apt() {
    if apt list --upgradable 2>/dev/null | grep -q "^apt/"; then
        echo "$running Upgrading apt.."
        pkg upgrade apt -y > /dev/null 2>&1
    fi
}

upgrade_bash() {
    if apt list --upgradable 2>/dev/null | grep -q "^bash/"; then
        echo "$running Upgrading bash.."
        pkg upgrade bash -y > /dev/null 2>&1
    fi
}

upgrade_dpkg() {
    if apt list --upgradable 2>/dev/null | grep -q "^dpkg/"; then
        echo "$running Upgrading dpkg.."
        pkg upgrade dpkg -y > /dev/null 2>&1
        pkill dpkg && yes | dpkg --configure -a && dpkg --configure -a  # Forcefully kill dpkg process and configure dpkg
    fi
}

upgrade_termux_tools() {
    if apt list --upgradable 2>/dev/null | grep -q "^termux-tools/"; then
        echo "$running Upgrading termux-tools.."
        pkg upgrade termux-tools -y > /dev/null 2>&1
    fi
}

upgrade_libcpp() {
    if apt list --upgradable 2>/dev/null | grep -q "^libc++/"; then
        echo "$running Upgrading libc++.."
        pkg upgrade libc++ -y > /dev/null 2>&1
    fi
}

# upgrade some Termux pkg if outdated
echo "${running} Updating Termux pkg.."
pkill pkg && pkg update > /dev/null 2>&1
upgrade_apt && upgrade_bash && upgrade_dpkg && upgrade_termux_tools && upgrade_libcpp

# --- Setup java 17 ---
if [ ! -f $bin/java ]; then
  echo "${running} Setup java 17 Runtime Environment.."
  pkg install openjdk-17 -y > /dev/null 2>&1
else
  echo "${good} java is already installed."
  java -version 2>&1 | head -n 1
fi

# --- Install apksigner for Signing apk ---
if [ ! -f $bin/apksigner ]; then
  echo "${running} installing apksigner for Signing apk.."
  pkg install apksigner -y > /dev/null 2>&1
else
  echo "${good} apksigner is already installed."
  as_v=$(apksigner version) && echo "apksigner $as_v"
fi

# --- Check if 'jq' is installed ---
if ! command jq -V >/dev/null 2>&1 ; then
  echo "${running} installing jq for extrcting json data from github api"
  # install json query for extrcting json data
  pkg install jq -y > /dev/null 2>&1
else
  echo "${good} jq is already installed."
  jq -V
fi

# openssl absolutely required because Python in Termux was compiled without SSL support.
if apt list --upgradable 2>/dev/null | grep -q "^openssl/"; then
  echo "$running Upgrading OpenSSL.."
  pkg upgrade openssl -y > /dev/null 2>&1
elif ! pkg list-installed 2>/dev/null | grep -q '^openssl/' > /dev/null 2>&1; then
  echo "$running openssl not found. Installing.."
  pkg install openssl -y > /dev/null 2>&1
else
  echo "$good openssl is already installed"
  echo "OpenSSL $(dpkg -s openssl | grep Version | awk '{print $2}')"
fi

# libffi is a library that allows programs to call functions from other libraries at runtime.
if ! pkg list-installed 2>/dev/null | grep -q '^libffi/'; then
  echo "$running libffi not found. Installing.."
  pkg install libffi -y > /dev/null 2>&1
else
  echo "$good libffi is already installed"
  echo "libfii $(dpkg -s libffi | grep Version | awk '{print $2}')"
fi

# --- Check if python is installed ---
if ! command python --version >/dev/null 2>&1 ; then
  echo "${running} installing python for downloading stock apk by extrcting data form patches.json"
  pkg install python -y > /dev/null 2>&1
# Install requests library using Python package installer (pip) that comes with Python pkg
  pip install requests > /dev/null 2>&1
else
  echo "${good} python is already installed."
  python --version
fi

# --- Check if wget is installed ---
if [ ! -f $bin/wget ]; then
  echo "${running} installing wget for downloading file"
  pkg install wget -y > /dev/null 2>&1
else
  echo "${good} wget is already installed."
  wget --version | grep "^GNU Wget"
fi

# --- Check if curl is installed ---
if apt list --upgradable 2>/dev/null | grep -q "^curl/"; then
  echo "$running Upgrading curl.."
  pkg upgrade curl libcurl -y > /dev/null 2>&1
elif [ ! -f $bin/curl ]; then
  echo "${running} installing curl"
  pkg install curl -y > /dev/null 2>&1
else
  echo "${good} curl is already installed."
  curl -V | grep "^curl"
fi

# --- Check if grep is installed ---
if [ ! -f $bin/grep ]; then
  echo "${running} installing grep"
  pkg install grep -y > /dev/null 2>&1
else
  echo "${good} grep is already installed."
  grep -V | grep "^grep ("
fi

# Download RVX_dl Python script for dynamically download stock apk from GitHub
if [ ! -f "$Simplify/RVX_dl.py" ]; then
  echo "${running} Downloading RVX_dl.py from GitHub.."
  wget "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RVX_dl.py" -O "$Simplify/RVX_dl.py" 2>&1 | grep -E 'Simplify|100%|saved'
fi

# --- Create $Simplify and $SimplUsr dir if it does't exist ---
mkdir -p "$SimplUsr" "$Simplify"

# --- Change Termux $HOME dir to $Simplify dir ---
cd "$Simplify"

# --- Download Custom aapt2 binary for Android ---
sed -i '/allow-external-apps/s/# //' "$HOME/.termux/termux.properties"
# Ensure aapt2 exist in $Simplify directory if not download it & save as aapt2
if [ ! -f "$Simplify/aapt2" ]; then
  echo "${running} Downloading Custom aapt2 binary for compile apk.."
  wget "https://github.com/arghya339/aapt2/releases/download/all/aapt2_$arch" -O "$Simplify/aapt2" 2>&1 | grep -E 'binaries|100%|saved'
  chmod +x "$Simplify/aapt2" && "$Simplify/aapt2" version
else
  echo "${good} Custom aapt2 bin already exist in $Simplify dir."
  # this will set the aapt2 binary executable (--x) permissions..
  # Ensure the binary has executable permissions by checking aapt2 version
  "$Simplify/aapt2" version
fi
  
# --- Create a ks.keystore for Signing apk ---
if [ ! -f "$Simplify/ks.keystore" ]; then
  echo "${running} Create a 'ks.keystore' for Signing apk.."
  keytool -genkey -v -storetype pkcs12 -keystore ks.keystore -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456
else
  echo "${good} 'ks.keystore' already exist in $Simplify dir."
fi

# --- Function to download and cleanup files ---
# Download the latest file
# Correctly identify lower version number with file as an older version.
# Remove older version file from your storage.
# Download microg.apk and save it as microg-${tag_name}.apk.
download_and_cleanup() {
  local repo_url=$1
  local file_pattern=$2
  local file_extension=$3

  # Fetch download URL and latest file name
  local download_url=$(curl -s "$repo_url" | \
    jq --arg pattern "$file_pattern" -r '.assets[] | select(.name | test($pattern)).browser_download_url')
  local latest_filename=$(curl -s "$repo_url" | \
    jq --arg pattern "$file_pattern" -r '.assets[] | select(.name | test($pattern)).name')

  # Ensure latest file name and download URL are valid
  if [ -z "$latest_filename" ] || [ -z "$download_url" ]; then
    echo "${bad} Error: Could not find a matching file for pattern '$file_pattern'."
    return 1
  fi

  # --- Handle MicroG differently ---
  if echo "$file_pattern" | grep -q "microg.apk"; then
    local tag_name=$(curl -s "$repo_url" | jq -r '.tag_name')
    local filename_with_tag="microg-${tag_name}.apk"

    if [ -f "$filename_with_tag" ]; then
      echo "${info} $filename_with_tag already exists. Skipping download."
    else
      echo "${running} Downloading latest version: $latest_filename (as $filename_with_tag)"
      curl -L "$download_url" -o "$filename_with_tag"

      # Remove older versions of MicroG
      find . -maxdepth 1 -name "microg-*.apk" ! -name "$filename_with_tag" -type f -exec echo "${running} Removing older version: {}" \; -exec rm {} \;
    fi

  # --- Handle Other Files Normally ---
  else
    if [ -f "$latest_filename" ]; then
      echo "${info} File '$latest_filename' already exists. Skipping download."
    else
      echo "${running} Downloading latest version: $latest_filename"
      curl -L "$download_url" -o "$latest_filename"

      echo "${running} Cleaning up older versions.."

      # Extract the base name and version from latest_filename
      local base_name="${latest_filename%_*}"  # Extract part before "_"
      local latest_version="${latest_filename#*_}"  # Extract part after "_"
      latest_version="${latest_version%.*}"  # Remove extension

      # Find and remove files with lower versions (including CLI)
      find . -maxdepth 1 \( -name "$base_name*.rvp" -o -name "$base_name*.jar" \) -type f -print0 | while IFS= read -r -d $'\0' file; do
        local version="${file#*_}"
        version="${version%.*}"
        if [ "$version" != "$latest_version" ]; then
          echo "${running} Removing older version: $file"
          rm "$file"
        fi
      done
    fi
  fi
}

# --- Architecture Detection (dash-compatible) ---
all_arch="arm64-v8a armeabi-v7a x86_64 x86"  # Space-separated list instead of array
# Generate ripLib arguments for all ABIs EXCEPT the detected one
ripLib=""
for current_arch in $all_arch; do
    if [ "$current_arch" != "$arch" ]; then
        if [ -z "$ripLib" ]; then
            ripLib="--rip-lib=$current_arch"  # No leading space for first item
        else
            ripLib="$ripLib --rip-lib=$current_arch"  # Add space for subsequent items
        fi
    fi
done
# Display the final ripLib arguments
echo "${info} ${Blue}arch:${Reset} $arch"
echo "${info} ${Blue}ripLib:${Reset} $ripLib"

# --- Download and generate patches.json ---
if [ $Android -ge 5 ]; then 
    # --- ReVanced Extended CLI ---
    download_and_cleanup "https://api.github.com/repos/inotia00/revanced-cli/releases/latest" \
        "revanced-cli-[0-9]+\\.[0-9]+\\.[0-9]+-all\\.jar" \
        "jar"

    # --- ReVanced Extended Patches ---
    download_and_cleanup "https://api.github.com/repos/inotia00/revanced-patches/releases/latest" \
        "patches-[0-9]+\\.[0-9]+\\.[0-9]+\\.rvp" \
        "rvp"

    # --- VancedMicroG ---
    download_and_cleanup "https://api.github.com/repos/inotia00/VancedMicroG/releases/latest" \
        "microg.apk" \
        "apk"
    
    # --- APKEditor ---
    download_and_cleanup "https://api.github.com/repos/REAndroid/APKEditor/releases/latest" \
        "APKEditor-[0-9]+\\.[0-9]+\\.[0-9]+\\.jar" \
        "jar"
    
    ReVancedCLIJar=$(find "$Simplify" -type f -name "revanced-cli-*-all.jar" -print -quit)
    PatchesRvp=$(find "$Simplify" -type f -name "patches-*.rvp" -print -quit)
    VancedMicroG=$(find "$Simplify" -type f -name "microg-*.apk" -print -quit)
    APKEditor=$(find "$Simplify" -type f -name "APKEditor-*.jar" -print -quit)
    
    ReVancedCLIJar_Path=$(realpath "$ReVancedCLIJar")
    PatchesRvp_Path=$(realpath "$PatchesRvp")
    VancedMicroG_Path=$(realpath "$VancedMicroG")
    APKEditor_Path=$(realpath "$APKEditor")
    
    echo "$info ${Blue}ReVancedCLIJar:${Reset} $ReVancedCLIJar_Path"
    echo "$info ${Blue}PatchesRvp:${Reset} $PatchesRvp_Path"
    echo "$info ${Blue}VancedMicroG:${Reset} $VancedMicroG_Path"
    echo "$info ${Blue}APKEditor:${Reset} $APKEditor_Path"
    
    # --- Generate patches.json file --- 
    if [ ! -f "$Simplify/patches.json" ] && [ $Android -ge 8 ]; then
        echo "${running} patches.json does't exist, genertating patches.json"
        java -jar $ReVancedCLIJar_Path patches $PatchesRvp_Path
    elif command java -jar $Simplify/revanced-cli-*-all.jar patches $Simplify/patches-*.rvp && [ $Android -ge 8 ]; then
        echo "${info} patches.json generated successfully!"
    elif [ -f "$Simplify/patches.json" ] && [ $Android -ge 8 ]; then
        echo "${good} patches.json exist in $Simplify dir."
    elif ! command java -jar $ReVancedCLIJar_Path patches $PatchesRvp_Path && [ $Android -ge 8 ] && [ ! -f "$Simplify/patches.json" ]; then
        echo "${bad} Error: patches.json was not generated."
    fi

    <<comment
    # --- Download revanced-extended-options.json ---
    if [ ! -f "$SimplUsr/rvx-options.json" ] && [ -f $ReVancedCLIJar_Path ] && [ -f $PatchesRvp_Path ] && [ $Android -ge 5 ]; then
      echo "${running} Downloading revanced-extended-options.json from GitHub.."
      wget "https://github.com/arghya339/Simplify/releases/download/all/rvx-options.json" -O "$SimplUsr/rvx-options.json" 2>&1 | grep -E 'Simplify|100%|saved'
    elif [ -f "$SimplUsr/rvx-options.json" ] && [ $Android -ge 8 ]; then
      echo "${good} rvx-options.json already exist in $SimplUsr dir."
    # Supported app icon: google_family, pink, revancify_blue, vanced_light
    fi
comment
  
    # --- Download branding.zip ---
    if [ ! -d "$SimplUsr/branding" ] && [ ! -f "$SimplUsr/branding.zip" ] && [ -f $PatchesRvp_Path ] && [ $Android -ge 5 ]; then
      echo "${running} Downloading branding.zip from GitHub.."
      wget "https://github.com/arghya339/Simplify/releases/download/all/branding.zip" -O "$SimplUsr/branding.zip" 2>&1 | grep -E 'Simplify|100%|saved'
    fi
    
    # --- installing un zip ---
    if [ ! -f "$bin/unzip" ] && [ -f "$SimplUsr/branding.zip" ] && [ $Android -ge 5 ]; then
      echo "${running} installing unzip pkg.."
      pkg install unzip -y
    elif [ -f "$bin/unzip" ] && [ $Android -ge 8 ]; then
      echo "${good} unzip pkg is already installed."
      uz_v=$(unzip -v | awk 'NR==1 {print $2}') && echo "unzip $uz_v"  # print second field of first Iine
    fi
    
    # --- Extrct branding.zip ---
    if [ -f "$SimplUsr/branding.zip" ] && [ ! -d "$SimplUsr/branding" ] && [ $Android -ge 5 ]; then
      echo "${running} Extrcting branding.zip to $SimplUsr dir.."
      # unzip program extract zip files in following flgs. one `o` this flag use to  overwrites any existing files without usr prompting, and other `d` this flag use to  specifies the destination directory for the extracted files.
      unzip -o "$SimplUsr/branding.zip" -d "$SimplUsr/branding/" > /dev/null 2>&1
    elif [ -d "$SimplUsr/branding" ] && [ $Android -ge 8 ]; then
      echo "${good} branding dir already exist in $SimplUsr dir.."
    fi
    # --- Remove branding.zip ---
    if [ -d "$SimplUsr/branding" ] && [ -f "$SimplUsr/branding.zip" ] && [ $Android -ge 8 ]; then  
      echo "${running} removing branding.zip.."
      rm "$SimplUsr/branding.zip"
    fi

    # --- Download stock APKs from GitHub using python by extracting data from patches.json file ---
    if [ $Android -ge 8 ]; then
      if [ -f "$Simplify/patches.json" ] && [ $Android -ge 8 ]; then
        echo "${running} Checking for required stock APKs for patching.."
        python "$Simplify/RVX_dl.py"
        # Recheck after downloading
        downloaded_youtube_apk=$(find "$Download" -type f -name "com.google.android.youtube*.apk" -print -quit)
        downloaded_yt_music_apk=$(find "$Download" -type f -name "com.google.android.apps.youtube.music*.apk" -print -quit)
        downloaded_reddit_apk=$(find "$Download" -type f -name "com.reddit.frontpage*apkm" -print -quit)
      fi

      # Check if APKs were successfully located or downloaded
      if [ -z "$downloaded_youtube_apk" ] || [ -z "$downloaded_yt_music_apk" ] && [ $Android -ge 8 ]; then
        echo "${bad} Error: Failed to locate or download one or more APK files. Please check the logs."
        exit 1
      fi

      # --- Get the absolute paths ---
      youtube_apk_path=$(realpath "$downloaded_youtube_apk")
      yt_music_apk_path=$(realpath "$downloaded_yt_music_apk")
      reddit_apk_path=$(realpath "$downloaded_reddit_apk")

      echo "${good} ${Green}YouTube APK:${Reset} $youtube_apk_path"
      echo "${good} ${Green}YouTube Music APK:${Reset} $yt_music_apk_path"
      echo "${good} ${Green}Reddit APK:${Reset} $reddit_apk_path"

      # --- Get the versions from the filenames ---
      youtube_version=$(echo "$downloaded_youtube_apk" | awk -F '_' '{print $2}' | awk -F '.apk' '{print $1}')
      yt_music_version=$(echo "$downloaded_yt_music_apk" | awk -F '_' '{print $2}' | awk -F '-' '{print $1}')
      reddit_version=$(echo "$downloaded_reddit_apk" | awk -F '_' '{print $2}' | awk -F '.apkm' '{print $1}')

      echo "${info} ${Blue}YouTube version:${Reset} $youtube_version"
      echo "${info} ${Blue}YouTube Music version:${Reset} $yt_music_version"
      echo "${info} ${Blue}Reddit version:${Reset} $reddit_version"
    fi
    
    # --- YouTube & YouTube Music RVX Android 8 and up ---
    if [ $Android -ge 8 ]; then
      # --- YouTube RVX ---
      if [ ! "$youtube_apk_path" = *"Error downloading"* ] && [ -f "$youtube_apk_path" ] && [ $Android -ge 8 ]; then
        echo "${good} ${Green}Downloaded YouTube APK found:${Reset} $youtube_apk_path"
        # --- Execute ReVanced patching for YouTube ---
        echo "${running} Patching YouTube RVX.."
        java -jar $ReVancedCLIJar_Path patch -p $PatchesRvp_Path \
          -o "$Simplify/youtube-revanced-extended_$youtube_version-$arch.apk" $youtube_apk_path \
          -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
          -e "Custom Shorts action buttons" -OiconType="round" \
          -e "Custom branding icon for YouTube" -OappIcon="/storage/emulated/0/Simplify/branding/youtube/launcher/google_family" \
          -e "Custom header for YouTube" -OcustomHeader="/storage/emulated/0/Simplify/branding/youtube/header/google_family" \
          -e "Custom branding name for YouTube" -OappName="YouTube RVX" \
          -e "Hide shortcuts" -Oshorts=false \
          -e "Overlay buttons" -OiconType=thin \
          -e "Custom header for YouTube" -e "Force hide player buttons background" -e=MaterialYou \
          -e="Return YouTube Username" --custom-aapt2-binary="$Simplify/aapt2" \
          --purge $ripLib --unsigned -f | tee "$SimplUsr/yt-rvx-patch_log.txt"
          # --legacy-options "$SimplUsr/rvx-options.json" \
        if [ -d "$Simplify/youtube-revanced-extended_$youtube_version-$arch-temporary-files" ]; then
          rm -rf "$Simplify/youtube-revanced-extended_$youtube_version-$arch-temporary-files"
        fi
      elif [ ! -f "$Simplify/youtube-revanced-extended_$youtube_version-$arch.apk" ] && [ -f $youtube_apk_path ] && [ $Android -ge 8 ]; then
        echo "${bad} Oops, YouTube Patching failed !! Logs saved to "$SimplUsr/yt-rvx-patch_log.txt". Share the Patchlog to developer."
        
        {
          # Read log file silently
          yt_log=$(cat "$SimplUsr/yt-rvx-patch_log.txt" 2>/dev/null)
  
          # URL-encode critical characters (improved encoding)
          yt_log_encoded=$(printf "%s" "$yt_log" | sed \
            -e 's/ /%20/g' \
            -e 's/\n/%0A/g' \
            -e 's/:/%3A/g' \
            -e 's/\//%2F/g' \
            -e 's/\[/%5B/g' \
            -e 's/\]/%5D/g' \
            -e 's/\?/%3F/g' \
            -e 's/&/%26/g' \
            -e 's/=/%3D/g')
          
          # URL-encode space characters for $model
          model_encoded=$(printf "%s" "$model" | sed -e 's/ /%20g')

          # Open URL silently
          termux-open-url "https://github.com/inotia00/ReVanced_Extended/issues/new?title=bug:%20Patching%20Failed&body=**Type**%3A%0A-%20Error%20while%20patching%0A%0A**Tools%20used**%3A%0A-%20Simplify%20Android%0A%0A**Application**%3A%0AYouTube%20v${youtube_version}%0A%0A**Bug%20description**%3A%0APatching%20fails%20with%20...%0A%0A**Error%20logs**%3A%0A${yt_log_encoded}%0A%0A**Device%20Environment**%3A%0AAndroid%20${Android}%2C%20${model_encoded}"
        } >/dev/null 2>&1
        
      fi
      # --- Signing YouTube RVX ---
      if [ -f "$Simplify/youtube-revanced-extended_$youtube_version-$arch.apk" ] && [ $Android -ge 8 ]; then
        echo "${running} Signing YouTube RVX.."
        apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk" "$Simplify/youtube-revanced-extended_$youtube_version-$arch.apk"
      fi
      # After Signing complete delete 'yt-revanced-extended-signed_$youtube_version-$arch.apk.idsig' & unsigned yt-revanced-extended_$youtube_version-$arch.apk file.
      if [ -f "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk" ] && [ $Android -ge 8 ]; then
        rm "$Simplify/youtube-revanced-extended_$youtube_version-$arch.apk" && rm "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk.idsig" 
      # Add YouTube Signing failed detection logic
      elif [ ! -f "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk" ] && [ $Android -ge 8 ]; then 
        echo "${bad} Oops, YouTube RVX Signing failed !!"
      fi
      # --- Verify sinature info ---
      if [ -f "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk" ] && [ $Android -ge 8 ]; then
        echo "${running} Verify YouTube RVX APK Signature info.."
        apksigner verify -v --print-certs "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk" | grep "Signer .* certificate DN"
      fi
      # --- Open the APK file with the Termux default package installer ---
      if [ -f "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk" ] && [ -f "$VancedMicroG_Path" ] && [ $Android -ge 8 ]; then
        echo "${info} VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
        # Prompt for user choice on installing the VancedMicroG apk
        echo "$question ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Installing VancedMicroG apk.."
            termux-open "$VancedMicroG_Path"
            ;;
          n*|N*) echo "$notice VancedMicroG Installaion skipped." ;;
          *) echo "$info Invalid choice. VancedMicroG Installaion skipped." ;;
        esac
      fi
      if [ -f "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk" ] && [ -f "$VancedMicroG_Path" ] && [ $Android -ge 8 ]; then
        # Prompt for user choice on installing the patched YouTube RVX apk
        echo "$question ${Yellow}Do you want to install YouTube RVX app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Installing Patched YouTube RVX apk.."
            termux-open "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk"
            ;;
          n*|N*) echo "$notice YouTube RVX Installaion skipped." ;;
          *) echo "$info Invalid choice. YouTube RVX Installaion skipped." ;;
        esac
      fi
      if [ -f "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk" ] && [ $Android -ge 8 ]; then
        # Prompt for user choice on shareing the patched YouTube RVX apk
        echo "$question ${Yellow}Do you want to Share YouTube RVX app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Sharing Patched YouTube RVX apk.."
            termux-open --send "$SimplUsr/youtube-revanced-extended-signed_$youtube_version-$arch.apk"
            ;;
          n*|N*) echo "$notice YouTube RVX Sharing skipped."
            echo "${info} Locate 'youtube-revanced-extended-signed_$youtube_version-$arch.apk' in '$SimplUsr' dir, Share it with your Friends and Family ;)"
            ;;
          *) echo "$info Invalid choice. YouTube RVX Sharing skipped." ;;
        esac
      fi

      # --- YouTube Music RVX ---
      if [ ! "$yt_music_apk_path" = *"Error downloading"* ] && [ -f "$yt_music_apk_path" ] && [ $Android -ge 8 ]; then
        echo "${good} ${Green}Downloaded YouTube Music APK found:${Reset} $yt_music_apk_path"
        # --- Execute ReVanced patching for YouTube Music ---
        echo "${running} Patching YT Music RVX.."
        java -jar $ReVancedCLIJar_Path patch -p $PatchesRvp_Path \
          -o $Simplify/yt-music-revanced-extended_$yt_music_version-$arch.apk $yt_music_apk_path \
          -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
          -e "Custom branding icon for YouTube Music" -OappIcon="/storage/emulated/0/Simplify/branding/music/launcher/google_family" \
          -e "Custom header for YouTube Music" -OcustomHeader="/storage/emulated/0/Simplify/branding/music/header/google_family" \
          -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" \
          -e "Dark theme" -OmaterialYou=true \
          -e "Custom header for YouTube Music" -e="Return YouTube Username" --custom-aapt2-binary="$Simplify/aapt2" \
          --purge --unsigned -f | tee "$SimplUsr/ytm-rvx-patch_log.txt"
          # --legacy-options $SimplUsr/rvx-options.json \
        if [ -d "$Simplify/yt-music-revanced-extended_$yt_music_version-$arch-temporary-files" ]; then
          rm -rf "$Simplify/yt-music-revanced-extended_$yt_music_version-$arch-temporary-files"
        fi
      elif [ ! -f "$Simplify/yt-music-revanced-extended_$yt_music_version-$arch.apk" ] && [ -f $yt_music_apk_path ] && [ $Android -ge 8 ]; then
        echo "${bad} Oops, YouTube Music Patching failed !! Logs saved to "$SimplUsr/ytm-rvx-patch_log.txt". Share the Patchlog to developer."
      fi
      # --- Signing YT Music ---
      if [ -f "$Simplify/yt-music-revanced-extended_$yt_music_version-$arch.apk" ] && [ $Android -ge 8 ]; then
        echo "${running} Signing YT Music RVX.."
        apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk" "$Simplify/yt-music-revanced-extended_$yt_music_version-$arch.apk"
      # Add YT Music Signing failed detection logic
      elif [ ! -f "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk" ] && [ $Android -ge 8 ]; then
        echo "${bad} Oops, YT Music RVX Signing failed !!"
      fi
      # After Signing complete delete 'yt-music-revanced-extended-signed_$yt_music_version-$arch.apk.idsig' & unsigned yt-music-revanced-extended_$yt_music_version-$arch.apk file.
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk" ] && [ $Android -ge 8 ]; then
        rm "$Simplify/yt-music-revanced-extended_$yt_music_version-$arch.apk" && rm "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk.idsig"
      fi
      # --- Verify sinature info ---
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk" ] && [ $Android -ge 8 ]; then
        echo "${running} Verify Signature info.."
        apksigner verify -v --print-certs "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk" | grep "Signer .* certificate DN"
      fi
      # --- Open the APK file with the Termux default package installer ---
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk" ] && [ -f "$VancedMicroG_Path" ] && [ $Android -ge 8 ]; then
        echo "${info} VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
        # Prompt for user choice on installing the VancedMicroG apk
        echo "$question ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Installing VancedMicroG apk.."
            termux-open "$VancedMicroG_Path"
            ;;
          n*|N*) echo "$notice VancedMicroG Installaion skipped." ;;
          *) echo "$info Invalid choice. VancedMicroG Installaion skipped." ;;
        esac
      fi
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk" ] && [ -f "$VancedMicroG_Path" ] && [ $Android -ge 8 ]; then
        # Prompt for user choice on installing the patched YT Music RVX apk
        echo "$question ${Yellow}Do you want to install YT Music RVX app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Installing Patched YT Music RVX apk.."
            termux-open "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk"
            ;;
          n*|N*) echo "$notice YT Music RVX Installaion skipped." ;;
          *) echo "$info Invalid choice. YT Music RVX Installaion skipped." ;;
        esac
      fi
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk" ] && [ $Android -ge 8 ]; then
        # Prompt for user choice on shareing the patched YT Music RVX apk
        echo "$question ${Yellow}Do you want to Share YT Music RVX app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Sharing Patched YT Music RVX apk.."
            termux-open --send "$SimplUsr/yt-music-revanced-extended-signed_$yt_music_version-$arch.apk"
            ;;
          n*|N*) echo "$notice YT Music RVX Sharing skipped."
            echo "${info} Locate 'yt-music-revanced-extended-signed_$yt_music_version-$arch.apk' in '$SimplUsr' dir, Share it with your Friends and Family ;)"
            ;;
          *) echo "$info Invalid choice. YT Music RVX Sharing skipped." ;;
        esac
      fi

    else
      echo "${info} Skipped: Latest YouTube and YT Music not compatible with Android $Android"
    fi

    # --- YouTube Music RVX Android 7 ---
    # --- Download and generate patches.json ---
    if [ $Android -eq 7 ]; then
      # --- Download TY Music_6.42.55.apk from GitHub ---
      if [ ! -f "$Download/com.google.android.apps.youtube.music_6.42.55-$arch.apk" ]; then
        echo "${running} Downloading YT Music 6.42.55 apk from github.."
        wget "https://github.com/arghya339/Simplify/releases/download/all/com.google.android.apps.youtube.music_6.42.55-$arch.apk" -O "$Download/com.google.android.apps.youtube.music_6.42.55-$arch.apk" 2>&1 | grep -E 'Simplify|100%|saved'
      fi
      if [ -f "$Download/com.google.android.apps.youtube.music_6.42.55-$arch.apk" ]; then
        echo "${good} ${Green}Downloaded YT Music 6.42.55 found:${Reset} $Download/com.google.android.apps.youtube.music_6.42.55-$arch.apk"
        echo "$running Patching YT Music 6.42.55.."
        java -jar $ReVancedCLIJar_Path patch -p $PatchesRvp_Path \
          -o "$Simplify/yt-music-revanced-extended_6.42.55-$arch.apk" "$Download/com.google.android.apps.youtube.music_6.42.55-$arch.apk" \
          -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
          -e "Custom branding icon for YouTube Music" -OappIcon="/storage/emulated/0/Simplify/branding/music/launcher/google_family" \
          -e "Custom header for YouTube Music" -OcustomHeader="/storage/emulated/0/Simplify/branding/music/header/google_family" \
          -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" \
          -e "Dark theme" -OmaterialYou=true \
          -e "Custom header for YouTube Music" -e="Return YouTube Username" --custom-aapt2-binary="$Simplify/aapt2" \
          --purge --unsigned -f | tee "$SimplUsr/ytm-rvx-patch_log.txt"
          # --legacy-options "$SimplUsr/rvx-options.json" \
        if [ -d "$Simplify/yt-music-revanced-extended_6.42.55-$arch-temporary-files" ]; then
          rm -rf "$Simplify/yt-music-revanced-extended_6.42.55-$arch-temporary-files"
        fi
      elif [ ! -f "$Simplify/yt-music-revanced-extended_6.42.55-$arch.apk" ]; then
        echo "${bad} Oops, YouTube Music 6.42.55 Patching failed !! Logs saved to $SimplUsr/ytm-rvx-patch_log.txt. Share the Patchlog to developer."
      fi
      # --- Signing YT Music ---
      if [ -f "$Simplify/yt-music-revanced-extended_6.42.55-$arch.apk" ]; then
        echo "$running Signing YT Music RVX 6.42.55.."
        apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk" "$Simplify/yt-music-revanced-extended_6.42.55-$arch.apk"
      # Add YT Music Signing failed detection logic
      elif [ ! -f "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk" ]; then
        echo "${bad} Oops, YT Music RVX 6.42.55 Signing failed !!"
      fi
      # After Signing complete delete 'yt-music-revanced-extended-signed_6.42.55-$arch.apk.idsig' & unsigned yt-music-revanced-extended_6.42.55-$arch.apk file.
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk" ]; then
        rm "$Simplify/yt-music-revanced-extended_6.42.55-$arch.apk" && rm "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk.idsig"
      fi
      # --- Verify sinature info ---
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk" ]; then
        echo "${running} Verify YT Music RVX 6.42.55 APK Signature info.."
        apksigner verify -v --print-certs "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk" | grep "Signer .* certificate DN"
      fi
      # --- Open the APK file with the Termux default package installer ---
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk" ] && [ -f $VancedMicroG_Path ]; then
        echo "${info} VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
        # Prompt for user choice on installing the VancedMicroG apk
        echo "$question ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Installing VancedMicroG apk.."
            termux-open "$VancedMicroG_Path"
            ;;
          n*|N*) echo "$notice VancedMicroG Installaion skipped." ;;
          *) echo "$info Invalid choice. VancedMicroG Installaion skipped." ;;
        esac
      fi
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk" ] && [ -f "$VancedMicroG_Path" ]; then
        # Prompt for user choice on installing the patched YT Music RVX apk
        echo "$question ${Yellow}Do you want to install YT Music RVX 6.42.55 app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Installing Patched YT Music RVX 6.42.55 apk.."
            termux-open "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk"
            ;;
          n*|N*) echo "$notice YT Music RVX 6.42.55 Installaion skipped." ;;
          *) echo "$info Invalid choice. YT Music RVX 6.42.55 Installaion skipped." ;;
        esac
      fi
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk" ]; then
        # Prompt for user choice on shareing the patched YT Music RVX apk
        echo "$question ${Yellow}Do you want to Share YT Music RVX 6.42.55 app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Sharing Patched YT Music RVX 6.42.55 apk.."
            termux-open --send "$SimplUsr/yt-music-revanced-extended-signed_6.42.55-$arch.apk"
            ;;
          n*|N*) echo "$notice YT Music RVX 6.42.55 Sharing skipped."
            echo "${info} Locate 'yt-music-revanced-extended-signed_6.42.55-$arch.apk' in '$SimplUsr' dir, Share it with your Friends and Family ;)"
            ;;
          *) echo "$info Invalid choice. YT Music RVX 6.42.55 Sharing skipped." ;;
        esac
      fi
    else
      echo "${info} Skipped: This YT Music 6.42.55 app made for Android 7"
    fi

    # --- YouTube Music RVX Android 5 and 6 ---
    # --- Download and generate patches.json ---
    if [ $Android -eq 5 ] || [ $Android -eq 6 ]; then
      # --- Download TY Music_6.20.51.apk from GitHub ---
      if [ ! -f "$Download/com.google.android.apps.youtube.music_6.20.51-$arch.apk" ]; then
        echo "${running} Download YT Music 6.20.51 apk from github.."
        wget "https://github.com/arghya339/Simplify/releases/download/all/com.google.android.apps.youtube.music_6.20.51-$arch.apk" -O "$Download/com.google.android.apps.youtube.music_6.20.51-$arch.apk" 2>&1 | grep -E 'Simplify|100%|saved'
      fi
      if [ -f "$Download/com.google.android.apps.youtube.music_6.20.51-$arch.apk" ]; then
        echo "${good} ${Green}YT Music 6.20.51 found:${Reset} $Download/com.google.android.apps.youtube.music_6.20.51-$arch.apk."
        echo "$running Patching YT Music RVX 6.20.51.."
        java -jar $ReVancedCLIJar_Path patch -p $PatchesRvp_Path \
          -o "$Simplify/yt-music-revanced-extended_6.20.51-$arch.apk" "$Download/com.google.android.apps.youtube.music_6.20.51-$arch.apk" \
          -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
          -e "Custom branding icon for YouTube Music" -OappIcon="/storage/emulated/0/Simplify/branding/music/launcher/google_family" \
          -e "Custom header for YouTube Music" -OcustomHeader="/storage/emulated/0/Simplify/branding/music/header/google_family" \
          -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" \
          -e "Dark theme" -OmaterialYou=true \
          -e "Custom header for YouTube Music" -e="Return YouTube Username" --custom-aapt2-binary="$Simplify/aapt2" \
          --purge --unsigned | tee "$SimplUsr/ytm-rvx-patch_log.txt"
          # --legacy-options "$SimplUsr/rvx-options.json" \
        if [ -d "$Simplify/yt-music-revanced-extended_6.20.51-$arch-temporary-files" ]; then
          rm -rf "$Simplify/yt-music-revanced-extended_6.20.51-$arch-temporary-files"
        fi
      elif [ ! -f "$Simplify/yt-music-revanced-extended_6.20.51-$arch.apk" ]; then
        echo "${bad} Oops, YouTube Music 6.20.51 Patching failed !! Logs saved to $SimplUsr/ytm-rvx-patch_log.txt. Share the Patchlog to developer."
      fi
      # --- Signing YT Music ---
      if [ -f "$Simplify/yt-music-revanced-extended_6.20.51-$arch.apk" ]; then
        echo "${running} Signing YT Music RVX 6.20.51.."
        apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk" "$Simplify/yt-music-revanced-extended_6.20.51-$arch.apk"
      # Add YT Music Signing failed detection logic
      elif [ ! -f "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk" ]; then
        echo "${bad} Oops, YT Music RVX 6.20.51 Signing failed !!"
      fi
      # After Signing complete delete 'yt-music-revanced-extended-signed_6.20.51-$arch.apk.idsig' & unsigned yt-music-revanced-extended_6.20.51-$arch.apk file.
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk" ]; then
        rm "$Simplify/yt-music-revanced-extended_6.20.51-$arch.apk" && rm "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk.idsig"
      fi
      # --- Verify sinature info ---
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk" ]; then
        echo "${running} Verify YT Music RVX 6.20.51 Signature info.."
        apksigner verify -v --print-certs "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk" | grep "Signer .* certificate DN"
      fi
      # Download VancedMicroGv0.2.22 for Android 5
      if [ ! -f "$Simplify/microg_v0.2.22.apk" ] || [ $Android -eq 5 ]; then
        echo "${running} Downloading microg_v0.2.22.apk from GitHub.."
        wget "https://github.com/TeamVanced/VancedMicroG/releases/download/v0.2.22.212658-212658001/microg.apk" -O "$Simplify/microg_v0.2.22.apk" 2>&1 | grep -E 'VancedMicroG|100%|saved'
      fi
      # --- Open the APK file with the Termux default package installer ---
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk" ] && [ -f $VancedMicroG_Path ] && [ $Android -eq 6 ]; then
        echo "${info} VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
        # Prompt for user choice on installing the VancedMicroG apk
        echo "$question ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Installing VancedMicroG apk.."
            termux-open "$VancedMicroG_Path"
            ;;
          n*|N*) echo "$notice VancedMicroG Installaion skipped." ;;
          *) echo "$info Invalid choice. VancedMicroG Installaion skipped." ;;
        esac
      elif [ -f "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk" ] && [ -f "$Simplify/microg_v0.2.22.apk" ] && [ $Android -eq 5 ]; then
        echo "${info} VancedMicroG is used to run MicroG services without root. \nYouTube and YouTube Music won't work without it. \nIf you already have VancedMicroG, You don't need to install it."
        # Prompt for user choice on installing the VancedMicroG apk
        echo "$question ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Installing VancedMicroG apk.."
            termux-open "$Simplify/microg_v0.2.22.apk"
            ;;
          n*|N*) echo "$notice VancedMicroG Installaion skipped." ;;
          *) echo "$info Invalid choice. VancedMicroG Installaion skipped." ;;
        esac
      fi
      if [ -f "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk" ] && [ -f $VancedMicroG_Path ] || [ -f "$Simplify/microg_v0.2.22.apk" ]; then
        # Prompt for user choice on installing the patched YT Music RVX apk
        echo "$question ${Yellow}Do you want to install YT Music RVX 6.20.51 app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Installing Patched YT Music RVX 6.20.51 apk.."
            termux-open "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk"
            ;;
          n*|N*) echo "$notice YT Music RVX 6.20.51 Installaion skipped." ;;
          *) echo "$info Invalid choice. YT Music RVX 6.20.51 Installaion skipped." ;;
        esac
        # Prompt for user choice on shareing the patched YT Music RVX apk
        echo "$question ${Yellow}Do you want to Share YT Music RVX 6.20.51 app? [Y/n]${Reset}"
        read -r -p "Select: " opt
        case $opt in
          y*|Y*|"")
            echo "$running Please Wait !! Sharing Patched YT Music RVX 6.20.51 apk.."
            termux-open --send "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$arch.apk"
            ;;
          n*|N*) echo "$notice YT Music RVX 6.20.51 Sharing skipped."
            echo "$info 'yt-music-revanced-extended-signed_6.20.51-$arch.apk' Locate in $SimplUsr dir, Share it with your Friends and Family ;)"
            ;;
          *) echo "$info Invalid choice. YT Music RVX 6.20.51 Sharing skipped." ;;
        esac  
      fi
    else
      echo "$info Skipped: This YT Music 6.20.51 app made for older Android Version"
    fi

    # --- Reddit ReVanced Extended Android 9 and up ---
    # --- Download and generate patches.json ---
    if [ $Android -ge 9 ]; then
      # --- Bug report prompt ---
      userInput=$(Write_ColoredPrompt $question_mark "yellow" "Are you want patch Reddit RVX? (Yes/No) ")
      case "$userInput" in
          [Yy]*)
              
              if [ -f "$Download/com.reddit.frontpage_$reddit_version.apk" ]; then
                echo "${good} Downloaded Reddit standalone apk exist"
              elif [ ! -f "$Download/com.reddit.frontpage_$reddit_version.apk" ] && [ -f "$Download/com.reddit.frontpage_$reddit_version.apkm" ]; then
                echo "${running} Merge splits apks to standalone apk.."
                # --- Merge from .apkm to .apk using APKEditor ---
                java -jar $APKEditor_Path m -i $reddit_apk_path -o "$Download/com.reddit.frontpage_$reddit_version.apk"
              elif [ ! -f "$Download/com.reddit.frontpage_$reddit_version.apkm" ]; then
                echo "${bad} Downloaded Reddit apks doesn't exist"
              fi
              <<comment
              if [ -f "$Download/com.reddit.frontpage_$reddit_version.apk" ] && [ -f "$Download/com.reddit.frontpage_$reddit_version.apkm" ]; then
                echo "$running Removing Reddit_$reddit_version.apkm.."
                rm "$Download/com.reddit.frontpage_$reddit_version.apkm"
              fi
comment
              if [ ! -f "$Download/com.reddit.frontpage_$reddit_version.apk" ]; then
                echo "${bad} Oops, Stock Reddit APK not found!"
              elif [ -f "$Download/com.reddit.frontpage_$reddit_version.apk" ]; then
                echo "${good} ${Green}Downloaded Reddit standalone APK found:${Reset} $Download/com.reddit.frontpage_$reddit_version.apk"
                # --- Execute ReVanced patching for Reddit ---
                echo "${running} Patching Reddit RVX.."
                java -jar $ReVancedCLIJar_Path patch -p $PatchesRvp_Path \
                  -o "$Simplify/reddit-revanced-extended_$reddit_version.apk" "$Download/com.reddit.frontpage_$reddit_version.apk" \
                  --custom-aapt2-binary="$Simplify/aapt2" \
                  --purge --rip-lib="" --unsigned -f | tee "$SimplUsr/reddit-rvx_patch-log.txt"
                  # --legacy-options "$SimplUsr/rvx-options.json" \
                if [ -d "$Simplify/reddit-revanced-extended_$reddit_version-temporary-files" ]; then
                  rm -rf "$Simplify/reddit-revanced-extended_$reddit_version-temporary-files"
                fi
              elif [ ! -f "$Simplify/reddit-revanced-extended_$reddit_version.apk" ]; then
                echo "${bad} Oops, Reddit RVX Patching failed !! Logs saved to $SimplUsr/reddit-rvx_patch-log.txt. Share the Patchlog to developer."
              fi
              # --- Signing Reddit RVX ---
              if [ -f "$Simplify/reddit-revanced-extended_$reddit_version.apk" ]; then
                echo "${running} Signing Reddit RVX.."
                apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk" "$Simplify/reddit-revanced-extended_$reddit_version.apk"
              fi
              # After Signing complete delete 'reddit-revanced-extended-signed_$reddit_version.apk.idsig' & unsigned reddit-revanced-extended_$reddit_version.apk file.
              if [ -f "$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk" ]; then
                rm "$Simplify/reddit-revanced-extended_$reddit_version.apk" && rm "$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk.idsig" 
              fi
              # Add Reddit Signing failed detection logic
              if [ ! -f "$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk" ]; then 
                echo "${bad} Oops, Reddit RVX Signing failed !!"
              fi
              # --- Verify sinature info ---
              if [ -f "$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk" ]; then
                echo "${running} Verify Reddit RVX APK Signature info.."
                apksigner verify -v --print-certs "$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk" | grep "Signer .* certificate DN"
              fi
              # --- Open the APK file with the Termux default package installer ---
              if [ -f "$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk" ]; then
                # Prompt for user choice on installing the patched Reddit RVX apk
                echo "$question ${Yellow}Do you want to install Reddit RVX app? [Y/n]${Reset}"
                read -r -p "Select: " opt
                case $opt in
                  y*|Y*|"")
                    echo "${running} Please Wait !! Installing Patched Reddit RVX apk.."
                    termux-open "$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk"
                    ;;
                  n*|N*) echo "$notice Reddit RVX Installaion skipped." ;;
                  *) echo "$info Invalid choice. Reddit RVX Installaion skipped." ;;
                esac
              fi
              if [ -f "$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk" ]; then
                # Prompt for user choice on shareing the patched Reddit RVX apk
                echo "$question ${Yellow}Do you want to Share Reddit RVX app? [Y/n]${Reset}"
                read -r -p "Select: " opt
                case $opt in
                  y*|Y*|"")
                    echo "$running Please Wait !! Sharing Patched Reddit RVX apk.."
                    termux-open --send "$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk"
                    ;;
                  n*|N*) echo "$notice Reddit RVX Sharing skipped."
                    echo "${info} Locate '$SimplUsr/reddit-revanced-extended-signed_$reddit_version.apk' in $SimplUsr dir, Share it with your Friends and Family ;)"
                    ;;
                  *) echo "$info Invalid choice. Reddit RVX Sharing skipped." ;;
                esac
              fi
              
              ;;
          [Nn]*)
              echo "${notice} ${Yellow}Skiped Reddit RVX Patch by Usr.${Reset}"
              ;;
          *)
              echo "${info} ${Blue}Invalid input. Please enter Yes or No.${Reset}"
              ;;
      esac
    else
      echo "${info} Skipped: Reddit App not compatible with Android $Android"
    fi
  
fi

# RVX Android 6-7
if [ $Android -eq 6 ] || [ $Android -eq 7 ]; then
PatchesRvp=$(find "$Simplify" -type f -name "patches-*.rvp" -print -quit)
PatchesRvp_Path=$(realpath "$PatchesRvp")
rm $PatchesRvp_Path
  # --- ReVanced Extended CLI for Android 6-7 ---
  download_and_cleanup "https://api.github.com/repos/inotia00/revanced-cli/releases/latest" \
                       "revanced-cli-[0-9]+\\.[0-9]+\\.[0-9]+-all\\.jar" \
                       "jar"
  
  # --- ReVanced Extended Patches for Android 6-7 ---
  download_and_cleanup "https://api.github.com/repos/kitadai31/revanced-patches-android6-7/releases/latest" \
                       "patches-[0-9]+\\.[0-9]+\\.[0-9]+\\.rvp" \
                       "rvp"
    
  # --- VancedMicroG ---
  download_and_cleanup "https://api.github.com/repos/inotia00/VancedMicroG/releases/latest" \
                       "microg.apk" \
                       "apk"

  VancedMicroG=$(find "$Simplify" -type f -name "microg-*.apk" -print -quit)
  VancedMicroG_Path=$(realpath "$VancedMicroG")
  echo "$info ${Blue}VancedMicroG:${Reset} $VancedMicroG_Path"

  # --- Download YouTube_17.34.36 ---
  if [ ! -f "$Download/com.google.android.youtube_17.34.36.apk" ]; then
    echo "${running} Downloading YouTube 17.34.36.apk from github.."
    wget "https://github.com/arghya339/Simplify/releases/download/all/com.google.android.youtube_17.34.36.apk" -O "$Download/com.google.android.youtube_17.34.36.apk" 2>&1 | grep -E 'Simplify|100%|saved'
  fi
  if [ -f "$Download/com.google.android.youtube_17.34.36.apk" ]; then
    echo "${good} ${Green}Downloaded YouTube 17.34.36 found:${Reset} $Download/com.google.android.youtube_17.34.36.apk"
    echo "$running Patching YouTube RVX 17.34.36 .."
    java -jar $Simplify/revanced-cli-*-all.jar patch -p  $Simplify/patches-*.rvp \
      -o "$Simplify/youtube-revanced-extended_17.34.36-$arch.apk" "$Download/com.google.android.youtube_17.34.36.apk" \
      -e "Visual preferences icons" \
      -e "Change version code" \
      -e "Custom header for YouTube" -OcustomHeader="$SimplUsr/branding/youtube/header/google_family" \
      -e "Custom branding icon for YouTube" -OappIcon="$SimplUsr/branding/youtube/launcher/google_family" \
      -e "Custom branding name for YouTube" -OappName="YouTube RVX" \
      -e "Force hide player buttons background" \
      -e "materialyou" \
      -e "Return YouTube Username" \
      -e "Spoof app version" \
      -e "Custom Shorts action buttons" -OiconType="round" \
      -e "GmsCore support" -OgmsCoreVendorGroupId="app.revanced" -OcheckGmsCore=true \
      -e "Hide shortcuts" -Oshorts=false \
      -e "Theme" -OdarkThemeBackgroundColor="@android:color/black" -OlightThemeBackgroundColor="@android:color/white" \
      --custom-aapt2-binary="$Simplify/aapt2" \
      $ripLib --purge --unsigned | tee "$SimplUsr/yt-rvx-a6_7_patch-log.txt"
      # --legacy-options $SimplUsr/revanced-extended-android6-7-options.json
      # -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \  # don't have com.mgoogle option in GmsCore support patch
      # -e "Overlay buttons" -OiconType="thin" \  # thin icon compile bug in Overlay buttons patch
      # --unsigned > "$SimplUsr/yt-rvx-a6_7_patch-log.txt"  # Redirect patch log to a .txt file without display log in Terminal
    # java -jar $Simplify/revanced-cli-*-all.jar patch $Download/com.google.android.youtube_17.34.36.apk -o $Simplify/youtube-revanced-extended_17.34.36.apk -m $Simplify/revanced-integrations-*.apk --options options.json -b $Simplify/revanced-patches-*.jar --purge -i "materialyou" -i "spoof-streaming-data" -e "hide-autoplay-button" -e "hide-cast-button"  -e "hide-create-button" -e "hide-endscreen-overlay" -e "hide-next-prev-button" -e "hide-player-captions-button" -e "hide-player-overlay-filter" -e "hide-shorts-button" -e "switch-create-notification" --unsigned | tee "$SimplUsr/yt-rvx-a6-7-patch_log.txt"
    rm $PatchesRvp_Path
    if [ -d "$Simplify/youtube-revanced-extended_17.34.36-$arch-temporary-files" ]; then
      rm -rf "$Simplify/youtube-revanced-extended_17.34.36-$arch-temporary-files"
    fi
  # Add YouTube_17.34.36 Patching failed detection logic
  elif [ ! -f "youtube-revanced-extended_17.34.36-$arch.apk" ]; then
    echo "${bad} Oops, YouTube RVX 17.34.36 Patching failed !! Logs saved to $SimplUsr/yt-rvx-a6-7_patch-log.txt. Share the Patchlog to developer."
  fi
  # --- Signing YouTube RVX ---
  if [ -f "$Simplify/youtube-revanced-extended_17.34.36-$arch.apk" ]; then
    echo "${running} Signing YouTube RVX 17.34.36.."
    apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$SimplUsr/youtube-revanced-extended-signed_17.34.36-$arch.apk" "$Simplify/youtube-revanced-extended_17.34.36-$arch.apk"
  fi
  # After Signing complete delete 'youtube-revanced-extended-signed_17.34.36.apk.idsig' & unsigned youtube-revanced-extended_17.34.36.apk file.
  if [ -f "$SimplUsr/youtube-revanced-extended-signed_17.34.36-$arch.apk" ]; then
    rm "$Simplify/youtube-revanced-extended_17.34.36-$arch.apk" && rm "$SimplUsr/youtube-revanced-extended-signed_17.34.36-$arch.apk.idsig" 
  # Add YouTube Signing failed detection logic
  elif [ ! -f "$SimplUsr/youtube-revanced-extended-signed_17.34.36-$arch.apk" ]; then 
    echo "${bad} Oops, YouTube RVX 17.34.36 Signing failed !!"
  fi
  # --- Verify sinature info ---
  if [ -f "$SimplUsr/youtube-revanced-extended-signed_17.34.36-$arch.apk" ]; then
    echo "${running} Verify YouTube RVX 17.34.36 Signature info.."
    apksigner verify -v --print-certs "$SimplUsr/youtube-revanced-extended-signed_17.34.36-$arch.apk" | grep "Signer .* certificate DN"
  fi
  # --- Open the APK file with the Termux default package installer ---
  if [ -f "$SimplUsr/youtube-revanced-extended-signed_17.34.36-$arch.apk" ] && [ -f $VancedMicroG_Path ]; then
    # Prompt for user choice on installing the VancedMicroG apk
    echo "$question ${Yellow}Do you want to install VancedMicroG app? [Y/n]${Reset}"
    read -r -p "Select: " opt
    case $opt in
      y*|Y*|"")
        echo "$running Please Wait !! Installing VancedMicroG apk.."
        termux-open "$VancedMicroG_Path"
        ;;
      n*|N*) echo "$notice VancedMicroG Installaion skipped." ;;
      *) echo "$info Invalid choice. VancedMicroG Installaion skipped." ;;
    esac
  fi
  if [ -f "$SimplUsr/youtube-revanced-extended-signed_17.34.36-$arch.apk" ] && [ -f $VancedMicroG_Path ]; then
    # Prompt for user choice on installing the patched Reddit RVX apk
    echo "$question ${Yellow}Do you want to install YouTube RVX 17.34.36 app? [Y/n]${Reset}"
    read -r -p "Select: " opt
    case $opt in
      y*|Y*|"")
        echo "${running} Please Wait !! Installing Patched YouTube RVX 17.34.36 apk.."
        termux-open "$SimplUsr/youtube-revanced-extended-signed_17.34.36-$arch.apk"
        ;;
      n*|N*) echo "$notice YouTube RVX 17.34.36 Installaion skipped." ;;
      *) echo "$info Invalid choice. YouTube RVX 17.34.36 Installaion skipped." ;;
    esac
  fi
  if [ -f "$SimplUsr/youtube-revanced-extended-signed_17.34.36.apk" ]; then
    # Prompt for user choice on shareing the patched YouTube RVX apk
    echo "$question ${Yellow}Do you want to Share YouTube RVX 17.34.36 app? [Y/n]${Reset}"
    read -r -p "Select: " opt
    case $opt in
      y*|Y*|"")
        echo "$running Please Wait !! Sharing Patched YouTube RVX 17.34.36 apk.."
        termux-open --send "$SimplUsr/youtube-revanced-extended-signed_17.34.36-$arch.apk"
        ;;
      n*|N*) echo "$notice YouTube RVX 17.34.36 Sharing skipped."
        echo "${info} Locate youtube-revanced-extended-signed_17.34.36.apk in $SimplUsr dir, Share it with your Friends and Family ;)"
        ;;
      *) echo "$info Invalid choice. YouTube RVX 17.34.36 Sharing skipped." ;;
    esac
  fi
else
  echo "${info} Skipped: This YouTube 17.34.36 app made for older Android Version"
fi

# --- Feature request prompt ---
userInput=$(Write_ColoredPrompt $question_mark "yellow" "Do you want any new feature in this script? (Yes/No) ")
case "$userInput" in
    [Yy]*)
        echo "${running} Creating feature request template using your key words.."
        feature_description=$(Write_ColoredPrompt "" "yellow" "Describe the new feature: ")
        termux-open-url "https://github.com/arghya339/Simplify/issues/new?title=Feature&body=$feature_description"
        echo "${Green}❤️ Thanks for your suggestion!${Reset}"
        ;;
    [Nn]*)
        echo "${running} Proceeding.."
        ;;
    *)
        echo "${info} ${Blue}Invalid input. Please enter Yes or No.${Reset}"
        ;;
esac

# --- Bug report prompt ---
userInput=$(Write_ColoredPrompt $question_mark "yellow" "Did you find any bugs? (Yes/No) ")
case "$userInput" in
    [Yy]*)
        echo "${running} Creating bug report template uisng your keywords.."
        issue_description=$(Write_ColoredPrompt "" "yellow" "Describe the bug: ")
        termux-open-url "https://github.com/arghya339/Simplify/issues/new?title=Bug&body=$issue_description"
        echo "${Green}🖤 Thanks for the report!${Reset}"
        ;;
    [Nn]*)
        echo "${Green}💐 Thanks for chosing Simplify!${Reset}"
        ;;
    *)
        echo "${info} ${Blue}Invalid input. Please enter Yes or No.${Reset}"
        ;;
esac

<<comment
# --- Open a URL in the default browser ---
echo "${Yellow}⭐ Star & 🍻 Fork me..
termux-open-url "https://github.com/arghya339/Simplify"
echo "${Yellow}💲 Donation: PayPal/@arghyadeep339"
termux-open-url "https://www.paypal.com/paypalme/arghyadeep339"
echo "${Yellow}🔔 Subscribe: YouTube/@MrPalash360"
termux-open-url "https://www.youtube.com/channel/UC_OnjACMLvOR9SXjDdp2Pgg/videos?sub_confirmation=1"
echo "${Yellow}📣 Follow: Telegram"
termux-open-url "https://t.me/MrPalash360"
echo "${Yellow}💬 Join: Telegram"
termux-open-url "https://t.me/MrPalash360Discussion"
comment

# --- Show developer info ---
echo "${Green}✅ *Done"
echo "${Green}✨ Powered by ReVanced (revanced.app)"
termux-open-url "https://revanced.app/"
echo "${Green}🧑‍💻 Author arghya339 (github.com/arghya339)"
echo ""
#########################################################