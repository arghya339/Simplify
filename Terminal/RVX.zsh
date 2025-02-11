#!/bin/zsh

# Set -e to exit immediately if a command exits with a non-zero status
set -e

# --- Define the eye color (adjust as desired) ---
eyeColor='green'  # primary color

# Define ANSI color codes
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
WHITE=$(tput setaf 7)
RESET=$(tput sgr0)

# Construct the eye shape using string concatenation
eye=$(cat <<'EOF'
  ______  __                       __ __  ______           
 /      \|  \                     |  \  \/      \          
|  ▓▓▓▓▓▓\\▓▓______ ____   ______ | ▓▓\▓▓  ▓▓▓▓▓▓\__    __ 
| ▓▓___\▓▓  \      \    \ /      \| ▓▓  \ ▓▓_  \▓▓  \  |  \
 \▓▓    \| ▓▓ ▓▓▓▓▓▓\▓▓▓▓\  ▓▓▓▓▓▓\ ▓▓ ▓▓ ▓▓ \   | ▓▓  | ▓▓
 _\▓▓▓▓▓▓\ ▓▓ ▓▓ | ▓▓ | ▓▓ ▓▓  | ▓▓ ▓▓ ▓▓ ▓▓▓▓   | ▓▓  | ▓▓
|  \__| ▓▓ ▓▓ ▓▓ | ▓▓ | ▓▓ ▓▓__/ ▓▓ ▓▓ ▓▓ ▓▓     | ▓▓__/ ▓▓
 \▓▓    ▓▓ ▓▓ ▓▓ | ▓▓ | ▓▓ ▓▓    ▓▓ ▓▓ ▓▓ ▓▓      \▓▓    ▓▓
  \▓▓▓▓▓▓ \▓▓\▓▓  \▓▓  \▓▓ ▓▓▓▓▓▓▓ \▓▓\▓▓\▓▓      _\▓▓▓▓▓▓▓
                         | ▓▓                    |  \__| ▓▓
                         | ▓▓                     \▓▓    ▓▓
                          \▓▓                      \▓▓▓▓▓▓ >_𝒟𝑒𝓋𝑒𝓁𝑜𝓅𝑒𝓇: @𝒶𝓇𝑔𝒽𝓎𝒶𝟥𝟥𝟫
https://github.com/arghya339/Simplify
EOF
)

# Set the console foreground color for the eyes
if [[ "$eyeColor" == "green" ]]; then
    echo "$GREEN$eye$RESET"
elif [[ "$eyeColor" == "red" ]]; then
    echo "$RED$eye$RESET"
elif [[ "$eyeColor" == "yellow" ]]; then
    echo "$YELLOW$eye$RESET"
elif [[ "$eyeColor" == "blue" ]]; then
    echo "$BLUE$eye$RESET"
elif [[ "$eyeColor" == "white" ]]; then
    echo "$WHITE$eye$RESET"
else
    echo "$eye" # Default color if not recognized
fi

echo "" # Space
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "# --- Colored log indicators  ---"

echo "${GREEN}[+]${RESET} -good"  # "[🗸]"
echo "${RED}[x]${RESET} -bad"    # "[✘]"
echo "${BLUE}[i]${RESET} -info"
echo "${WHITE}[~]${RESET} -running"
echo "${YELLOW}[!]${RESET} -notice"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Checking Internet Connection ---
echo "[~] Checking internet Connection..."
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null; then
  echo -e "${RED}[x] Oops! No Internet Connection available. \nConnect to the Internet and try again later.${RESET}"
  exit 1
fi

# If the ping command succeeds, we will reach this line
echo "${GREEN}[+]$RESET Internet connection is available."

# --- local Veriable ---
HOME="$HOME"
Downloads="$HOME/Downloads"
Simplify="$HOME/Simplify"
# --- Create the $Simplify directory if it doesn't exist ---
if [ ! -d "$Simplify" ]; then
  mkdir -p "$Simplify"
fi
OSArchitecture=$(uname -m) # get architecture of macOS
fullScriptPath=$(realpath "$0")  # currently running full script path

# --- Check for dependencies ---
dependencies=("brew" "java" "android-commandlinetools" "android-platform-tools" "python3") # Removed "7z" as they are not needed

for dependency in "${dependencies[@]}"; do
  installed=false
  version=""

  # Custom dependency checks
  case "$dependency" in
    # Check for Homebrew
    "brew")
      if brew --version >/dev/null 2>&1; then
        installed=true
        version=$(brew --version)
        echo "${GREEN}[+] Homebrew is already installed (Version: ${version})."
      fi
      ;;

    # Check for Java 23
    "java")
        export JAVA_HOME="/usr/local/opt/openjdk@23/libexec/openjdk.jdk/Contents/Home" && export PATH="$JAVA_HOME/bin:$PATH" && source ~/.zshrc
        if java -version 2>&1 | grep -q 'version "23.0.2'; then
            installed=true
            version=$(java -version 2>&1 | grep 'version' | awk -F '"' '{print $2}')
            echo "${GREEN}[+] Java 23 is already installed (Version: ${version})."
        fi
        ;;

    # Check for Android Command Line Tools
    "android-commandlinetools")
      if [ -d "/usr/local/Caskroom/android-commandlinetools" ]; then
        installed=true
        echo "${GREEN}[+] Android Command Line Tools are already installed."
      fi
      ;;

    # Check for Android Platform Tools
    "android-platform-tools")
      if [ -d "/usr/local/Caskroom/android-platform-tools" ]; then
        installed=true
        echo "${GREEN}[+] Android Platform Tools are already installed."
      fi
      ;;

    # Check for Python
    "python3")
      if python3 --version 2>&1 | grep -q 'Python '; then
        installed=true
        version=$(python3 --version 2>&1 | awk '{print $2}')
        echo "${GREEN}[+] Python is already installed (Version: ${version})."
      else
          if python3 --version 2>&1; then
            echo "${YELLOW}[!]$RESET Python detected, but version could not be determined."
          fi
      fi
      ;;
    # General executable check for unknown dependencies
    *)
        if command -v "$dependency" >/dev/null 2>&1; then
          installed=true
          echo "${GREEN}[+]${RESET} '$dependency' is already installed."
        fi
      ;;
  esac

  # If the dependency is not installed, attempt to install it
  if ! "$installed"; then
    echo "${YELLOW}[!]$RESET '$dependency' is not installed. Attempting to install..."
    case "$dependency" in
        "brew")
            echo "${YELLOW}[!]$RESET Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
             ;;
        "java")
              echo "${YELLOW}[!]$RESET Installing Java 23 using Brew..."
              brew install openjdk
              # --- Set Java 23 in PATH ---
              echo "${YELLOW}[!]$RESET Adding Java 23 to PATH..."
              # Add Java 23 to the PATH
              export JAVA_HOME="/usr/local/opt/openjdk@23/libexec/openjdk.jdk/Contents/Home"
              export PATH="$JAVA_HOME/bin:$PATH"
              echo $JAVA_HOME
              source ~/.zshrc
              # export JAVA_HOME="/usr/local/opt/openjdk@23/libexec/openjdk.jdk/Contents/Home" && export PATH="$JAVA_HOME/bin:$PATH"
              # Verify Java 23 is being used
              java -version
              ;;
        "android-commandlinetools")
            echo "${YELLOW}[!]$RESET Installing Android Command Line Tools using Brew..."
            brew install --cask android-commandlinetools
            ;;
        "android-platform-tools")
            echo "${YELLOW}[!]$RESET Installing Android Platform Tools using Brew..."
            brew install --cask android-platform-tools
            ;;
       "python3")
            echo "${YELLOW}[!]$RESET Installing Python using Brew..."
            brew install python@3.13
            ;;
    esac
    # Recheck installation to verify success
    installed=false
    case "$dependency" in
        "brew")
          if brew --version >/dev/null 2>&1; then
            installed=true
          fi
          ;;
        "java")
            if java -version 2>&1 | grep -q 'version "23.0.2'; then
                installed=true
            fi
          ;;
        
        "android-commandlinetools")
            if [ -d "/usr/local/Caskroom/android-commandlinetools" ]; then
                installed=true
            fi
          ;;

        "android-platform-tools")
            if [ -d "/usr/local/Caskroom/android-platform-tools" ]; then
                installed=true
            fi
          ;;

        "python3")
          if python3 --version 2>&1 | grep -q 'Python '; then
             installed=true
          fi
        ;;
      esac

       if "$installed"; then
           echo "${GREEN}[+]${RESET} '$dependency' installed and verified successfully."
        else
           echo "${RED}[x]${RESET} Installation verification failed for '$dependency'."
           echo "${YELLOW}[!]$RESET Please install '$dependency' manually and re-run the script."
           exit 1
       fi
  fi
done

# --- Capture dynamic path for sdkmanager ---
random_sdk_path=$(ls /usr/local/Caskroom/android-commandlinetools | head -n 1)

# Check if we got a valid path
if [ -z "$random_sdk_path" ]; then
    echo "${RED}[x]${RESET} No SDK directory found. Please verify the Android Command Line Tools installation."
    exit 1
fi

# Construct the full path to sdkmanager
sdkmanager_path="/usr/local/Caskroom/android-commandlinetools/$random_sdk_path/cmdline-tools/bin/sdkmanager"

# Check if sdkmanager exists
if [ ! -f "$sdkmanager_path" ]; then
    echo "${RED}[x]${RESET} sdkmanager not found in $sdkmanager_path. Please verify the Android Command Line Tools installation."
    exit 1
else
    echo "${GREEN}[+]${RESET} Found sdkmanager at: $sdkmanager_path"
fi

if [ ! -d "/usr/local/share/android-commandlinetools/build-tools" ]; then
# Downloading Build Tools by automatically accept all licenses
cd "$(dirname "$sdkmanager_path")" && yes | ./sdkmanager --licenses && sdkmanager --update && sdkmanager --version && sdkmanager --uninstall "build-tools;34.0.0" && sdkmanager "build-tools;34.0.0"
fi

# Setup cmdline-tools
echo 'export ANDROID_HOME="/usr/local/share/android-commandlinetools"' >> ~/.zshrc && echo 'export PATH="$ANDROID_HOME/cmdline-tools/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
# export ANDROID_HOME="/usr/local/share/android-commandlinetools" && export PATH="$ANDROID_HOME/cmdline-tools/bin:$PATH"

# Check the Build Tools Installation
echo "Android Build-Tools version:" && ls $ANDROID_HOME/build-tools/

# Add the build-tools directory to the PATH
echo 'export PATH="$ANDROID_HOME/build-tools/34.0.0:$PATH"' >> ~/.zshrc && source ~/.zshrc
# echo 'export PATH="$ANDROID_HOME/build-tools/34.0.0:$PATH"' >> ~/.zshrc && source ~/.zshrc

# Build Tools Usage
echo "${GREEN}[+]${RESET} apksigner version:" && apksigner version
echo "${GREEN}[+]${RESET} Android Asset Packaging Tool (aapt) version:" && aapt version


adb devices > /dev/null 2>&1  # Silently Starting adb daemon

# --- Number of devices connected to the computer through USB ---
devices=($(adb devices | grep -E '^\S+\s+device$' | awk '{print $1}'))
devicescount=${#devices[@]}

# --- Store the serial numbers and models in an array ---
deviceInfo=()
if (( devicescount > 0 )); then
    for device in "${devices[@]}"; do
        serial="$device"
        # Check that serial is not the "List" header
        if [[ "$serial" != "List" && -n "$serial" ]]; then
            model=$(adb -s "$serial" shell "getprop ro.product.model" | tr -d '\r\n')  # Remove any trailing newline or carriage return
            # Only add if the model is non-empty
            if [[ -n "$model" ]]; then
                deviceInfo+=("$serial:$model")
            else
                echo "${RED}[x] Error: Could not retrieve model for device $serial.${RESET}"
            fi
        fi
    done
fi

# Check if the number of devices is greater than 7
if (( ${#deviceInfo[@]} >= 7 )); then
    echo "${YELLOW}[!] Error: More than seven devices attached in adb!${RESET}"
    exit 1
fi

# Usage instructions with device model included
function usage {
    
    echo -e "${BLUE}[i] Usage examples:${RESET}"
    echo -e "${BLUE}[i] usage: ~ zsh $fullScriptPath [SERIAL]${RESET}"
    echo -e "${BLUE}[i] The serial number of the device can be found by running ~ adb devices.${RESET}"

    if (( devicescount == 0 )); then
        echo -e "${RED}[x] No devices found. Please connect a device and try again.${RESET}"
    else
        for device in "${deviceInfo[@]}"; do
            model=$(echo "$device" | cut -d ':' -f 2)
            serial=$(echo "$device" | cut -d ':' -f 1)
            echo -e "${GREEN}[i] $model ~ zsh $fullScriptPath $serial${RESET}"
        done
    fi
    exit 1
}

# --- Check if there are connected devices or if arguments are passed
if (( devicescount == 0 )) || (( $# == 0 )); then
    # No devices are connected and/or no arguments were passed, show usage
    usage
fi

# Assign the passed serial number
serial=$1

# --- adb dependent Variables ---
Android=$(adb -s "$serial" shell getprop ro.build.version.release)  # get device android version
cpu_abi=$(adb -s "$serial" shell getprop ro.product.cpu.abi)  # get device arch

# --- Checking Android Version ---
echo "[~] Checking Android Version..."
if (( Android < 5 )); then
    echo "${RED}[x] Android $Android is not supported by RVX Patches.${RESET}"
    exit 1
fi

# --- Check if the device is connected, authorized or offline via adb ---
deviceOutput=$(adb devices | grep "$serial")
if [[ -n "$deviceOutput" ]]; then
    devicestatus=$(echo "$deviceOutput" | awk '{print $2}')
    echo "Device status: $devicestatus"
else
    echo "${YELLOW}[!] No matching device found for serial: $serial${RESET}"
    devicestatus=null
fi

if [[ "$devicestatus" == "device" ]]; then
    echo "${GREEN}[+] Device '$serial' is connected.${RESET}"
elif [[ "$devicestatus" == "unauthorized" ]]; then
    echo "${RED}[x] Device '$serial' is not authorized.${RESET}"
    echo "${YELLOW}[!] Check for a confirmation dialog on your device.${RESET}"
    exit 1
else
    echo "${RED}[x] Device '$serial' is offline.${RESET}"
    echo "${YELLOW}[!] Check if the device is connected and USB debugging is enabled.${RESET}"
    exit 1
fi

# --- Get the device model ---
if [[ -n "$serial" ]]; then
    echo "${BLUE}[i] Using device serial: $serial"
    
    # Fetch the product model using adb
    product_model=$(adb -s "$serial" shell "getprop ro.product.model" | tr -d '\r\n')
    if [[ -z "$product_model" ]]; then
        echo "${RED}[x] Error: Couldn't fetch the product model for '$serial' device.${RESET}"
        exit 1
    fi
    echo "${BLUE}[i] Device model: $product_model"
else
    echo "${RED}[x] No device found or '$serial' is invalid.${RESET}"
    exit 1
fi

echo "${BLUE}[i] Target device:${RESET} $serial ($product_model)"

# --- Define a custom function for colored prompts ---
function Write_ColoredPrompt {
  # Parameters
  local message="$1"
  local color="$2"
  local prompt_message="$3"
  
  # Define color codes
  local color_code reset_code
  reset_code=$'\033[0m'  # Use $'...' here
  
  case "$color" in
    black) color_code=$'\033[30m' ;;
    red) color_code=$'\033[31m' ;;
    green) color_code=$'\033[32m' ;;
    yellow) color_code=$'\033[33m' ;;
    blue) color_code=$'\033[34m' ;;
    magenta) color_code=$'\033[35m' ;;
    cyan) color_code=$'\033[36m' ;;
    white) color_code=$'\033[37m' ;;
    *) color_code="$reset_code" ;;  # Default to reset if invalid color
  esac

  # Print the colored prompt message to stderr
  printf "%s%s %s%s" "$color_code" "$message" "$prompt_message" "$reset_code" >&2
  
  # Read user input and output it
  read -r input
  printf "%s" "$input"
}

# Download RVX_dl Python script for dynamically download stock apk from GitHub
if [[ ! -f "$Simplify/RVX_dl.py" ]]; then
  echo "Downloading RVX_dl.py from GitHub.."
  curl -L "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Terminal/RVX_dl.py" -o "$Simplify/RVX_dl.py"
fi

function check_jq {
  # Check if jq is installed globally
  if command -v jq &> /dev/null; then
    echo "${GREEN}[+]$RESET 'jq' is installed."
    jq --version  # Check and display jq version
  else
    echo "${YELLOW}[!]$RESET 'jq' is not installed."
    echo "[~] Installing jq via brew."
    brew install jq
  fi
}

: '
function check_wget {
  # Check if wget is installed globally
  if command -v wget &> /dev/null; then
    echo "${GREEN}[+]$RESET 'wget' is installed."
    wget --version
  else
    echo "${YELLOW}[!]$RESET 'wget' is not installed."
    echo "[~] installing wget via brew."
    brew install wget
  fi
}

# --- Download Custom aapt2 binary ---
# Check if the aapt2 binary already exists
if [[ ! -f "$Simplify/aapt2" ]]; then
  echo "[~] Downloading aapt2 binary..."
  # Download the binary using curl
  curl -L "https://github.com/decipher3114/binaries/releases/download/v1.0/aapt2_${OSArchitecture}" -o "$Simplify/aapt2" && chmod +x "$Simplify/aapt2" && "$Simplify/aapt2" version
else
  echo "${GREEN}[+]${RESET} aapt2 binary already exists."
  chmod +x "$Simplify/aapt2" && "$Simplify/aapt2" version
fi
'

# --- Create a keystore if it doesn't exist using keytool that comes with Java 17 ---
if [[ ! -e "$Simplify/ks.keystore" ]]; then
    echo "[~] Creating a keystore for signed APK..."
    keytool -genkey -v -storetype pkcs12 -keystore "$Simplify/ks.keystore" -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=IN" -storepass 123456 -keypass 123456
    # You can use the second line if you prefer the JKS store type instead of PKCS12
    # keytool -genkey -v -storetype JKS -keystore "$Simplify/ks.keystore" -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=IN" -storepass 123456 -keypass 123456 > /dev/null 2>&1  # to discard output.
fi

cd $Simplify  # change to $Simplify dir

# --- Function to download and cleanup files ---
# Download the latest file
# Correctly identify lower version number with file as an older version.
# Remove older version file from your storage.
# Download microg.apk and save it as microg-${tag_name}.apk.
Download_AndCleanup() {
    RepoUrl=$1
    FilePattern=$2
    FileExtension=$3

    # Download to temporary file and capture HTTP status code
    temp_file=$(mktemp)
    response_code=$(curl -s -L -o "$temp_file" -w "%{http_code}" "$RepoUrl")

    # Check for curl errors (non-HTTP errors like network issues)
    if [[ $? -ne 0 ]]; then
        echo "${RED}[x]${RESET} Error: Download failed from $RepoUrl" >&2
        rm -f "$temp_file"
        return 1
    fi

    # Validate HTTP status code
    if [[ "$response_code" -ne 200 ]]; then
        echo "${YELLOW}[!]${RESET} Error: GitHub API returned status code $response_code" >&2
        rm -f "$temp_file"
        return 1
    fi

    # Read and validate JSON response
    response=$(cat "$temp_file")
    rm -f "$temp_file"

    # Sanitize and check JSON validity
    if ! response=$(jq -r '.' <<< "$response" 2>/dev/null); then
        echo "${RED}[x]${RESET} Error: Invalid JSON response from GitHub API." >&2
        return 1
    fi

    # Extract necessary details from JSON
    downloadUrl=$(jq -r --arg fp "$FilePattern" '.assets[] | select(.name | test($fp)) | .browser_download_url' <<< "$response")
    latestFilename=$(jq -r --arg fp "$FilePattern" '.assets[] | select(.name | test($fp)) | .name' <<< "$response")
    tagName=$(jq -r '.tag_name' <<< "$response")

    # Handle empty results
    if [[ -z "$latestFilename" || -z "$downloadUrl" ]]; then
        echo "${RED}[x]${RESET} Error: Could not find a matching file for pattern '$FilePattern'." >&2
        return 1
    fi

    # --- Handle MicroG differently ---
    if [[ "$FilePattern" == *"microg.apk"* ]]; then
        filenameWithTag="microg-$tagName.apk"

        if [[ -e "$filenameWithTag" ]]; then
            echo "${GREEN}[+]${RESET} $filenameWithTag already exists. Skipping download."
        else
            echo "[~] Downloading latest version: $latestFilename (as $filenameWithTag)"
            curl -L -o "$filenameWithTag" "$downloadUrl" || { echo "${RED}[x]${RESET} Download failed"; return 1; }

            # Remove older versions of MicroG
            find . -type f -name "microg-*.apk" ! -name "$filenameWithTag" -exec rm -f {} \;
        fi

    # --- Handle Other Files Normally ---
    else
        if [[ -e "$latestFilename" ]]; then
            echo "${GREEN}[+]${RESET} File '$latestFilename' already exists. Skipping download."
        else
            echo "[~] Downloading latest version: $latestFilename"
            curl -L -o "$latestFilename" "$downloadUrl" || { echo "${RED}[x]${RESET} Download failed"; return 1; }

            echo "[~] Cleaning up older versions..."

            # Extract base name and version
            baseName=$(sed -E 's/(-[0-9.]+.*)?\.(.*)$//' <<< "$latestFilename")
            latestVersion=$(sed -E 's/.*-([0-9.]+).*$/\1/' <<< "$latestFilename")

            # Find and remove older versions
            find . -type f -name "$baseName*.$FileExtension" | while read -r file; do
                fileVersion=$(sed -E 's/.*-([0-9.]+).*$/\1/' <<< "$file")
                if ! [[ "$fileVersion" =~ ^[0-9.]+$ ]] || [[ "$fileVersion" != "$latestVersion" ]]; then
                    echo "[~] Removing older version: $file"
                    rm -f "$file"
                fi
            done
        fi
    fi
}

# List of all supported ABIs
all_abis=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")
# Generate ripLib arguments for all ABIs EXCEPT the detected one
ripLib=()
for abi in "${all_abis[@]}"; do
    if [[ "$abi" != "$cpu_abi" ]]; then
        ripLib+=("--rip-lib=$abi")
    fi
done
# Display the final arguments
echo "${BLUE}[i] cpu_abi:${RESET} $cpu_abi"
echo "${BLUE}[i] ripLib:${RESET} ${ripLib[*]}"

# --- YouTube & YouTube Music RVX Android 8 and up ---
# --- Download and generate patches.json ---
if [[ $Android -ge 5 ]]; then
    #find "$Simplify" -name "patches-*.rvp" -delete

    Download_AndCleanup "https://api.github.com/repos/inotia00/revanced-cli/releases/latest" "revanced-cli-[0-9]+.[0-9]+.[0-9]+-all.jar" "jar"
    Download_AndCleanup "https://api.github.com/repos/inotia00/revanced-patches/releases/latest" "patches-[0-9]+.[0-9]+.[0-9]+.rvp" "rvp"
    Download_AndCleanup "https://api.github.com/repos/inotia00/VancedMicroG/releases/latest" "microg.apk" "apk"
    Download_AndCleanup "https://api.github.com/repos/REAndroid/APKEditor/releases/latest" "APKEditor-[0-9]+.[0-9]+.[0-9]+.jar" "jar"

    revancedCliJar=$(find "$Simplify" -name "revanced-cli-*-all.jar" | head -n 1)
    patchesRvp=$(find "$Simplify" -name "patches-*.rvp" | head -n 1)
    VancedMicroG=$(find "$Simplify" -name "microg-*.apk" | head -n 1)
    APKEditorJar=$(find "$Simplify" -name "APKEditor-*.jar" | head -n 1)

    echo "${GREEN}[+]$RESET revancedCliJar: $revancedCliJar"
    echo "${GREEN}[+]$RESET patchesRvp: $patchesRvp"
    echo "${GREEN}[+]$RESET VancedMicroG: $VancedMicroG"
    echo "${GREEN}[+]$RESET APKEditorJar: $APKEditorJar"
    
    # --- Generate patches.json file ---
    if [[ ! -f "$Simplify/patches.json" && $Android -ge 8 ]]; then
      echo "${YELLOW}[!]${RESET} patches.json doesn't exist, generating patches.json"
      if [[ -n "$revancedCliJar" && -n "$patchesRvp" ]]; then
        java -jar "$revancedCliJar" patches "$patchesRvp"
        if [[ $? -eq 0 ]]; then
          echo "${GREEN}[+]${RESET} patches.json generated successfully!"
        else
          echo "${RED}[x]${RESET} Error: patches.json was not generated." >&2
        fi
      else
        echo "${RED}[x]${RESET} Error: Required files (revanced-cli.jar and patches.rvp) are missing." >&2
      fi
    fi
    
    : '
    # --- Download revanced-extended-options.json ---
    if [[ ! -f "$Simplify/revanced-extended-options.json" && 
      $(ls "$revancedCliJar" 2>/dev/null | wc -l) -gt 0 && 
      $(ls "$patchesRvp" 2>/dev/null | wc -l) -gt 0 && 
      $Android -ge 8 ]]; then
      echo "[~] Downloading revanced-extended-options.json..."
      curl -L "https://github.com/arghya339/Simplify/releases/download/all/revanced-extended.json" -o "$Simplify/revanced-extended-options.json"
    elif [[ -f "$Simplify/revanced-extended-options.json" && $Android -ge 5 ]]; then
      echo "${GREEN}[+]$RESET revanced-extended-options.json already exists in $Simplify directory..."
    fi
    '

    # --- Download branding.zip ---
    if [[ ! -d "$Simplify/branding" && ! -f "$Simplify/branding.zip" && 
      $(ls "$patchesRvp" 2>/dev/null | wc -l) -gt 0 && 
      $Android -ge 8 ]]; then
      echo "[~] Downloading branding.zip..."
      curl -L "https://github.com/arghya339/Simplify/releases/download/all/branding.zip" -o "$Simplify/branding.zip"
    elif [[ -d "$Simplify/branding" && $Android -ge 5 ]]; then
      echo "${BLUE}[i]$RESETbranding directory already exists in $Simplify directory..."
    fi
 
    # --- Extract branding.zip ---
    if [[ -f "$Simplify/branding.zip" && ! -d "$Simplify/branding" && $Android -ge 5 ]]; then
      echo "[~] Extracting branding.zip..."
      # Extract the ZIP file to the branding directory
      unzip -q "$Simplify/branding.zip" -d "$Simplify/branding"
    elif [[ -d "$Simplify/branding" && $Android -ge 5 ]]; then
      echo "${GREEN}[+]$RESET branding directory already exists in $Simplify directory..."
    fi

    # --- Remove branding.zip ---
    if [[ -d "$Simplify/branding" && -f "$Simplify/branding.zip" && $Android -ge 5 ]]; then
      echo "[~] Removing branding.zip..."
      rm -f "$Simplify/branding.zip"
    fi
    
    # --- Download stock APKs from GitHub using Python by extracting data from patches.json file ---
    if [[ -f "$Simplify/patches.json" && $Android -ge 8 ]]; then
        echo "[~] Downloading missing APK files..."
        echo "[~] Installing Python requests library using pip..."

        python3 -m pip install requests -q
        if [[ $? -ne 0 ]]; then
        echo "${RED}[x]$RESET Failed to install 'requests' using pip. Please check Python installation." >&2
        exit 1
        fi

        # Pass the Downloads and Simplify as environment variables to Python
        # --- Export Environment Variables ---
        export Downloads="$HOME/Downloads"
        export Simplify="$HOME/Simplify"
        export RVX_DOWNLOADS="$Downloads"  # Crucial for RVX_dl Python script
        export RVX_SIMPLIFY="$Simplify"
        export RVX_SERIAL="$serial"
        export RVX_ARCH="$cpu_abi"

        python3 "$Simplify/RVX_dl.py"

        # Recheck after downloading
        downloaded_youtube_apk=$(find "$Downloads" -type f -name "com.google.android.youtube*.apk" | head -n 1)
        downloaded_yt_music_apk=$(find "$Downloads" -type f -name "com.google.android.apps.youtube.music*.apk" | head -n 1)
        downloaded_reddit_apk=$(find "$Downloads" -type f -name "com.reddit.frontpage*.apkm" | head -n 1)

        # Check if APKs were successfully located or downloaded
        if [[ -z "$downloaded_youtube_apk" || -z "$downloaded_yt_music_apk" || -z "$downloaded_reddit_apk" ]]; then
          echo "${RED}[x]${RESET} Error: Failed to locate or download one or more APK files. Please check the logs." >&2
          exit 1
        fi

        echo "${GREEN}[+] YouTube APK:${RESET} $downloaded_youtube_apk"
        echo "${GREEN}[+] YouTube Music APK:${RESET} $downloaded_yt_music_apk"
        echo "${GREEN}[+] Reddit APK:${RESET} $downloaded_reddit_apk"

        # --- Get the versions from the filenames ---
        youtube_version=$(basename "$downloaded_youtube_apk" | sed -E 's/.*_(.*)\.apk/\1/')
        yt_music_version=$(basename "$downloaded_yt_music_apk" | sed -E 's/.*_(.*)-.*/\1/')
        reddit_version=$(basename "$downloaded_reddit_apk" | sed -E 's/.*_(.*)\.apkm/\1/')

        echo "${BLUE}[i] YouTube version:${RESET} $youtube_version"
        echo "${BLUE}[i] YouTube Music version:${RESET} $yt_music_version"
        echo "${BLUE}[i] Reddit version:${RESET} $reddit_version"
      
        # --- YouTube RVX ---
        # --- Check if YouTube APK is available and compatible Android version ---
        if [[ ! "$downloaded_youtube_apk" =~ "${RED}[x]$RESET Error downloading" ]] && [[ -e "$downloaded_youtube_apk" ]] && [[ $Android -ge 8 ]]; then
          echo "${GREEN}[+]$RESET Downloaded YouTube APK found: $downloaded_youtube_apk"
          echo "[~] Patching YouTube RVX..."
    
          # --- Execute ReVanced patching for YouTube ---
          java -jar "$revancedCliJar" patch -p "$patchesRvp" --purge -o "$Simplify/youtube-revanced-extended_$youtube_version-$cpu_abi.apk" $downloaded_youtube_apk \
            -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
            -e "Custom header for YouTube" -e "Force hide player buttons background" -e "MaterialYou" \
            -e "Return YouTube Username" -e "Custom Shorts action buttons" -OiconType=round -e "Hide shortcuts" \
            -Oshorts=false -e "Overlay buttons" -OiconType=thin -e "Custom branding name for YouTube" \
            -OappName="YouTube RVX" -e "Custom branding icon for YouTube" -OappIcon="$Simplify/branding/youtube/launcher/google_family" \
            -e "Custom header for YouTube" -OcustomHeader="$Simplify/branding/youtube/header/google_family" \
            --unsigned -f "${ripLib[@]}" | tee "$Simplify/yt-rvx-patch_log.txt"
    
          # Remove temporary files
          rm -rf "$Simplify/youtube-revanced-extended_${youtube_version}-${cpu_abi}-temporary-files"

          if [[ ! -e "$Simplify/youtube-revanced-extended_$youtube_version-$cpu_abi.apk" ]] && [[ -e "$downloaded_youtube_apk" ]] && [[ $Android -ge 8 ]]; then
            echo "${RED}[x]$RESET Oops, YouTube Patching failed !! Logs saved to $HOME/Simplify/yt-rvx-patch_log.txt. Share the Patchlog with the developer."
          fi

          # --- Signing YouTube RVX ---
          if [[ -e "$Simplify/youtube-revanced-extended_$youtube_version-$cpu_abi.apk" ]] && [[ $Android -ge 8 ]]; then
            echo "[~] Signing YouTube RVX..."
            apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$Simplify/youtube-revanced-extended-signed_${youtube_version}-${cpu_abi}.apk" "$Simplify/youtube-revanced-extended_${youtube_version}-${cpu_abi}.apk"
          elif [[ ! -e "$Simplify/youtube-revanced-extended-signed_${youtube_version}-${cpu_abi}.apk" ]] && [[ -e "$Simplify/youtube-revanced-extended_$youtube_version.apk" ]] && [[ $Android -ge 8 ]]; then
            echo "${RED}[x]$RESET Oops, YouTube RVX Signing failed !!"
          fi

          # After Signing, remove temporary unsigned APK if signing was successful
          if [[ -e "$Simplify/youtube-revanced-extended-signed_${youtube_version}-${cpu_abi}.apk" ]] && [[ $Android -ge 8 ]]; then
            rm "$Simplify/youtube-revanced-extended_${youtube_version}-${cpu_abi}.apk"
            rm "$Simplify/youtube-revanced-extended-signed_${youtube_version}-${cpu_abi}.apk.idsig"
          fi

          # --- Verify signature info ---
          if [[ -e "$Simplify/youtube-revanced-extended-signed_${youtube_version}-${cpu_abi}.apk" ]] && [[ $Android -ge 8 ]]; then
            echo "[~] Verifying Signature info of the signed YouTube RVX APK..."
            signedSignature=$(apksigner verify -v --print-certs "$Simplify/youtube-revanced-extended-signed_${youtube_version}-${cpu_abi}.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
            echo "${BLUE}[i]$RESET Signed YouTube RVX APK Certificate: $signedSignature"
    
            # Fetch the path of the installed APK from the device
            echo "[~] Fetching installed YouTube RVX APK path from the device..."
            YouTubeRVXPath=$(adb -s "$serial" shell pm path app.rvx.android.youtube | sed 's/package://')
    
            if [[ -n "$YouTubeRVXPath" ]]; then
              echo "[~] Pulling APK from device: $YouTubeRVXPath"
              adb -s "$serial" pull "$YouTubeRVXPath" "$Simplify/base.apk"
        
              echo "[~] Verifying Signature info of the pulled YouTube RVX APK..."
              baseSignature=$(apksigner verify -v --print-certs "$Simplify/base.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
              echo "${BLUE}[i]$RESET Pulled YouTube RVX APK Certificate: $baseSignature"
              rm "$Simplify/base.apk"  # Clean up pulled APK
        
              if [[ "$signedSignature" != "$baseSignature" ]]; then
                echo "${YELLOW}[!]$RESET Signatures do not match! Uninstalling the YouTube RVX app from the device..."
                adb -s "$serial" uninstall app.rvx.android.youtube
                echo "[~] Please Wait !! Installing Patched YouTube RVX APK"
                adb -s "$serial" install "$Simplify/youtube-revanced-extended-signed_${youtube_version}-${cpu_abi}.apk"
              else
                echo "${GREEN}[+]$RESET Signatures match. No action needed."
                echo "[~] Please Wait !! Reinstalling Patched YouTube RVX APK"
                adb -s "$serial" install -r "$Simplify/youtube-revanced-extended-signed_${youtube_version}-${cpu_abi}.apk"
              fi
            else
              echo "${YELLOW}[!]$RESET Failed to fetch the installed YouTube RVX APK path. Ensure the app is installed on the device."
              echo "[~] Please Wait !! Installing Patched YouTube RVX APK"
              adb -s "$serial" install "$Simplify/youtube-revanced-extended-signed_${youtube_version}-${cpu_abi}.apk"
            fi
          else
            echo "${RED}[x]$RESET Signed YouTube RVX APK file does not exist or Android version is unsupported."
          fi

          # --- Install the APK file (for Android version 8 and up) with the adb installer ---
          VancedMicroGInstalledStatus=$(adb -s $serial shell dumpsys package com.mgoogle.android.gms)
          if [[ -f "$Simplify/youtube-revanced-extended-signed_$youtube_version-$cpu_abi.apk" ]] && [[ -f "$VancedMicroG" ]] && [[ "$VancedMicroGInstalledStatus" == *"Unable to find package"* ]] && [[ "$Android" -ge 8 ]]; then
            echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
            echo "[~] installing $filenameWithTag"
            adb -s $serial install $VancedMicroG
          fi
          VancedMicroGPath=$(adb -s "$serial" shell pm path com.mgoogle.android.gms)
          VancedMicroGVersion=$(adb -s $serial shell dumpsys package com.mgoogle.android.gms | grep versionName | sed 's/versionName=//;s/^[[:space:]]*//;s/[[:space:]]*$//')
          if [[ -f "$Simplify/youtube-revanced-extended-signed_$youtube_version-$cpu_abi.apk" ]] && [[ -f "$VancedMicroG" ]] && [[ -n "$VancedMicroGPath" ]] && [[ "microg-v$VancedMicroGVersion.apk" != "$filenameWithTag" ]] && [[ "$Android" -ge 8 ]]; then
            echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
            echo "${YELLOW}[!]$RESET you already have VancedMicroG_v$VancedMicroGVersion, you need to uninstall it and you want to install the $filenameWithTag app"
            echo "[~] uninstalling VancedMicroG_v$VancedMicroGVersion app from device"
            adb -s $serial uninstall com.mgoogle.android.gms
            echo "[~] installing $filenameWithTag app"
            adb -s "$serial" install "$VancedMicroG"
          fi

          # Final Message
          if [[ -e "$Simplify/youtube-revanced-extended-signed_${youtube_version}-${cpu_abi}.apk" ]] && [[ $Android -ge 8 ]]; then
            echo "${BLUE}[i]$RESET Locate YouTube RVX in '$Simplify' directory. Share it with your Friends and Family ;)"
          fi
        else
          echo "${BLUE}[i]$RESET Latest YouTube not compatible with Android $Android"
        fi

        # --- YouTube Music RVX ---
        # --- YouTube Music RVX Patching ---
        if [[ ! "$yt_music_apk_path" =~ "${RED}[x]$RESET Error downloading" ]] && [[ -e "$downloaded_yt_music_apk" ]] && [[ Android -ge 8 ]]; then
          echo "${GREEN}[+]$RESET Downloaded YouTube Music APK found: $downloaded_yt_music_apk"
          echo "[~] Patching YouTube Music RVX..."

          # --- Execute ReVanced patching for YouTube Music ---
          java -jar "$revancedCliJar" patch -p "$patchesRvp" --purge -o "$Simplify/yt-music-revanced-extended_${yt_music_version}-${cpu_abi}.apk" "$downloaded_yt_music_apk" \
            -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
            -e "Return YouTube Username" \
            -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" -e "Custom branding icon for YouTube Music" -OappIcon="$Simplify/branding/music/launcher/google_family" \
            -e "Custom header for YouTube Music" -OcustomHeader="$Simplify/branding/music/header/google_family" \
            --rip-lib="" --unsigned -f | tee "$Simplify/ytm-rvx-patch_log.txt"

          # --- Signing YT Music ---
          if [[ -e "$Simplify/yt-music-revanced-extended_${yt_music_version}-${cpu_abi}.apk" ]] && [[ Android -ge 8 ]]; then
            echo "[~] Signing YT Music RVX..."
            apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias "ReVancedKey" --ks-pass pass:123456 --key-pass pass:123456 --out "$Simplify/yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk" "$Simplify/yt-music-revanced-extended_${yt_music_version}-${cpu_abi}.apk"
          elif [[ ! -e "$Simplify/yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk" ]] && [[ -e "$Simplify/yt-music-revanced-extended_${yt_music_version}-${cpu_abi}.apk" ]] && [[ Android -ge 8 ]]; then
            echo "${RED}[x]$RESET Oops, YT Music RVX Signing failed!!"
          fi

          # --- After signing, delete intermediate files ---
          if [[ -e "$Simplify/yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk" ]] && [[ Android -ge 8 ]]; then
            rm -rf "$Simplify/yt-music-revanced-extended_${yt_music_version}-${cpu_abi}.apk"
            rm -rf "$Simplify/yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk.idsig"
          fi

          # --- Verify signature info ---
          if [[ -e "$Simplify/yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk" ]] && [[ Android -ge 8 ]]; then
            echo "[~] Verifying Signature info of the signed YT Music RVX APK..."
            signedSignature=$(apksigner verify -v --print-certs "$Simplify/yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
            echo "${BLUE}[i]$RESET Signed YT Music RVX APK Certificate: $signedSignature"

            # Get the path of the installed APK on the device
            echo "[~] Fetching installed YT Music RVX APK path from the device..."
            YTMusicRVXPath=$(adb -s "$serial" shell pm path app.rvx.android.apps.youtube.music | sed 's/package://')
            if [[ -n "$YTMusicRVXPath" ]]; then
              # Pull the APK from the device
              echo "[~] Pulling YT Music RVX APK from device: $YTMusicRVXPath"
              adb -s "$serial" pull "$YTMusicRVXPath" "$Simplify/base.apk"

              # Verify the signer information of the pulled APK
              echo "[~] Verifying Signature info of the pulled YT Music RVX APK..."
              baseSignature=$(apksigner verify -v --print-certs "$Simplify/base.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
              echo "${BLUE}[i]$RESET Pulled YT Music RVX APK Certificate: $baseSignature"
              rm -f "$Simplify/base.apk"

              # Compare the two signatures
              if [[ "$signedSignature" != "$baseSignature" ]]; then
                echo "${YELLOW}[!]$RESET Signatures do not match! Uninstalling the YT Music RVX app from the device..."
                adb -s "$serial" uninstall app.rvx.android.apps.youtube.music
                echo "[~] Please Wait! Installing Patched YT Music RVX APK"
                adb -s "$serial" install "$Simplify/yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk"
              else
                echo "${GREEN}[+]$RESET Signatures match. No action needed."
                echo "[~] Please Wait! Reinstalling Patched YT Music RVX APK"
                adb -s "$serial" install -r "$Simplify/yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk"
              fi
            else
              echo "${YELLOW}[!]$RESET Failed to fetch the installed APK path. Ensure the app is installed on the device."
              echo "[~] Please Wait! Installing Patched YT Music RVX APK"
              adb -s "$serial" install "$Simplify/yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk"
            fi
          else
            echo "${RED}[x]$RESET Signed YT Music RVX APK file does not exist or Android version is unsupported."
          fi

          # --- Install the APK file (for Android version 8 and up) with the adb installer ---
          VancedMicroGInstalledStatus=$(adb -s $serial shell dumpsys package com.mgoogle.android.gms)
          if [[ -f "$Simplify/yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk" ]] && [[ -f "$VancedMicroG" ]] && [[ "$VancedMicroGInstalledStatus" == *"Unable to find package"* ]] && [[ "$Android" -ge 8 ]]; then
            echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
            echo "[~] installing $filenameWithTag"
            adb -s $serial install $VancedMicroG
          fi
          VancedMicroGPath=$(adb -s "$serial" shell pm path com.mgoogle.android.gms)
          VancedMicroGVersion=$(adb -s $serial shell dumpsys package com.mgoogle.android.gms | grep versionName | sed 's/versionName=//;s/^[[:space:]]*//;s/[[:space:]]*$//')
          if [[ -f "$Simplify/yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk" ]] && [[ -f "$VancedMicroG" ]] && [[ -n "$VancedMicroGPath" ]] && [[ "microg-v$VancedMicroGVersion.apk" != "$filenameWithTag" ]] && [[ "$Android" -ge 6 ]]; then
            echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
            echo "${YELLOW}[!]$RESET you already have VancedMicroG_v$VancedMicroGVersion, you need to uninstall it and you want to install the $filenameWithTag app"
            echo "[~] uninstalling VancedMicroG_v$VancedMicroGVersion app from device"
            adb -s $serial uninstall com.mgoogle.android.gms
            echo "[~] installing $filenameWithTag app"
            adb -s "$serial" install "$VancedMicroG"
          fi

          # Final Message
          if [[ -e "$Simplify/yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk" ]] && (( Android >= 8 )); then
            echo "${BLUE}[i]$RESET yt-music-revanced-extended-signed_${yt_music_version}-${cpu_abi}.apk is located in $Simplify. Share it with your friends and family! ;)"
          fi

        else
          echo "${BLUE}[i]$RESET Latest YT Music not compatible with Android $Android"
        fi

        # --- YouTube Music RVX for Android 7 ---
        if [[ $Android -eq 7 ]]; then
          # Download YT Music 6.42.55 APK
          if [[ ! -e "$Downloads/com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk" ]]; then
            echo "[~] Downloading YT Music 6.42.55-$cpu_abi.apk from GitHub..."
            curl -L "https://github.com/arghya339/Simplify/releases/download/all/com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk" -o "$Downloads/com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk"
          fi
          if [[ -e "$Downloads/com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk" ]]; then
            echo "${GREEN}[+]$RESET YT Music 6.42.55-$cpu_abi already exists in $Downloads directory."
            echo "[~] Patching YouTube Music RVX 6.42.55..."
            # --- Execute ReVanced patching for YouTube Music ---
            java -jar "$revancedCliJar" patch -p "$patchesRvp" --purge -o "$Simplify/yt-music-revanced-extended_6.42.55-$cpu_abi.apk" "$Downloads/com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk" \
              -e "Change version code" \
              -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
              -e="Return YouTube Username" \
              -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" -e "Custom branding icon for YouTube Music" -OappIcon="$Simplify/branding/music/launcher/google_family" \
              -e "Custom header for YouTube Music" -OcustomHeader="$Simplify/branding/music/header/google_family" \
              --rip-lib="" --unsigned -f | tee "$Simplify/ytm-rvx-patch_log.txt"

            # Clean up temporary files
            rm -rf "$Simplify/yt-music-revanced-extended_6.42.55-$cpu_abi-temporary-files"
          elif [[ -e "$Downloads/com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk" ]] && [[ ! -e "$Simplify/yt-music-revanced-extended_6.42.55-$cpu_abi.apk" ]]; then
            echo "${RED}[x]$RESET Oops, YouTube Music 6.42.55 patching failed! Logs saved to '$HOME/Simplify/ytm-rvx-patch_log.txt'. Share the patch log with the developer."
          fi

          # --- Signing the patched APK ---
          if [[ -e "$Simplify/yt-music-revanced-extended_6.42.55-$cpu_abi.apk" ]]; then
            echo "[~] Signing YT Music RVX..."
            apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias "ReVancedKey" --ks-pass pass:123456 --key-pass pass:123456 --out "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk" "$Simplify/yt-music-revanced-extended_6.42.55-$cpu_abi.apk"
          elif [[ ! -e "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk" ]]; then
            echo "${RED}[x]$RESET Oops, YT Music RVX 6.42.55 signing failed!"
          fi

          # --- Clean up after signing ---
          if [[ -e "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk" ]]; then
            rm -f "$Simplify/yt-music-revanced-extended_6.42.55-$cpu_abi.apk"
            rm -f "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk.idsig"
          fi

          # --- Verify signature info ---
          if [[ -e "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk" ]]; then
            echo "[~] Verifying Signature info of the signed TY Music RVX APK..."
            signedSignature=$(apksigner verify -v --print-certs "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
            echo "${BLUE}[i]$RESET Signed APK Certificate: $signedSignature"

            # Get the path of the installed APK on the device
            echo "[~] Fetching installed YT Music RVX APK path from the device..."
            YTMusicRVXPath=$(adb -s "$serial" shell pm path app.rvx.android.apps.youtube.music | sed 's/package://')
            if [[ -n "$YTMusicRVXPath" ]]; then
              # Pull the APK from the device
              echo "[~] Pulling APK from device: $YTMusicRVXPath"
              adb -s "$serial" pull "$YTMusicRVXPath" "$Simplify/base.apk"

              # Verify the signer information of the pulled APK
              echo "[~] Verifying Signature info of the pulled APK..."
              baseSignature=$(apksigner verify -v --print-certs "$Simplify/base.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
              echo "${BLUE}[i]$RESET Pulled APK Certificate: $baseSignature"
              rm -f "$Simplify/base.apk"

              # Compare the two signatures
              if [[ "$signedSignature" != "$baseSignature" ]]; then
                echo "${YELLOW}[!]$RESET Signatures do not match! Uninstalling the YT Music RVX 6.42.55 app from the device..."
                adb -s "$serial" uninstall app.rvx.android.apps.youtube.music
                echo "[~] Please Wait! Installing Patched YT Music RVX 6.42.55 APK"
                adb -s "$serial" install "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk"
              else
                echo "${GREEN}[+]$RESET Signatures match. No action needed."
                echo "[~] Please Wait! Reinstalling Patched YT Music RVX 6.42.55 APK"
                adb -s "$serial" install -r "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk"
              fi
            else
              echo "${YELLOW}[!]$RESET Failed to fetch the installed APK path. Ensure the app is installed on the device."
              echo "[~] Please Wait! Installing Patched YT Music RVX 6.42.55 APK"
              adb -s "$serial" install "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk"
            fi
          else
            echo "${YELLOW}[!]$RESET Signed YT Music RVX 6.42.55 APK file does not exist or Android version is unsupported."
          fi

          # --- Install the APK file (for Android version 7) with the adb installer ---
          VancedMicroGInstalledStatus=$(adb -s $serial shell dumpsys package com.mgoogle.android.gms)
          if [[ -f "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk" ]] && [[ -f "$VancedMicroG" ]] && [[ "$VancedMicroGInstalledStatus" == *"Unable to find package"* ]] && [[ "$Android" -eq 7 ]]; then
            echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
            echo "[~] installing $filenameWithTag"
            adb -s $serial install $VancedMicroG
          fi
          VancedMicroGPath=$(adb -s "$serial" shell pm path com.mgoogle.android.gms)
          VancedMicroGVersion=$(adb -s $serial shell dumpsys package com.mgoogle.android.gms | grep versionName | sed 's/versionName=//;s/^[[:space:]]*//;s/[[:space:]]*$//')
          if [[ -f "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk" ]] && [[ -f "$VancedMicroG" ]] && [[ -n "$VancedMicroGPath" ]] && [[ "microg-v$VancedMicroGVersion.apk" != "$filenameWithTag" ]] && [[ "$Android" -eq 7 ]]; then
            echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
            echo "${YELLOW}[!]$RESET you already have VancedMicroG_v$VancedMicroGVersion, you need to uninstall it and you want to install the $filenameWithTag app"
            echo "[~] uninstalling VancedMicroG_v$VancedMicroGVersion app from device"
            adb -s $serial uninstall com.mgoogle.android.gms
            echo "[~] installing $filenameWithTag app"
            adb -s "$serial" install "$VancedMicroG"
          fi

          # Notify user of APK location
          if [[ -e "$Simplify/yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk" ]]; then
            echo "${BLUE}[i]$RESET yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk is located in $Simplify directory. Share it with your friends and family! ;)"
          fi
        else
          echo "${BLUE}[i]$RESET This YT Music 6.42.55 app is made for Android 7."
        fi
  
        # --- YouTube Music RVX for Android 5 and 6 ---
        if [[ "$Android" -eq 6 ]] || [[ "$Android" -eq 5 ]]; then
          # Download YT Music 6.20.51 APK
          if [[ ! -f "$Downloads/com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk" ]] && [[ "$Android" -eq 6 ]] || [[ "$Android" -eq 5 ]]; then
            echo "[~] Downloading YT Music 6.20.51-$cpu_abi.apk from GitHub..."
            curl -L "https://github.com/arghya339/Simplify/releases/download/all/com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk" -o "$Downloads/com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk"
          fi
          if [[ -f "$Downloads/com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk" ]]; then
            echo "${GREEN}[+]$RESET YT Music 6.20.51-$cpu_abi already exists in $Downloads directory."
            echo "[~] Patching YouTube Music RVX 6.20.51..."
            java -jar "$revancedCliJar" patch -p "$patchesRvp" --purge -o "$Simplify/yt-music-revanced-extended_6.20.51-$cpu_abi.apk" "$Downloads/com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk" \
              -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
              -e "Return YouTube Username" \
              -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" \
              -e "Custom branding icon for YouTube Music" -OappIcon="$Simplify/branding/music/launcher/google_family" \
              -e "Custom header for YouTube Music" -OcustomHeader="$Simplify/branding/music/header/google_family" \
              --rip-lib="" --unsigned -f | tee "$Simplify/ytm-rvx-patch_log.txt"
            rm -rf "$Simplify/yt-music-revanced-extended_6.20.51-$cpu_abi-temporary-files"
          elif [[ ! -f "$Simplify/yt-music-revanced-extended_6.20.51-$cpu_abi.apk" ]] && [[ -f "$Downloads/com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk" ]]; then
            echo "${RED}[x]$RESET Oops, YouTube Music 6.20.51 patching failed! Logs saved to '$HOME/Simplify/ytm-rvx-patch_log.txt'. Share the patch log with the developer."
          fi

          # Signing the patched APK
          if [[ -f "$Simplify/yt-music-revanced-extended_6.20.51-$cpu_abi.apk" ]]; then
            echo "[~] Signing YT Music RVX 6.20.51..."
            apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" "$Simplify/yt-music-revanced-extended_6.20.51-$cpu_abi.apk"
          elif [[ ! -f "$SimplUsr/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" ]] && [[ "$Android" -eq 6 ]] || [[ "$Android" -eq 5 ]]; then
            echo "${RED}[x]$RESET Oops, YT Music RVX 6.20.51 signing failed!"
          fi

          # Clean up after successful signing
          if [[ -f "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" ]] && [[ "$Android" -eq 6 ]] || [[ "$Android" -eq 5 ]]; then
            rm -f "$Simplify/yt-music-revanced-extended_6.20.51-$cpu_abi.apk"
            rm -f "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk.idsig"
          fi

          # --- Verify signature info ---
          if [[ -f "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" ]] && [[ "$Android" -eq 6 ]] || [[ "$Android" -eq 5 ]]; then
            echo "[~] Verifying Signature info of the signed YT Music RVX 6.20.51 APK..."
            signedSignature=$(apksigner verify -v --print-certs "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
            echo "${BLUE}[i]$RESET Signed YT Music RVX 6.20.51 APK Certificate: $signedSignature"
    
            # Get the path of the installed APK on the device
            echo "[~] Fetching installed YT Music RVX 6.20.51 APK path from the device..."
            YTMusicRVXPath=$(adb -s "$serial" shell pm path app.rvx.android.apps.youtube.music | sed 's/package://')
    
            if [[ -n "$YTMusicRVXPath" ]]; then
              echo "[~] Pulling YT Music RVX 6.20.51 APK from device: $YTMusicRVXPath"
              adb -s "$serial" pull "$YTMusicRVXPath" "$Simplify/base.apk"
      
              # Verify the signer information of the pulled APK
              echo "[~] Verifying Signature info of the pulled YT Music RVX 6.20.51 APK..."
              baseSignature=$(apksigner verify -v --print-certs "$Simplify/base.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
              echo "${BLUE}[i]$RESET Pulled YT Music RVX 6.20.51 APK Certificate: $baseSignature"
              rm -f "$Simplify/base.apk"
      
              # Compare the two signatures
              if [[ "$signedSignature" != "$baseSignature" ]]; then
                echo "${YELLOW}[!]$RESET Signatures do not match! Uninstalling the YT Music RVX 6.20.51 app from the device..."
                adb -s "$serial" uninstall app.rvx.android.apps.youtube.music
                echo "[~] Please Wait! Installing Patched YT Music RVX 6.20.51 APK"
                adb -s "$serial" install "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk"
              else
                echo "${GREEN}[+]$RESET Signatures match. No action needed."
                echo "[~] Please Wait! Reinstalling Patched YT Music RVX 6.20.51 APK"
                adb -s "$serial" install -r "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk"
              fi
            else
              echo "${YELLOW}[!]$RESET Failed to fetch the installed YT Music RVX 6.20.51 APK path. Ensure the app is installed on the device."
              echo "[~] Please Wait! Installing Patched YT Music RVX 6.20.51 APK"
              adb -s "$serial" install "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk"
            fi
          else
            echo "${RED}[x]$RESET Signed YT Music RVX 6.20.51 APK file does not exist or Android version is unsupported."
          fi
    
          # --- Install the APK file (for Android version 6) with the adb installer ---
          VancedMicroGInstalledStatus=$(adb -s $serial shell dumpsys package com.mgoogle.android.gms)
          if [[ -f "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" ]] && [[ -f "$VancedMicroG" ]] && [[ "$VancedMicroGInstalledStatus" == *"Unable to find package"* ]] && [[ "$Android" -eq 6 ]]; then
            echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
            echo "[~] installing $filenameWithTag"
            adb -s $serial install $VancedMicroG
          fi
          VancedMicroGPath=$(adb -s "$serial" shell pm path com.mgoogle.android.gms)
          VancedMicroGVersion=$(adb -s $serial shell dumpsys package com.mgoogle.android.gms | grep versionName | sed 's/versionName=//;s/^[[:space:]]*//;s/[[:space:]]*$//')
          if [[ -f "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" ]] && [[ -f "$VancedMicroG" ]] && [[ -n "$VancedMicroGPath" ]] && [[ "microg-v$VancedMicroGVersion.apk" != "$filenameWithTag" ]] && [[ "$Android" -eq 6 ]]; then
            echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
            echo "${YELLOW}[!]$RESET you already have VancedMicroG_v$VancedMicroGVersion, you need to uninstall it and you want to install the $filenameWithTag app"
            echo "[~] uninstalling VancedMicroG_v$VancedMicroGVersion app from device"
            adb -s $serial uninstall com.mgoogle.android.gms
            echo "[~] installing $filenameWithTag app"
            adb -s "$serial" install "$VancedMicroG"
          fi

          # --- Download Vanced MicroG_v0.2.22.212658 from GitHub ---
          if [[ ! -f "$Simplify/microg_v0.2.22.apk" ]] && [[ "$Android" -eq 5 ]]; then
            echo "[~] downloading microg_v0.2.22.apk from github..."
            curl -L "https://github.com/TeamVanced/VancedMicroG/releases/download/v0.2.22.212658-212658001/microg.apk" -o "$Simplify/microg_v0.2.22.apk"
          fi
          # --- Install the APK file (for Android version 5) with the adb installer ---
          if [[ -f "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cup_abi.apk" ]] && [[ -f "$Simplify/microg_v0.2.22.apk" ]] && [[ "$VancedMicroGInstalledStatus" == *"Unable to find package"* ]] && [[ "$Android" -eq 5 ]]; then
            echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
            echo "[~] installing microg_v0.2.22.apk"
            adb -s $serial install $Simplify/microg_v0.2.22.apk
          fi
          if [[ -f "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" ]] && [[ -f "$Simplify/microg_v0.2.22.apk" ]] && [[ -n "$VancedMicroGPath" ]] && [[ "$VancedMicroGVersion" != "0.2.22.212658" ]] && [[ "$Android" -eq 5 ]]; then
            echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
            echo "${YELLOW}[!]$RESET you already have VancedMicroG_v$VancedMicroGVersions, you need to uninstall it and you want to install the microg_v0.2.22 app"
            echo "[~] uninstalling VancedMicroG_v$VancedMicroGVersions app from device"
            adb -s "$serial" uninstall com.mgoogle.android.gms
            echo "[~] installing microg_v0.2.22 app"
            adb -s "$serial" install "$Simplify/microg_v0.2.22.apk"
          fi
    
          # Notify user of APK location
          if [[ -e "$Simplify/yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" ]]; then
            echo "${BLUE}[i]$RESET yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk is located in $Simplify directory. Share it with your friends and family! ;)"
          fi
    
        else
          echo "${BLUE}[i]$RESET This YT Music 6.20.51 app is made for older Android versions."
        fi

        # --- Reddit ReVanced Extended Android 9 and up ---
        if [[ $Android -ge 9 ]]; then
          # Prompt the user
          userInput=$(Write_ColoredPrompt "[?]" "yellow" "Are you want patching Reddit RVX? (Yes/No)")
          # Check the user's input
          # Check the user's input
          if [[ "$userInput" =~ ^(Yes|yes|Y|y)$ ]]; then
            echo "[~] Proceeding..."

            # Check conditions and execute tasks
            if [[ ! -f "$Downloads/com.reddit.frontpage_$reddit_version.apk" ]] && [[ -f "$Downloads/com.reddit.frontpage_$reddit_version.apkm" ]]; then
              echo "[~] Merge splits Reddit APKs to standalone APK..."
              # Merge from .apkm to .apk using APKEditor
              java -jar "$APKEditorJar" m -i "$downloaded_reddit_apk" -o "$Downloads/com.reddit.frontpage_$reddit_version.apk"
            elif [[ ! -f "$downloaded_reddit_apk" ]]; then
              echo "${RED}[x]$RESET Oops, Stock Reddit APKM not found."
            elif [[ -f "$Downloads/com.reddit.frontpage_$reddit_version.apk" ]]; then
              echo "${GREEN}[+]$RESET Reddit apk already exist in $Downloads dir"
            fi

            : '
            if [[ -f "$Downloads/com.reddit.frontpage_$reddit_version.apk" ]] && [[ -f "$Downloads/com.reddit.frontpage_$reddit_version.apkm" ]]; then
              echo "[~] Remove Reddit_$reddit_version.apkm..."
              rm -f "$Downloads/com.reddit.frontpage_$reddit_version.apkm"
            fi
            '

            if [[ -f "$Downloads/com.reddit.frontpage_$reddit_version.apk" ]]; then
              echo "${GREEN}[+]$RESET Downloaded Reddit APK found: $Downloads/com.reddit.frontpage_$reddit_version.apk"
              echo "[~] Patching Reddit RVX"
              # Execute ReVanced patching for Reddit
              java -jar "$revancedCliJar" patch -p "$patchesRvp" --purge -o "$Simplify/reddit-revanced-extended_$reddit_version.apk" "$Downloads/com.reddit.frontpage_$reddit_version.apk" --unsigned -f | tee "$Simplify/reddit-rvx-patch_log.txt"
              rm -rf "$Simplify/reddit-revanced-extended_$reddit_version-temporary-files"
              rm -rf "$Simplify/reddit-revanced-extended_$reddit_version-options.json"
            elif [[ ! -f "$Simplify/reddit-revanced-extended_$reddit_version.apk" ]]; then
              echo "${RED}[x]$RESET Oops, Reddit Patching failed!! Logs saved to $HOME/Simplify/reddit-rvx-patch_log.txt. Share the Patchlog with the developer."
            fi

            if [[ -f "$Simplify/reddit-revanced-extended_$reddit_version.apk" ]]; then
              # Signing Reddit RVX
              echo "[~] Signing Reddit RVX..."
              apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias "ReVancedKey" --ks-pass pass:123456 --key-pass pass:123456 --out "$Simplify/reddit-revanced-extended-signed_$reddit_version.apk" "$Simplify/reddit-revanced-extended_$reddit_version.apk"
              # Remove intermediate files
              rm -f "$Simplify/reddit-revanced-extended_$reddit_version.apk"
              rm -f "$Simplify/reddit-revanced-extended-signed_$reddit_version.apk.idsig"
            elif [[ ! -f "$Simplify/reddit-revanced-extended-signed_$reddit_version.apk" ]]; then
              echo "${RED}[x]$RESET Oops, Reddit RVX Signing failed!!"
            fi

            # --- Verify signature info ---
            if [[ -f "$Simplify/reddit-revanced-extended-signed_$reddit_version.apk" ]] && [[ $Android -ge 9 ]]; then
              echo "[~] Verifying Signature info of the signed APK..."
              # Get the signer information for the signed APK
              signedSignature=$(apksigner verify -v --print-certs "$Simplify/reddit-revanced-extended-signed_$reddit_version.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
              echo "${BLUE}[i] Signed APK Certificate:${RESET} $signedSignature"

              # Get the path of the installed APK on the device
              echo "[~] Fetching installed Reddit RVX APK path from the device..."
              RedditPath=$(adb -s "$serial" shell pm path com.reddit.frontpage | sed 's/package://')
              if [[ -n "$RedditPath" ]]; then
                # Pull the APK from the device
                echo "[~] Pulling APK from device: $RedditPath"
                adb -s "$serial" pull "$RedditPath" "$Simplify/base.apk"

                # Verify the signer information of the pulled APK
                echo "[~] Verifying Signature info of the pulled APK..."
                baseSignature=$(apksigner verify -v --print-certs "$Simplify/base.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
                echo "${BLUE}[i] Pulled APK Certificate:${RESET} $baseSignature"
                rm -f "$Simplify/base.apk"

                # Compare the two signatures
                if [[ "$signedSignature" != "$baseSignature" ]]; then
                  echo "${YELLOW}[!]$RESET Signatures do not match! Uninstalling the Reddit RVX app from the device..."
                  adb -s "$serial" uninstall com.reddit.frontpage
                  echo "[~] Please Wait !! Installing Patched Reddit RVX APK"
                  adb -s "$serial" install "$Simplify/reddit-revanced-extended-signed_$reddit_version.apk"
                else
                  echo "${GREEN}[+]$RESET Signatures match. No action needed."
                  echo "[~] Please Wait !! Reinstalling Patched Reddit RVX APK"
                  adb -s "$serial" install -r "$Simplify/reddit-revanced-extended-signed_$reddit_version.apk"
                fi
              else
                echo "${YELLOW}[!]$RESET Failed to fetch the installed APK path. Ensure the app is installed on the device."
                echo "[~] Please Wait !! Installing Patched Reddit RVX APK"
                adb -s "$serial" install "$Simplify/reddit-revanced-extended-signed_$reddit_version.apk"
              fi
            else
              echo "${RED}[x]$RESET Signed Reddit RVX APK file does not exist or Android version is unsupported."
            fi

            if [[ -f "$Simplify/reddit-revanced-extended-signed_$reddit_version.apk" ]]; then
              echo "${BLUE}[i]$RESET Locate Reddit RVX in $Simplify dir, Share it with your Friends and Family ;)"
            fi
          
          elif [[ "$userInput" =~ ^(No|no|N|n)$ ]]; then
            printf "${YELLOW}[!]${RESET} Skip Reddit RVX Patching\n"
          else
            printf "${BLUE}[i]${RESET} Invalid input. Please enter Yes or No.\n"
          fi

        else
          echo "${BLUE}[i]$RESET Reddit App not compatible with Android $Android"
        fi

    fi
fi

# YouTube RVX Android 6-7
if [[ "$Android" -eq "6" ]] || [[ "$Android" -eq "7" ]]; then
  
  # List and then remove existing patch files
  echo "${YELLOW}[!]$RESET Existing patches files:" && ls -l "$patchesRvp"
  echo "[~] Remove existing patches files"
  rm -f "$patchesRvp"
  
  # --- ReVanced Extended CLI ---
  Download_AndCleanup "https://api.github.com/repos/inotia00/revanced-cli/releases/latest" "revanced-cli-[0-9]+.[0-9]+.[0-9]+-all.jar" "jar"
  # --- ReVanced Extended Patches for Android 6-7 ---
  Download_AndCleanup "https://api.github.com/repos/kitadai31/revanced-patches-android6-7/releases/latest" "patches-[0-9]+.[0-9]+.[0-9]+.rvp" "rvp"
  # --- VancedMicroG ---
  Download_AndCleanup "https://api.github.com/repos/inotia00/VancedMicroG/releases/latest" "microg.apk" "apk"

  # Resolve the actual file path for the CLI JAR
  revancedCliJar=$(find "$Simplify" -name "revanced-cli-*-all.jar" | head -n 1)
  patchesRvp=$(find "$Simplify" -name "patches-*.rvp" | head -n 1)
  VancedMicroG=$(find "$Simplify" -name "microg-*.apk" | head -n 1)

  echo "${GREEN}[+] revancedCliJar:${RESET} $revancedCliJar"
  echo "${GREEN}[+] patchesRvp:${RESET} $patchesRvp"
  echo "${GREEN}[+] VancedMicroG:${RESET} $VancedMicroG"


  # --- Download YouTube_17.34.36 ---
  if [[ ! -f "$Downloads/com.google.android.youtube_17.34.36.apk" ]] && [[ "$Android" -eq "6" ]] || [[ "$Android" -eq "7" ]]; then
    echo "[~] Downloading YouTube_17.34.36.apk from GitHub..."
    curl -L -o "$Downloads/com.google.android.youtube_17.34.36.apk" "https://github.com/arghya339/Simplify/releases/download/all/com.google.android.youtube_17.34.36.apk"
  fi
  if [[ -f "$Downloads/com.google.android.youtube_17.34.36.apk" ]] && [[ "$Android" -eq "6" ]] || [[ "$Android" -eq "7" ]]; then
    echo "${GREEN}[+]$RESET YouTube_17.34.36 already exists in $Downloads dir..."
    echo "[~] Patching YouTube_17.34.36..."
    java -jar "$revancedCliJar" patch -p "$patchesRvp" -o "$Simplify/youtube-revanced-extended_17.34.36.apk" "$Downloads/com.google.android.youtube_17.34.36.apk" \
      -e "Visual preferences icons" \
      -e "Change version code" \
      -e "Custom header for YouTube" -OcustomHeader="$Simplify/branding/youtube/header/google_family" \
      -e "Custom branding icon for YouTube" -OappIcon="$Simplify/branding/youtube/launcher/google_family" \
      -e "Custom branding name for YouTube" -OappName="YouTube RVX" \
      -e "Force hide player buttons background" \
      -e "materialyou" \
      -e "Return YouTube Username" \
      -e "Spoof app version" \
      -e "Custom Shorts action buttons" -OiconType="round" \
      -e "GmsCore support" -OgmsCoreVendorGroupId="app.revanced" -OcheckGmsCore=true \
      -e "Hide shortcuts" -Oshorts=false \
      -e "Theme" -OdarkThemeBackgroundColor="@android:color/black" -OlightThemeBackgroundColor="@android:color/white" \
      "${ripLib[@]}" --purge \
      --unsigned | tee "$Simplify/yt-rvx-a6_7_patch-log.txt"
      # -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \  # don't have com.mgoogle option in GmsCore support patch
      # -e "Overlay buttons" -OiconType="thin" \  # thin icon compile bug in Overlay buttons patch
      # --custom-aapt2-binary="$Simplify/aapt2" > "$Simplify/yt-rvx-a6_7_patch-log.txt"  # Redirect patch log to a .txt file without display log in Terminal
    rm -rf "$Simplify/youtube-revanced-extended_17.34.36-temporary-files"
    rm -f "$patchesRvp"
    rm -f "$Downloads/com.google.android.youtube_17.34.36.apk"
  elif [[ ! -f "$Simplify/youtube-revanced-extended_17.34.36.apk" ]] && [[ "$Android" -eq "6" ]] || [[ "$Android" -eq "7" ]]; then
    echo "${RED}[x]$RESET Oops, YouTube 17.34.36 Patching failed! Logs saved to $Simplify/yt-rvx-a6_7_patch-log.txt. Share the patch log with the developer."
  fi

  if [[ -f "$Simplify/youtube-revanced-extended_17.34.36.apk" ]] && [[ "$Android" -eq "6" ]] || [[ "$Android" -eq "7" ]]; then
    echo "[~] Signing YouTube RVX 17.34.36..."
    apksigner sign --ks "$Simplify/ks.keystore" --ks-key-alias "ReVancedKey" --ks-pass pass:"123456" --key-pass pass:"123456" --out "$Simplify/youtube-revanced-extended-signed_17.34.36.apk" "$Simplify/youtube-revanced-extended_17.34.36.apk"
  fi
  if [[ -f "$Simplify/youtube-revanced-extended-signed_17.34.36.apk" ]] && [[ "$Android" -eq "6" ]] || [[ "$Android" -eq "7" ]]; then
    rm -f "$Simplify/youtube-revanced-extended_17.34.36.apk"
    rm -f "$Simplify/youtube-revanced-extended-signed_17.34.36.apk.idsig"
  elif [[ ! -f "$Simplify/youtube-revanced-extended-signed_17.34.36.apk" ]] && [[ "$Android" -eq "6" ]] || [[ "$Android" -eq "7" ]]; then
    echo "${RED}[x]$RESET Oops, YouTube RVX 17.34.36 Signing failed!"
  fi

  # --- Verify signature info ---
  if [[ -f "$Simplify/youtube-revanced-extended-signed_17.34.36.apk" ]] && [[ "$Android" -eq "6" ]] || [[ "$Android" -eq "7" ]]; then
    echo "[~] Verifying Signature info of the signed APK..."
    # Get the signer information for the signed APK
    signedSignature=$(apksigner verify -v --print-certs "$Simplify/youtube-revanced-extended-signed_17.34.36.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
    echo "${BLUE}[i] Signed APK Certificate:${RESET} $signedSignature" # Write-Host "Signed APK Certificate: $($signedSignature.Line)"
    # Get the path of the installed APK on the device
    echo "[~] Fetching installed YouTube RVX 17.34.36 APK path from the device..." # Write-Host "Fetching installed YT Music RVX APK path from the device..."
    YouTubeRVXPath=$(adb -s "$serial" shell pm path app.rvx.android.youtube | sed 's/package://')
    if [[ -n "$YouTubeRVXPath" ]]; then
      # Pull the APK from the device
      echo "[~] Pulling YouTube RVX 17.34.36 APK from device: $YouTubeRVXPath"
      adb -s "$serial" pull "$YouTubeRVXPath" "$Simplify/base.apk"
      # Verify the signer information of the pulled APK
      echo "[~] Verifying Signature info of the pulled YouTube RVX 17.34.36 APK..."
      baseSignature=$(apksigner verify -v --print-certs "$Simplify/base.apk" | grep 'Signer #1 certificate DN:' | cut -d ':' -f 2-)
      echo "${BLUE}[i]$RESET Pulled YouTube RVX 17.34.36 APK Certificate: $baseSignature"
      rm -f "$Simplify/base.apk"
      # Compare the two signatures
      if [[ "$signedSignature" != "$baseSignature" ]]; then
        echo "${YELLOW}[!]$RESET Signatures do not match! Uninstalling the YouTube RVX 17.34.36 app from the device..."
        adb -s "$serial" uninstall "app.rvx.android.youtube"
        echo "[~] Please Wait !! Installing Patched YouTube RVX 17.34.36 APK"
        adb -s "$serial" install "$Simplify/youtube-revanced-extended-signed_17.34.36.apk"
      else
        echo "${GREEN}[+]$RESET Signatures match. No action needed."
        echo "[~] Please Wait !! Reinstalling Patched YouTube RVX 17.34.36 APK"
        adb -s "$serial" install -r "$Simplify/youtube-revanced-extended-signed_17.34.36.apk"
      fi
    else
      echo "${YELLOW}[!]$RESET Failed to fetch the installed YouTube RVX 17.34.36 APK path. Ensure the app is installed on the device."
      echo "[~] Please Wait !! Installing Patched YouTube RVX 17.34.36 APK"
      adb -s "$serial" install "$Simplify/youtube-revanced-extended-signed_17.34.36.apk"
    fi
  else
    echo "${RED}[x]$RESET Signed YouTube RVX 17.34.36 APK file does not exist or Android version is unsupported."
  fi

  # --- Install the APK file (for Android version 6-7) with the adb installer ---
  VancedMicroGInstalledStatus=$(adb -s $serial shell dumpsys package com.mgoogle.android.gms)
  if [[ -f "$Simplify/youtube-revanced-extended-signed_17.34.36.apk" ]] && [[ -f "$VancedMicroG" ]] && [[ "$VancedMicroGInstalledStatus" == *"Unable to find package"* ]] && [[ "$Android" -eq 6 ]] || [[ "$Android" -eq "7" ]]; then
    echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
    echo "[~] installing $filenameWithTag"
    adb -s $serial install $VancedMicroG
  fi
  VancedMicroGPath=$(adb -s "$serial" shell pm path com.mgoogle.android.gms)
  VancedMicroGVersion=$(adb -s $serial shell dumpsys package com.mgoogle.android.gms | grep versionName | sed 's/versionName=//;s/^[[:space:]]*//;s/[[:space:]]*$//')
  if [[ -f "$Simplify/youtube-revanced-extended-signed_17.34.36.apk" ]] && [[ -f "$VancedMicroG" ]] && [[ -n "$VancedMicroGPath" ]] && [[ "microg-v$VancedMicroGVersion.apk" != "$filenameWithTag" ]] && [[ "$Android" -eq 6 ]] || [[ "$Android" -eq "7" ]]; then
    echo "${BLUE}[i]$RESET VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
    echo "${YELLOW}[!]$RESET you already have VancedMicroG_v$VancedMicroGVersion, you need to uninstall it and you want to install the $filenameWithTag app"
    echo "[~] uninstalling VancedMicroG_v$VancedMicroGVersion app from device"
    adb -s $serial uninstall com.mgoogle.android.gms
    echo "[~] installing $filenameWithTag app"
    adb -s "$serial" install "$VancedMicroG"
  fi

  if [[ -f "$Simplify/youtube-revanced-extended-signed_17.34.36.apk" ]] && [[ "$Android" -eq "6" ]] || [[ "$Android" -eq "7" ]]; then
    echo "${BLUE}[i]$RESET Locate YouTube RVX 17.34.36 in $Simplify dir. Share it with your friends and family!"
  fi

else
  echo "${BLUE}[i]$RESET This YouTube 17.34.36 app was made for older Android versions."
fi

# Prompt the user
userInput=$(Write_ColoredPrompt "[?]" "yellow" "Are you want any new Feature in this script? (Yes/No) ")
# Check the user's input
if [[ "$userInput" =~ ^(Yes|yes|Y|y)$ ]]; then
    echo "[~] Wait, Creating a new Feature request Template using your key words..."
    feature_description=$(Write_ColoredPrompt "[?]" "yellow" "Please discribe whats new Feature you want in this script? (Write here...)")
    open "https://github.com/arghya339/Simplify/issues/new?title=Feature&body=$feature_description."
    printf "${GREEN}❤️ Thanks for improving Simplify!"
elif [[ "$userInput" =~ ^(No|no|N|n)$ ]]; then
    echo "[~] Proceeding..."
else
    printf "${BLUE}[i]${RESET} Invalid input. Please enter Yes or No.\n"
fi

# Prompt the user
userInput=$(Write_ColoredPrompt "[?]" "yellow" "Are you find any Bugs in this script? (Yes/No) ")
# Check the user's input
if [[ "$userInput" =~ ^(Yes|yes|Y|y)$ ]]; then
    echo "[~] Wait, Creating a new Bug reporting Template using your key words..."
    issue_description=$(Write_ColoredPrompt "[?]" "yellow" "Please discribe whats not working in this script? (Write here...)")
    open "https://github.com/arghya339/Simplify/issues/new?title=Bug&body=$issue_description."
    printf "${GREEN}🖤 Thanks for provide feedback"
elif [[ "$userInput" =~ ^(No|no|N|n)$ ]]; then
    echo "${GREEN}💐 Thanks for choosing Simplify!"
else
    printf "${BLUE}[i]${RESET} Invalid input. Please enter Yes or No.\n"
fi

# --- Open a URL in the default browser ---
echo "${YELLOW}⭐ Star & 🍻 Fork me..."
open "https://github.com/arghya339/Simplify"
echo "${YELLOW}💲 Donation: PayPal/@arghyadeep339"
open "https://www.paypal.com/paypalme/arghyadeep339"
echo "${YELLOW}🔔 Subscribe: YouTube/@MrPalash360"
open "https://www.youtube.com/channel/UC_OnjACMLvOR9SXjDdp2Pgg/videos?sub_confirmation=1"
echo "${YELLOW}📣 Follow: Telegram"
open "https://t.me/MrPalash360"
echo "${YELLOW}💬 Join: Telegram"
open "https://t.me/MrPalash360Discussion"

# --- Show developer info ---
echo "${GREEN}✅ *Done"
echo "${GREEN}✨ Powered by ReVanced (revanced.app)"
open "https://revanced.app/"
echo "${GREEN}🧑‍💻 Author arghya339 (github.com/arghya339)"
echo ""
#########################################################