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
RVX="$Simplify/RVX"
mkdir -p "$Simplify" "$RVX" "$SimplUsr"
Download="/sdcard/Download"

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
  if ! pip list | grep -q "apksigcopier"; then
    pip install apksigcopier > /dev/null 2>&1  # install apksigcopier using pip
  fi
fi

# --- Download and give execute (--x) permission to AAPT2 Binary ---
if [ ! -f "$HOME/aapt2" ]; then
  echo -e "$running Downloading aapt2 binary from GitHub.."
  curl -sL "https://github.com/arghya339/aapt2/releases/download/all/aapt2_$arch" --progress-bar -o "$HOME/aapt2" && chmod +x "$HOME/aapt2"
fi

curl -L "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/dlGitHub.sh" --progress-bar -o $Simplify/dlGitHub.sh > /dev/null 2>&1

curl -L "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/APKMdl.sh" --progress-bar -o $Simplify/APKMdl.sh  > /dev/null 2>&1

curl -L "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/apkInstall.sh" --progress-bar -o $Simplify/apkInstall.sh  > /dev/null 2>&1

# --- Download branding.zip ---
if [ ! -d "$SimplUsr/branding" ] && [ ! -f "$SimplUsr/branding.zip" ]; then
  echo -e "$running Downloading ${Red}branding.zip${Reset} from GitHub.."
  curl -sL "https://github.com/arghya339/Simplify/releases/download/all/branding.zip" --progress-bar -o "$SimplUsr/branding.zip"
fi
# --- Extrct branding.zip ---
if [ -f "$SimplUsr/branding.zip" ] && [ ! -d "$SimplUsr/branding" ]; then
  echo -e "$running Extrcting ${Red}branding.zip${Reset} to $SimplUsr dir.."
  pv "$SimplUsr/branding.zip" | bsdtar -xof - -C "$SimplUsr/" --no-same-owner --no-same-permissions
fi
# --- Remove branding.zip ---
if [ -d "$SimplUsr/branding" ] && [ -f "$SimplUsr/branding.zip" ]; then
  rm "$SimplUsr/branding.zip"
fi

<<comment
# --- Create a ks.keystore for Signing apk ---
if [ ! -f "$Simplify/ks.keystore" ]; then
  echo -e "$running Create a 'ks.keystore' for Signing apk.."
  keytool -genkey -v -storetype pkcs12 -keystore $Simplify/ks.keystore -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456
else
  echo -e "$good 'ks.keystore' already exist in $Simplify dir."
fi
comment

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
  echo -e "RVX. ReVanced Extended\nRVXC. RVX CoreLSPosed\nF. Feature request\nB. Bug report\nS. Support\nA. About\nQ. Quit\n"
  echo -n "Select Patches source: " && read source
  case $source in
    RVX|rvx)
      curl -sL --progress-bar -o "$RVX/RVX.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RVX.sh" > /dev/null 2>&1
      bash "$RVX/RVX.sh"
      sleep 3
      ;;
    RVXC|rvxc)
      if su -c "id" >/dev/null 2>&1; then
        curl -sL --progress-bar -o "$RVX/RVXC.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/Termux/RVXC.sh" > /dev/null 2>&1
        bash "$RVX/RVXC.sh"
      else
        echo -e "$notice SuperUser permission is not granted! RVX CoreLSPosed required SU permission."
      fi
      sleep 3
      ;;
    [Ff]*) feature && sleep 3 ;;
    [Bb]*) bug && sleep 3 ;;
    [Ss]*) support && sleep 3 ;;
    [Aa]*) about && sleep 3 ;;
    [Qq]*) clear && break ;;
    *) echo -e "$info Invalid input! Please enter RVX / RVXC / F / B / S / A / Q." && sleep 3 ;;
  esac
done
################################################################################################