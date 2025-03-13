# --- Define the eye color (adjust as desired) ---
$eyeColor = 'Green'  # primary color
# Construct the eye shape using string concatenation
$eye = @"
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
"@
# Set the console foreground color for the eyes
Write-Host $eye -ForegroundColor $eyeColor
Write-Host ""  # Space

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "# --- Colored log indicators  ---"
Write-Host "[+]" -ForegroundColor Green "-good"  # "[🗸]"
Write-Host "[x]" -ForegroundColor Red "-bad"  # "[✘]"
Write-Host "[i]" -ForegroundColor Blue "-info"
Write-Host "[~]" -ForegroundColor White "-running"
Write-Host "[!]" -ForegroundColor Yellow "-notice"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Checking Internet Connection using google.com IPv4-IP Address (8.8.8.8) ---
Write-Host "[~]" -ForegroundColor White "Checking internet Connection..."
if (!(Test-Connection 8.8.8.8 -Count 1 -Quiet)) {
  Write-Host "[x]" -ForegroundColor Red "Oops! No Internet Connection available.`nConnect to the Internet and try again later."
  return 1
}

# --- local Variables ---
$fullScriptPath = $MyInvocation.MyCommand.Path  # running script path
$Downloads = Join-Path $env:USERPROFILE "Downloads"  # Downloads dir
$Simplify = Join-Path $env:USERPROFILE "Simplify"  # $env:USERPROFILE\Simplify dir
# --- Create the $meo directory if it doesn't exist ---
if (!(Test-Path $Simplify)) {
  mkdir $Simplify -Force
}
$OSArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture  # get architecture of Windows

# --- Check for dependencies ---
foreach ($dependency in @("choco", "java", "jdk", "android-sdk", "python"<#, "7z"#>)) {

  $installed = $false
  $version = $null

  # Custom dependency checks
  switch ($dependency) {

      # Check for Chocolatey
      "choco" {
          try {
              $version = choco --version -ErrorAction Stop
              if ($version) {
                  $installed = $true
                  Write-Host "[+]" -ForegroundColor Green "Chocolatey is already installed (Version: $version)."
              }
          } catch {
              $installed = $false
          }
      }

      # Check for Java
      "java" {
          try {
              $version = java -version 2>&1 -ErrorAction Stop # Redirect stderr to stdout
              if ($version -match 'java version "(\d+\.\d+\.\d+)" 2024-07-16 LTS') {
                  $installed = $true
                  Write-Host "[+]" -ForegroundColor Green "Java is already installed (Version: $($version -split '`n')[0])."
              }
          } catch {
              $installed = $false
          }
      }

      # Check for JDK
      "jdk" {
          if (Test-Path "C:\Program Files\AdoptOpenJDK\jdk-8.0.292.10-hotspot\bin") {
              $installed = $true
              Write-Host "[+]" -ForegroundColor Green "AdoptOpenJDK 8 is already installed."
          }
      }

      # Check for Android SDK
      "android-sdk" {
          if (Test-Path "C:\Android\android-sdk") {
              $installed = $true
              Write-Host "[+]" -ForegroundColor Green "Android SDK is already installed."
          }
      }

      # Check for Python
      "python" {
          try {
              $versionOutput = python --version 2>&1 # Capture output (both stdout and stderr)
              if ($versionOutput -match "Python (\d+\.\d+\.\d+)") {
                  $installed = $true
                  $version = $Matches[1] # Extract version number using regex
                  Write-Host "[+]" -ForegroundColor Green "Python is already installed (Version: $version)."
              } else {
                  Write-Host "[!]" -ForegroundColor Yellow "Python detected, but version could not be determined."
              }
          } catch {
              $installed = $false
          }
      }
      
      <#
      # Check for 7z
      "7z" {
          try {
              $7zPath = "C:\Program Files\7-Zip\7z.exe"
              if (Test-Path $7zPath) {
                  $version = & $7zPath --version 2>&1
                  if ($version -match '7-Zip (\d+\.\d+)') {
                      $version = $matches[1]
                      $installed = $true
                      Write-Host "[+]" -ForegroundColor Green "Hashcat is already installed and verified (Version: $version)."
                  } else {
                      Write-Host "[!]" -ForegroundColor Yellow "Hashcat version mismatch or not detected correctly."
                  }
              }
          } catch {
              $installed = $false
          }
      }
      #>
      
      # General executable check for unknown dependencies
      default {
          if (Get-Command $dependency -ErrorAction SilentlyContinue) {
              $installed = $true
              Write-Host "[+]" -ForegroundColor Green "'$dependency' is already installed."
          }
      }
  }

  # If the dependency is not installed, attempt to install it
  if (-not $installed) {
      Write-Host "[!]" -ForegroundColor Yellow "'$dependency' is not installed. Attempting to install..."

      try {
          # Installation Logic
          switch ($dependency) {
              "choco" {
                  Write-Host "[!]" -ForegroundColor Yellow "Installing Chocolatey using Winget..."
                  winget install Chocolatey.Chocolatey --accept-source-agreements --silent --force
                  # Ensure Chocolatey path is in environment variables
                  Write-Host "[!]" -ForegroundColor Yellow "Checking environment variables..."
                  $envPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine") -split ';'
                  if (-not ($envPath -contains "C:\ProgramData\chocolatey\bin")) {
                    $envPath += "C:\ProgramData\chocolatey\bin"
                    [System.Environment]::SetEnvironmentVariable("Path", ($envPath -join ';'), "Machine")
                    Write-Host "[+]" -ForegroundColor Green "Chocolatey path added to environment variables."
                  } else {
                    Write-Host "[!]" -ForegroundColor Green "Chocolatey path already present in environment variables."
                  }
                }
              "java" {
                  Write-Host "[!]" -ForegroundColor Yellow "Installing Oracle JDK 17 using Winget..."
                  winget install Oracle.JDK.17 --accept-source-agreements --silent --force
                  <#
                  # winget already set Oracle.JDK.17 Path in System Environment Variable as C:\Program Files\Common Files\Oracle\Java\javapath
                  # Add Java to Path
                  $jdkPath = 'C:\Program Files\Java\jdk-17\bin'
                  $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
                  if (-not ($currentPath -like "*$jdkPath*")) {
                    $newPath = "$currentPath;$jdkPath"
                    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
                  }
                  #>
                }
              "jdk" {
                  Write-Host "[!]" -ForegroundColor Yellow "Installing AdoptOpenJDK 8 using Winget..."
                  winget install AdoptOpenJDK.OpenJDK.8 --accept-source-agreements --silent --force
                  # winget already set Oracle.JDK.17 Path in System Environment Variable as C:\Program Files\AdoptOpenJDK\jdk-8.0.292.10-hotspot\bin
                  # so remove a this specific path from the system's environment variable using PowerShell
                  #$path = [Environment]::GetEnvironmentVariable("Path", "Machine")
                  #$path = $path -replace [Regex]::Escape("C:\Program Files\AdoptOpenJDK\jdk-8.0.292.10-hotspot\bin") + ";", ""
                  #$path = $path -replace [Regex]::Escape("C:\Program Files\AdoptOpenJDK\jdk-8.0.292.10-hotspot\bin"), ""
                  #[Environment]::SetEnvironmentVariable("Path", $path, "Machine")
                }
              "android-sdk" {
                  Write-Host "[!]" -ForegroundColor Yellow "Installing Android SDK using Chocolatey..."
                  # Install Android SDK using Chocolatey
                  choco install android-sdk -y --no-progress
                  # Add the Android SDK directories to Path (Ensure paths exist before modifying Path)
                  $androidToolsPath = "C:\Android\android-sdk\tools\bin"
                  $androidPlatformToolsPath = "C:\Android\android-sdk\platform-tools"
                  # Get the current system PATH
                  $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
                  # Check if the paths are already in the Path variable to avoid duplicates
                  if ($path -notcontains $androidToolsPath) {
                    $path += ";$androidToolsPath"
                  }
                  if ($path -notcontains $androidPlatformToolsPath) {
                    $path += ";$androidPlatformToolsPath"
                  }
                  # Set the updated PATH variable
                  [Environment]::SetEnvironmentVariable("Path", $path, "Machine")
                }
              "python" {
                  Write-Host "[!]" -ForegroundColor Yellow "Installing Python 3.13 using Winget..."
                  winget install Python.Python.3.13 --accept-source-agreements --silent --force
                  # Add Python.3.13 path in environment variables
                  $path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";$env:USERPROFILE\AppData\Local\Programs\Python\Python313"
                  [Environment]::SetEnvironmentVariable("Path", $path, "Machine")
                  $path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";$env:USERPROFILE\AppData\Local\Programs\Python\Python313\Scripts"
                  [Environment]::SetEnvironmentVariable("Path", $path, "Machine")
                }
              <#
              "7z" {
                  # Install 7zip using Winget due to latest in winget
                  winget install 7zip.7zip --silent --force
                }
              #>
            }

          # Recheck installation to verify success
          $installed = switch ($dependency) {
              "choco" { (choco --version -ErrorAction SilentlyContinue) -ne $null }
              "java" { $version = java -version 2>&1 -ErrorAction SilentlyContinue; $version -match 'java version "(\d+\.\d+\.\d+)" 2024-07-16 LTS' }
              "jdk" { Test-Path "C:\Program Files\AdoptOpenJDK\jdk-8.0.292.10-hotspot\bin" }
              "android-sdk" { Test-Path "C:\Android\android-sdk" }
              "python" { $version = python --version 2>&1 -ErrorAction SilentlyContinue; $version -match "Python (\d+\.\d+\.\d+)" }
              <#"7z" { $version = & $7zPath -version 2>$1; $version -match '7-Zip (\d+\.\d+)' }#>
          }

          if ($installed) {
              Write-Host "[+]" -ForegroundColor Green "'$dependency' installed and verified successfully."
          } else {
              throw "Installation verification failed for '$dependency'."
          }

      } catch {
          Write-Host "[x]" -ForegroundColor Red "Failed to install '$dependency'. Error: $_"
          Write-Host "[!]" -ForegroundColor Yellow "Please install '$dependency' manually and re-run the script."
          exit 1
      }
  }
}

adb devices > $null 2>&1  # Silently Starting adb daemon

# --- Number of devices connected to computer through USB ---
$devices = (adb devices | Select-String -Pattern "\sdevice$")
$devicescount = $devices.Count

# --- Store the serial numbers and models in an array ---
$deviceInfo = @()
if ($devicescount -gt 0) {
    $deviceInfo = $devices | ForEach-Object {
        $serial = ($_ -split "\s+")[0]
        if ($serial -ne "List") {
            $model = adb -s $serial shell "getprop ro.product.model" | Out-String
            $model = $model.Trim()  # Remove any trailing newline or whitespace
            [PSCustomObject]@{
                Serial = $serial
                Model  = $model
            }
        }
    }
}

if ($deviceInfo.Count -ge 7) {
    Write-Host "Error: More than seven devices attached in adb!"
    exit 1
}

# Usage instructions with device model included
function usage {
  Write-Host "[i]" -ForegroundColor Blue "Usage examples:"
  Write-Host "[i]" -ForegroundColor Blue "usage: ~ Set-ExecutionPolicy Bypass -Scope Process -Force; & $fullScriptPath [SERIAL]"
  Write-Host "[i]" -ForegroundColor Blue "The serial number of the device can be found by running ~ adb devices."
  foreach ($device in $deviceInfo) {
      Write-Host "[i]" -ForegroundColor Blue "  $($device.Model) ~ Set-ExecutionPolicy Bypass -Scope Process -Force; & $fullScriptPath $($device.Serial)"
  }
  # Write-Host "[i]" -ForegroundColor Blue "If only one device is connected, the serial number is not needed."
  exit 1
}

# Check if arguments are passed, else show usage
if ($args.Length -eq 0) {
  usage
}

# Assign the passed serial number
$serial = $args[0]

# --- adb dependent Variables ---
$Android = adb -s $serial shell getprop ro.build.version.release  # get device android version
$cpu_abi = adb -s $serial shell getprop ro.product.cpu.abi  # get device arch

# --- Checking Android Version ---
Write-Host "Checking Android Version..."
if ( $Android -le 5 ) {
Write-Host "Android $Android is not supported by RVX Patches."
return 1
}

# --- Check if the device is connected, authorized or offline via adb ---
$deviceOutput = adb devices | Where-Object { $_ -match $serial }
# Check if any matching device output was found
if ($deviceOutput) {
    # Split the output and extract the second field
    $devicestatus = ($deviceOutput | ForEach-Object { $_ -split "\s+" })[1]
    Write-Host "Device status: $devicestatus"
} else {
    Write-Host "No matching device found for serial: $serial"
    $devicestatus = $null
}

if ($devicestatus -eq 'device') {
  Write-Host "[+]" -ForegroundColor Green "Device '$serial' is connected."
} elseif ($devicestatus -eq 'unauthorized') {
  Write-Host "[x]" -ForegroundColor Red "Device '$serial' is not authorized."
  Write-Host "[!]" -ForegroundColor Yellow "Check for a confirmation dialog on your device."
  exit 1  # Exit the script with an errorimmediately and stops the execution
} else {
  Write-Host "[x]" -ForegroundColor Red "Device '$serial' is offline."
  Write-Host "[!]" -ForegroundColor Yellow "Check if the device is connected and USB debugging is enabled."
  exit 1
}

# --- Get the device model ---
if ($serial) {
  Write-Host "Using device serial: $serial"
  
  try {
      # Fetch the product model using adb
      $product_model = adb -s $serial shell "getprop ro.product.model"
      Write-Host "Device model: $product_model"
  }
  catch {
      Write-Host "[x]" -ForegroundColor Red "Error: Couldn't fetch the product model for '$serial' devices."
      exit 1
  }
} else {
  Write-Host "[x]" -ForegroundColor Red "No device found or '$serial' is invalid."
  exit 1
}

Write-Host "[i]" -ForegroundColor Blue "Target device: $serial ($product_model)"

# --- Define a custom function for colored prompts ---
function Write-ColoredPrompt {
  param(
    [string]$Message,
    [ConsoleColor]$ForegroundColor,
    [string]$PromptMessage
  )

  Write-Host $Message -NoNewline -ForegroundColor $ForegroundColor
  Write-Host " " $PromptMessage -NoNewline -ForegroundColor $ForegroundColor  # Apply color to prompt message
  return Read-Host
}

# Download RVX_dl Python script for dynamically download stock apk from GitHub
if (-Not (Test-Path "$Simplify\RVX_dl.py")) {
  Write-Host "Downloading RVX_dl.py from GitHub.."
  # Download the RVX_dl.py script
  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/main/PowerShell/RVX_dl.py" -OutFile "$Simplify\RVX_dl.py"
}

# Check if jq is installed globally
if (Get-Command jq -ErrorAction SilentlyContinue) {
    Write-Host "$GREEN[+]$RESET 'jq' is installed."
    jq --version  # Check and display jq version
} else {
    Write-Host "$YELLOW[!]$RESET 'jq' is not installed."
    Write-Host "[~] Installing jq via winget."
    winget install jq
}

<#
# Check if wget is installed globally
if (Get-Command wget -ErrorAction SilentlyContinue) {
    Write-Host "$GREEN[+]$RESET 'wget' is installed."
    wget --version  # Check and display jq version
} else {
    Write-Host "$YELLOW[!]$RESET 'wget' is not installed."
    Write-Host "[~] Installing wget via winget."
    winget install GnuWin32.Wget
}

# --- Download Custom aap2 binary ---
if (!(Test-Path (Join-Path $Simplify "aapt2"))) {
    # Check if $cpu_abi needs to be renamed
    if ($OSArchitecture -eq "X64") {
      $OSArchitecture = "x86_64"
    } elseif ($OSArchitecture -eq "armeabi_v7a") {
      $OSArchitecture = "x86"
    }
    Write-Host "[~]" -ForegroundColor White "Downloading aapt2 Binary..."
    Invoke-WebRequest -Uri https://github.com/decipher3114/binaries/releases/latest/download/aapt2_$OSArchitecture -OutFile $Simplify\aapt2
}
#>


# --- create a keystore if it doesn't exist using keytool that comes with java 17 ---
if (!(Test-Path (Join-Path $Simplify "ks.keystore"))) {
    Write-Host "[~]" -ForegroundColor White "Creating a keystore for signed apk..."
    keytool -genkey -v -storetype pkcs12 -keystore (Join-Path $Simplify "ks.keystore") -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456
    # keytool -genkey -v -storetype JKS -keystore (Join-Path $Simplify "ks.keystore") -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456 > $null 2>&1  # to discard output.
}
      
# Download build-tool using sdkmanager that comes with android-sdk and using java 8 with set env variable
$env:JAVA_HOME="C:\Program Files\AdoptOpenJDK\jdk-8.0.292.10-hotspot"
Push-Location "C:\Android\android-sdk\tools\bin"; sdkmanager.bat "build-tools;34.0.0"
$env:Path += ";C:\Android\android-sdk\build-tools\34.0.0"
Push-Location $Simplify  # change to $Simplify dir

# --- Function to download and cleanup files ---
# Download the latest file
# Correctly identify lower version number with file as an older version.
# Remove older version file from your storage.
# Download microg.apk and save it as microg-${tag_name}.apk.
function Download-AndCleanup {
    param (
        [string]$RepoUrl,
        [string]$FilePattern,
        [string]$FileExtension
    )

    # Fetch download URL and latest file name
    $response = Invoke-RestMethod -Uri $RepoUrl
    $downloadUrl = $response.assets | Where-Object { $_.name -match $FilePattern } | Select-Object -ExpandProperty browser_download_url
    $latestFilename = $response.assets | Where-Object { $_.name -match $FilePattern } | Select-Object -ExpandProperty name

    # Ensure latest file name and download URL are valid
    if (-not $latestFilename -or -not $downloadUrl) {
        Write-Host "Error: Could not find a matching file for pattern '$FilePattern'." -ForegroundColor Red
        return 1
    }

    # --- Handle MicroG differently ---
    if ($FilePattern -match "microg.apk") {
        $tagName = $response.tag_name
        $filenameWithTag = "microg-$tagName.apk"

        if (Test-Path $filenameWithTag) {
            Write-Host "$filenameWithTag already exists. Skipping download."
        } else {
            Write-Host "Downloading latest version: $latestFilename (as $filenameWithTag)"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $filenameWithTag

            # Remove older versions of MicroG
            Get-ChildItem -Path . -Filter "microg-*.apk" | Where-Object { $_.Name -ne $filenameWithTag } | ForEach-Object {
                Write-Host "Removing older version: $($_.Name)"
                Remove-Item -Path $_.FullName -Force
            }
        }

    # --- Handle Other Files Normally ---
    } else {
        if (Test-Path $latestFilename) {
            Write-Host "File '$latestFilename' already exists. Skipping download."
        } else {
            Write-Host "Downloading latest version: $latestFilename"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $latestFilename

            Write-Host "Cleaning up older versions..."

            # Extract the base name and version from latestFilename
            $baseName = $latestFilename -replace "_.*", ""  # Extract part before "_"
            $latestVersion = $latestFilename -replace ".*_", "" -replace "\..*", ""  # Extract part after "_" and remove extension

            # Find and remove files with lower versions
            Get-ChildItem -Path . -Filter "$baseName*.$FileExtension" | ForEach-Object {
                $fileVersion = $_.Name -replace ".*_", "" -replace "\..*", ""  # Extract version from file name
                if ($fileVersion -ne $latestVersion) {
                    Write-Host "Removing older version: $($_.Name)"
                    Remove-Item -Path $_.FullName -Force
                }
            }
        }
    }
}

# List of all supported ABIs
$all_abis = @("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
# Initialize the ripLib array
$ripLib = @()
# Loop through all ABIs except the detected one and add to ripLib array
foreach ($abi in $all_abis) {
    if ($abi -ne $cpu_abi) {
        $ripLib += "--rip-lib=$abi"
    }
}
# Display the final arguments
Write-Host "[i] cpu_abi: $cpu_abi"
Write-Host "[i] ripLib: $($ripLib -join ' ')"

# --- YouTube & YouTube Music RVX Android 8 and up ---
# --- Download and generate patches.json ---
if ($Android -ge 5) {
    # $patchesRvp = Get-ChildItem -Path $Simplify -Filter "patches-*.rvp"; $patchesRvp | ForEach-Object { Write-Output $_.FullName }; $patchesRvp | ForEach-Object { Remove-Item $_.FullName -Force }
    # --- ReVanced Extended CLI ---
    Download-AndCleanup `
        -RepoUrl "https://api.github.com/repos/inotia00/revanced-cli/releases/latest" `
        -FilePattern "revanced-cli-[0-9]+\.[0-9]+\.[0-9]+-all\.jar" `
        -FileExtension "jar"

    # --- ReVanced Extended Patches ---
    Download-AndCleanup `
        -RepoUrl "https://api.github.com/repos/inotia00/revanced-patches/releases/latest" `
        -FilePattern "patches-[0-9]+\.[0-9]+\.[0-9]+\.rvp" `
        -FileExtension "rvp"

    # --- VancedMicroG ---
    Download-AndCleanup `
        -RepoUrl "https://api.github.com/repos/inotia00/VancedMicroG/releases/latest" `
        -FilePattern "microg.apk" `
        -FileExtension "apk"

    # --- APKEditor ---
    Download-AndCleanup `
        -RepoUrl "https://api.github.com/repos/REAndroid/APKEditor/releases/latest" `
        -FilePattern "APKEditor-[0-9]+\.[0-9]+\.[0-9]+\.jar" `
        -FileExtension "jar"

    # Resolve the actual file path for the CLI JAR
    $revancedCliJar = Get-ChildItem -Path "$Simplify\revanced-cli-*-all.jar" | Select-Object -ExpandProperty FullName
    $patchesRvp = Get-ChildItem -Path "$Simplify\patches-*.rvp" | Select-Object -ExpandProperty FullName
    $VancedMicroG = Get-ChildItem -Path "$Simplify\microg-*.apk" | Select-Object -ExpandProperty FullName
    $APKEditorJar = Get-ChildItem -Path "$Simplify\APKEditor-*.jar" | Select-Object -ExpandProperty FullName

    # --- Generate patches.json file ---
    if (-not (Test-Path "$Simplify\patches.json") -and $Android -ge 8) {
      Write-Host "patches.json doesn't exist, generating patches.json"

      if ($revancedCliJar -and $patchesRvp) {
          java -jar $revancedCliJar patches $patchesRvp
          if ($LASTEXITCODE -eq 0) {
            Write-Host "patches.json generated successfully!"
          } else {
            Write-Host "Error: patches.json was not generated." -ForegroundColor Red
          }
        } else {
          Write-Host "Error: Required files (revanced-cli JAR or patches RVP) are missing." -ForegroundColor Red
        }
    }

    <#
    # --- Download revanced-extended-options.json ---
    if (-not (Test-Path "$Simplify\revanced-extended-options.json") -and 
       (Get-ChildItem "$Simplify\revanced-cli-*-all.jar" | Measure-Object).Count -gt 0 -and 
       (Get-ChildItem "$Simplify\patches-*.rvp" | Measure-Object).Count -gt 0 -and 
       $Android -ge 8) {

       Write-Host "Downloading revanced-extended-options.json..."
       Invoke-WebRequest -Uri "https://github.com/arghya339/Simplify/releases/download/all/revanced-extended.json" `
                      -OutFile "$Simplify\revanced-extended-options.json"
    } elseif ((Test-Path "$Simplify\revanced-extended-options.json") -and ($Android -ge 8)) {
       Write-Host "revanced-extended-options.json already exists in $Simplify directory..."
    }
    #>

    # --- Download branding.zip ---
    if (-not (Test-Path "$Simplify\branding") -and 
       -not (Test-Path "$Simplify\branding.zip") -and 
       (Get-ChildItem "$Simplify\patches-*.rvp" | Measure-Object).Count -gt 0 -and 
       $Android -ge 8) {

       Write-Host "Downloading branding.zip..."
       Invoke-WebRequest -Uri "https://github.com/arghya339/Simplify/releases/download/all/branding.zip" `
                      -OutFile "$Simplify\branding.zip"
    } elseif ((Test-Path "$Simplify\branding") -and ($Android -ge 8)) {
       Write-Host "branding directory already exists in $Simplify directory..."
    }

    # --- Extract branding.zip ---
    if ((Test-Path "$Simplify\branding.zip") -and 
       -not (Test-Path "$Simplify\branding") -and 
       $Android -ge 8) {

       Write-Host "Extracting branding.zip..."
       # Extract the ZIP file to the branding directory
       Expand-Archive -Path "$Simplify\branding.zip" -DestinationPath "$Simplify\branding" -Force

    } elseif ((Test-Path "$Simplify\branding") -and $Android -ge 8) {
       Write-Host "branding directory already exists in $Simplify directory..."
    
    }

    # --- Remove branding.zip ---
    if ((Test-Path "$Simplify\branding") -and 
            (Test-Path "$Simplify\branding.zip") -and 
            $Android -ge 8) {
       Write-Host "Removing branding.zip..."
       Remove-Item "$Simplify\branding.zip" -Force
    }

    # --- Download stock APKs from GitHub using Python by extracting data from patches.json file ---
    if ((Test-Path "$Simplify\patches.json") -and ($Android -ge 8)) {
      Write-Host "Checking for required stock APKs for patching..."
      # --- Locate the downloaded APKs ---
      $downloaded_youtube_apk = Get-ChildItem -Path "$Downloads" -Filter "com.google.android.youtube*.apk" -File | Select-Object -First 1
      $downloaded_yt_music_apk = Get-ChildItem -Path "$Downloads" -Filter "com.google.android.apps.youtube.music*.apk" -File | Select-Object -First 1
      $downloaded_reddit_apk = Get-ChildItem -Path "$Downloads" -Filter "com.reddit.frontpage*.apkm" -File | Select-Object -First 1
      # Function to check if any version of a package exists in $Downloads
      function Check-IfAnyVersionExists {
        param (
          [string]$PackageName,
          [string[]]$Versions
        )
        foreach ($version in $Versions) {
          if ((Test-Path "$Downloads\$PackageName`_$version.apk") -or 
              (Test-Path "$Downloads\$PackageName`_$version.apkm") -or 
              (Test-Path "$Downloads\$PackageName`_$version-$cpu_abi.apk")) {
              return $true # Any of the versions was found
          }
        }
        return $false # None of the versions was found
      }
      # Extract versions from patches.json for YouTube and YouTube Music
      $youtube_versions = (Get-Content "$Simplify\patches.json" | ConvertFrom-Json) | Where-Object { $_.name -eq "com.google.android.youtube" } | Select-Object -ExpandProperty versions
      $yt_music_versions = (Get-Content "$Simplify\patches.json" | ConvertFrom-Json) | Where-Object { $_.name -eq "com.google.android.apps.youtube.music" } | Select-Object -ExpandProperty versions
      $reddit_versions = (Get-Content "$Simplify\patches.json" | ConvertFrom-Json) | Where-Object { $_.name -eq "com.reddit.frontpage" } | Select-Object -ExpandProperty versions
      # If APKs are missing, run the Python script to download them
      if (-not (Check-IfAnyVersionExists -PackageName "com.google.android.youtube" -Versions $youtube_versions) -or 
        -not (Check-IfAnyVersionExists -PackageName "com.google.android.apps.youtube.music" -Versions $yt_music_versions) -or 
        -not (Check-IfAnyVersionExists -PackageName "com.reddit.frontpage" -Versions $reddit_versions)) {
        Write-Host "Downloading missing APK files..."
        Write-Host "[~]" -ForegroundColor White "Installing Python requests library using pip..."
        python -m pip install requests -q
        if ($LASTEXITCODE -ne 0) {
          Write-Host "[x]" -ForegroundColor Red "Failed to install 'requests' using pip. Please check python installation."
          exit 1
        }
        # Pass the USERPROFILE and Downloads as environment variables to Python
        $env:RVX_DOWNLOADS = $Downloads  # Pass the downloads path as env variable for python
        $env:USERPROFILE = $env:USERPROFILE  # this line will pass environment variable to python
        python $Simplify\RVX_dl.py
        # Recheck after downloading
        $downloaded_youtube_apk = Get-ChildItem -Path "$Downloads" -Filter "com.google.android.youtube*.apk" -File | Select-Object -First 1
        $downloaded_yt_music_apk = Get-ChildItem -Path "$Downloads" -Filter "com.google.android.apps.youtube.music*.apk" -File | Select-Object -First 1
        $downloaded_reddit_apk = Get-ChildItem -Path "$Downloads" -Filter "com.reddit.frontpage*.apkm" -File | Select-Object -First 1
      }
      # Check if APKs were successfully located or downloaded
      if (-not $downloaded_youtube_apk -or -not $downloaded_yt_music_apk -or -not $downloaded_reddit_apk) {
        Write-Host "Error: Failed to locate or download one or more APK files. Please check the logs." -ForegroundColor Red
        exit 1
      }
      Write-Host "YouTube APK: $($downloaded_youtube_apk.FullName)"
      Write-Host "YouTube Music APK: $($downloaded_yt_music_apk.FullName)"
      Write-Host "YouTube APK: $($downloaded_reddit_apk.FullName)"
      # --- Get the absolute paths ---
      $youtube_apk_path = $downloaded_youtube_apk.FullName
      $yt_music_apk_path = $downloaded_yt_music_apk.FullName
      $reddit_apk_path = $downloaded_reddit_apk.FullName
      # --- Get the versions from the filenames ---
      $youtube_version = ($downloaded_youtube_apk.Name -split "_")[1] -replace "\.apk$", ""
      $yt_music_version = ($downloaded_yt_music_apk.Name -split "_")[1] -split "-" | Select-Object -First 1
      $reddit_version = ($downloaded_reddit_apk.Name -split "_")[1] -replace "\.apkm$", ""

      if ($Android -ge 8) {
        # --- YouTube RVX ---
        if (($youtube_apk_path -notlike "*Error downloading*") -and (Test-Path $youtube_apk_path) -and ($Android -ge 8)) {
          Write-Host "Downloaded YouTube APK found: $youtube_apk_path"
          # --- Execute ReVanced patching for YouTube ---
          java -jar $revancedCliJar patch -p $patchesRvp <#--legacy-options="$Simplify\revanced-extended-options.json"#> --purge -o "$Simplify\youtube-revanced-extended_$youtube_version.apk" $youtube_apk_path \
            -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
            -e "Custom header for YouTube" -e "Force hide player buttons background" -e "MaterialYou" -e "Return YouTube Username" \
            -e "Custom Shorts action buttons" -OiconType=round -e "Hide shortcuts" -Oshorts=false -e "Overlay buttons" -OiconType=thin \
            -e "Custom branding name for YouTube" -OappName="YouTube RVX" -e "Custom branding icon for YouTube" -OappIcon="$Simplify\branding\youtube\launcher\google_family" \
            -e "Custom header for YouTube" -OcustomHeader="$Simplify\branding\youtube\header\google_family" \
            "$($ripLib -join ' ')" --unsigned -f | Tee-Object -FilePath "$Simplify\yt-rvx-patch_log.txt"
            # --custom-aapt2-binary="$Simplify\aapt2"  # not required
          Remove-Item -Path "$Simplify\youtube-revanced-extended_$youtube_version-temporary-files" -Recurse -Force
        } elseif (-not (Test-Path "$Simplify\youtube-revanced-extended_$youtube_version.apk") -and (Test-Path $youtube_apk_path) -and ($Android -ge 8)) {
          Write-Host "Oops, YouTube Patching failed !! Logs saved to $env:USERPROFILE\Simplify\yt-rvx-patch_log.txt. Share the Patchlog with the developer."
        }
        # --- Signing YouTube RVX ---
        if ((Test-Path "$Simplify\youtube-revanced-extended_$youtube_version.apk") -and ($Android -ge 8)) {
          Write-Host "Signing YouTube RVX..."
          apksigner sign --ks "$Simplify\ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk" "$Simplify\youtube-revanced-extended_$youtube_version.apk"
        } elseif (-not (Test-Path "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk") -and ($Android -ge 8)) {
          Write-Host "Oops, YouTube RVX Signing failed !!"
        }
        if ((Test-Path "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk") -and ($Android -ge 8)) {
          # After Signing, delete the 'idsig' and unsigned files.
          Remove-Item "$Simplify\youtube-revanced-extended_$youtube_version.apk"
          Remove-Item "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk.idsig"
        }
        # --- Verify signature info ---
        if ((Test-Path "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk") -and $Android -ge 8) {
          Write-Host "Verifying Signature info of the signed YouTube RVX APK..."
          # Get the signer information for the signed APK
          $signedSignature = apksigner verify -v --print-certs "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk" | Select-String "Signer .* certificate DN"
          Write-Host "Signed YouTube RVX APK Certificate: $($signedSignature.Line)"
          # Get the path of the installed APK on the device
          Write-Host "Fetching installed YouTube RVX APK path from the device..."
          $YouTubeRVXPath = adb -s $serial shell pm path app.rvx.android.youtube | ForEach-Object { ($_ -replace "package:", "").Trim() }
          if ($YouTubeRVXPath) {
            # Pull the APK from the device
            Write-Host "Pulling YouTube RVX APK from device: $YouTubeRVXPath"
            adb -s $serial pull $YouTubeRVXPath "$Simplify\base.apk"
            # Verify the signer information of the pulled APK
            Write-Host "Verifying Signature info of the pulled YouTube RVX APK..."
            $baseSignature = & apksigner verify -v --print-certs "$Simplify\base.apk" | Select-String "Signer .* certificate DN"
            Write-Host "Pulled YouTube RVX APK Certificate: $($baseSignature.Line)"
            Remove-Item "$Simplify\base.apk" -Force
            # Compare the two signatures
            if ($signedSignature.Line -ne $baseSignature.Line) {
              Write-Host "Signatures do not match! Uninstalling the YouTube RVX app from the device..."
              adb -s $serial uninstall app.rvx.android.youtube
              Write-Host "Please Wait !! Installing Patched YouTube RVX APK"
              adb -s $serial install "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk"
            } else {
              Write-Host "Signatures match. No action needed."
              Write-Host "Please Wait !! Reinstalling Patched YouTube RVX APK"
              adb -s $serial install -r "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk"
            }
          } else {
            Write-Host "Failed to fetch the installed APK path. Ensure the app is installed on the device."
            Write-Host "Please Wait !! Installing Patched YouTube RVX APK"
            adb -s $serial install "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk"
          }
        } else {
          Write-Host "Signed YouTube RVX APK file does not exist or Android version is unsupported."
        }
        # --- Install the APK file with the adb installer ---
        if ((Test-Path "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk") -and (Test-Path "$Simplify\$filename_with_tag") -and ($Android -ge 8)) {
          Write-Host "VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it. If you already have VancedMicroG, you don't need to install it. Do you want to install the VancedMicroG app?"
          adb -s $serial install "$Simplify\$filename_with_tag"
        }
        # Final Message
        if ((Test-Path "$Simplify\youtube-revanced-extended-signed_$youtube_version.apk") -and ($Android -ge 8)) {
          Write-Host "Locate YouTube RVX in '$Simplify' directory. Share it with your Friends and Family ;)"
        }

        # --- YouTube Music RVX ---
        if ($yt_music_apk_path -notmatch "Error downloading" -and (Test-Path $yt_music_apk_path) -and $Android -ge 8) {
          Write-Host "Downloaded YouTube Music APK found: $yt_music_apk_path"
          # --- Execute ReVanced patching for YouTube Music ---
          java -jar $revancedCliJar patch -p $patchesRvp <#--legacy-options="$Simplify\revanced-extended-options.json"#> --purge -o $Simplify\yt-music-revanced-extended_$yt_music_version-$cpu_abi.apk $yt_music_apk_path \
            -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true -e="Return YouTube Username" \
            -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" \
            -e "Custom branding icon for YouTube Music" -OappIcon="$Simplify\branding\music\launcher\google_family" -e "Custom header for YouTube Music" -OcustomHeader="$Simplify\branding\music\header\google_family" \
            --unsigned -f | Tee-Object -FilePath "$Simplify\ytm-rvx-patch_log.txt"
          # --custom-aapt2-binary="$Simplify\aapt2"
          # keytool -genkeypair -alias ReVanced -keyalg RSA -keysize 2048 -validity 70080 -keystore (Join-Path $Simplify "revanced.keystore") -storetype pkcs12<#By default, keytool creates a Java KeyStore (JKS)#> -storepass 123456 -keypass 123456 -dname "CN=ReVanced" -sigalg SHA256withRSA
          # java -jar $revancedCliJar patch -p $patchesRvp <#--legacy-options="$Simplify\revanced-extended-options.json"#> --purge -o $Simplify\yt-music-revanced-extended_$yt_music_version-$cpu_abi.apk $yt_music_apk_path -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true -e "Custom header for YouTube Music" -e="Return YouTube Username" -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" -e "Custom branding icon for YouTube Music" -OappIcon="$Simplify\branding\music\launcher\google_family" -e "Custom header for YouTube Music" -OcustomHeader="$Simplify\branding\music\header\google_family" <#--custom-aapt2-binary="$Simplify\aapt2"#> --rip-lib="" --keystore="$Simplify\revanced.keystore" --keystore-password="123456" --signer=ReVanced --keystore-entry-alias=ReVanced --keystore-entry-password="123456" -f | tee "$Simplify\ytm-rvx-patch_log.txt"
          Remove-Item -Path "$Simplify\yt-music-revanced-extended_$yt_music_version-$cpu_abi-temporary-files" -Recurse -Force
        } elseif (!(Test-Path "$Simplify\yt-music-revanced-extended_$yt_music_version-$cpu_abi.apk") -and (Test-Path $yt_music_apk_path) -and $Android -ge 8) {
          Write-Host "Oops, YouTube Music Patching failed! Logs saved to $env:USERPROFILE\Simplify\ytm-rvx-patch_log.txt. Share the Patchlog with the developer."
        }
        # --- Signing YT Music ---
        if ((Test-Path "$Simplify\yt-music-revanced-extended_$yt_music_version-$cpu_abi.apk") -and $Android -ge 8) {
          Write-Host "Signing YT Music RVX..."
          apksigner sign --ks $Simplify\ks.keystore --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out $Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk $Simplify\yt-music-revanced-extended_$yt_music_version-$cpu_abi.apk
        } elseif (!(Test-Path "$Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk") -and $Android -ge 8) {
        # Add YT Music Signing failed detection logic
          Write-Host "Oops, YT Music RVX Signing failed!!"
        }
        # After signing, delete intermediate files
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk") -and $Android -ge 8) {
          Remove-Item "$Simplify\yt-music-revanced-extended_$yt_music_version-$cpu_abi.apk"
          Remove-Item "$Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk.idsig"
        }
        # --- Verify signature info ---
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk") -and $Android -ge 8) {
          Write-Host "Verifying Signature info of the signed YT Music RVX APK..."
          # Get the signer information for the signed APK
          $signedSignature = apksigner verify -v --print-certs "$Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk" | Select-String "Signer .* certificate DN"
          Write-Host "Signed YT Music RVX APK Certificate: $($signedSignature.Line)"
          # Get the path of the installed APK on the device
          Write-Host "Fetching installed YT Music RVX APK path from the device..."
          $YTMusicRVXPath = adb -s $serial shell pm path app.rvx.android.apps.youtube.music | ForEach-Object { ($_ -replace "package:", "").Trim() }
          if ($YTMusicRVXPath) {
            # Pull the APK from the device
            Write-Host "Pulling YT Music RVX APK from device: $YTMusicRVXPath"
            adb -s $serial pull $YTMusicRVXPath "$Simplify\base.apk"
            # Verify the signer information of the pulled APK
            Write-Host "Verifying Signature info of the pulled YT Music RVX APK..."
            $baseSignature = & apksigner verify -v --print-certs "$Simplify\base.apk" | Select-String "Signer .* certificate DN"
            Write-Host "Pulled YT Music RVX APK Certificate: $($baseSignature.Line)"
            Remove-Item "$Simplify\base.apk" -Force
            # Compare the two signatures
            if ($signedSignature.Line -ne $baseSignature.Line) {
              Write-Host "Signatures do not match! Uninstalling the YT Music RVX app from the device..."
              adb -s $serial uninstall app.rvx.android.apps.youtube.music
              Write-Host "Please Wait! Installing Patched YT Music RVX APK"
              adb -s $serial install "$Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk"
            } else {
              Write-Host "Signatures match. No action needed."
              Write-Host "Please Wait! Reinstalling Patched YT Music RVX APK"
              adb -s $serial install -r "$Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk"
            }
          } else {
            Write-Host "Failed to fetch the installed YT Music RVX APK path. Ensure the app is installed on the device."
            Write-Host "Please Wait! Installing Patched YT Music RVX APK"
            adb -s $serial install "$Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk"
          }
        } else {
          Write-Host "Signed YT Music RVX APK file does not exist or Android version is unsupported."
        }

        # --- install the APK file with the adb installer ---
        $VancedMicroGPath = adb -s $serial shell pm path com.mgoogle.android.gms
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk") -and (Test-Path "$Simplify\$filename_with_tag") -and (!($VancedMicroGPath)) -and $Android -ge 8) {
          Write-Host "VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
          Write-Host "If you already have VancedMicroG, you don't need to install it. Do you want to install the VancedMicroG app?"
          adb -s $serial install "$Simplify\$filename_with_tag"
        }
        # Final Message
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk") -and $Android -ge 8) {
          Write-Host "yt-music-revanced-extended-signed_$yt_music_version-$cpu_abi.apk is located in $Simplify. Share it with your friends and family! ;)"
        }
      } else {
        Write-Host "Latest YouTube and YT Music not compatible with your device"
      }
    
      # --- YouTube Music RVX Android 7 ---
      if ($Android -eq 7) {
        # Download YT Music 6.42.55 APK
        if ((-Not (Test-Path "$Downloads\com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk")) -and $Android -eq 7) {
          Write-Host "Downloading YT Music 6.42.55-$cpu_abi.apk from GitHub..."
          Invoke-WebRequest -Uri "https://github.com/arghya339/Simplify/releases/download/all/com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk" -OutFile "$Downloads\com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk"
        }
        if ((Test-Path "$Downloads\com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk") -and $Android -eq 7) {
          Write-Host "YT Music 6.42.55-$cpu_abi already exists in $Downloads directory."
          java -jar $revancedCliJar patch -p $patchesRvp <#--legacy-options=$Simplify\revanced-extended-options.json#> --purge -o $Simplify\yt-music-revanced-extended_6.42.55-$cpu_abi.apk $Downloads\com.google.android.apps.youtube.music_6.42.55-$cpu_abi.apk \
            -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true \
            -e="Return YouTube Username" -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" \
            -e "Custom branding icon for YouTube Music" -OappIcon="$Simplify\branding\music\launcher\google_family" -e "Custom header for YouTube Music" -OcustomHeader="$Simplify\branding\music\header\google_family" \
            --unsigned -f | Tee-Object -FilePath "$Simplify\ytm-rvx-patch_log.txt"
            # --custom-aapt2-binary="$Simplify\aapt2"
          Remove-Item -Path "$Simplify\yt-music-revanced-extended_6.42.55-$cpu_abi-temporary-files" -Recurse -Force
        } elseif ((-Not (Test-Path "$Simplify\yt-music-revanced-extended_6.42.55-$cpu_abi.apk")) -and $Android -eq 7) {
          Write-Host "Oops, YouTube Music 6.42.55 patching failed! Logs saved to $env:USERPROFILE\Simplify\ytm-rvx-patch_log.txt. Share the patch log with the developer."
        }
        # Signing the patched APK
        if ((Test-Path "$Simplify\yt-music-revanced-extended_6.42.55-$cpu_abi.apk") -and $Android -eq 7) {
          Write-Host "Signing YT Music RVX..."
          apksigner sign --ks "$Simplify\ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk" "$Simplify\yt-music-revanced-extended_6.42.55-$cpu_abi.apk"
        } elseif ((-Not (Test-Path "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk")) -and $Android -eq 7) {
          # Detect if signing failed
          Write-Host "Oops, YT Music RVX 6.42.55 signing failed!"
        }
        # Clean up after successful signing
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk") -and $Android -eq 7) {
          Remove-Item "$Simplify\yt-music-revanced-extended_6.42.55-$cpu_abi.apk" -Force
          Remove-Item "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk.idsig" -Force
        }
        # --- Verify signature info ---
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk") -and $Android -eq 7) {
          Write-Host "Verifying Signature info of the signed YT Music RVX 6.42.55 APK..."
          # Get the signer information for the signed APK
          $signedSignature = apksigner verify -v --print-certs "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk" | Select-String "Signer .* certificate DN"
          Write-Host "Signed YT Music RVX 6.42.55 APK Certificate: $($signedSignature.Line)"
          # Get the path of the installed APK on the device
          Write-Host "Fetching installed YT Music RVX 6.42.55 APK path from the device..."
          $YTMusicRVXPath = adb -s $serial shell pm path app.rvx.android.apps.youtube.music | ForEach-Object { ($_ -replace "package:", "").Trim() }
          if ($YTMusicRVXPath) {
            # Pull the APK from the device
            Write-Host "Pulling YT Music RVX 6.42.55 APK from device: $YTMusicRVXPath"
            adb -s $serial pull $YTMusicRVXPath "$Simplify\base.apk"
            # Verify the signer information of the pulled APK
            Write-Host "Verifying Signature info of the pulled YT Music RVX 6.42.55 APK..."
            $baseSignature = & apksigner verify -v --print-certs "$Simplify\base.apk" | Select-String "Signer .* certificate DN"
            Write-Host "Pulled APK Certificate: $($baseSignature.Line)"
            Remove-Item "$Simplify\base.apk" -Force
            # Compare the two signatures
            if ($signedSignature.Line -ne $baseSignature.Line) {
              Write-Host "Signatures do not match! Uninstalling the YT Music RVX 6.42.55 app from the device..."
              adb -s $serial uninstall app.rvx.android.apps.youtube.music
              Write-Host "Please Wait! Installing Patched YT Music RVX 6.42.55 APK"
              adb -s $serial install "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk"
            } else {
              Write-Host "Signatures match. No action needed."
              Write-Host "Please Wait! Reinstalling Patched APK"
              adb -s $serial install -r "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk"
            }
          } else {
            Write-Host "Failed to fetch the installed YT Music RVX 6.42.55 APK path. Ensure the app is installed on the device."
            Write-Host "Please Wait! Installing Patched YT Music RVX 6.42.55 APK"
            adb -s $serial install "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk"
          }
        } else {
          Write-Host "Signed YT Music RVX 6.42.55 APK file does not exist or Android version is unsupported."
        }
        # --- install the APK file with the adb installer ---
        $VancedMicroGPath = adb -s $serial shell pm path com.mgoogle.android.gms
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk") -and (Test-Path "$Simplify\$filename_with_tag") -and (!($VancedMicroGPath)) -and $Android -eq 7) {
          Write-Host "VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
          Write-Host "If you already have VancedMicroG, you don't need to install it. Do you want to install the VancedMicroG app?"
          adb -s $serial install "$Simplify\$filename_with_tag"
        }
        # Notify user of APK location
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk") -and $Android -eq 7) {
          Write-Host "yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk is located in $Simplify directory. Share it with your friends and family! ;)"
        }
      } else {
        Write-Host "This YT Music 6.42.55 app is made for Android 7."
      }

      # --- YouTube Music RVX Android 5 and 6 ---
      if ($Android -le 6) {
        # Download YT Music 6.20.51 APK
        if ((-Not (Test-Path "$Downloads\com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk")) -and $Android -le 6) {
          Write-Host "Downloading YT Music 6.20.51-$cpu_abi.apk from GitHub..."
          Invoke-WebRequest -Uri "https://github.com/arghya339/Simplify/releases/download/all/com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk" -OutFile "$Downloads\com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk"
        }
        if (Test-Path "$Downloads\com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk") {
          Write-Host "YT Music 6.20.51-$cpu_abi already exists in $Downloads directory."
          java -jar $revancedCliJar patch -p $patchesRvp <#--legacy-options="$Simplify\revanced-extended-options.json"#> --purge -o "$Simplify\yt-music-revanced-extended_6.20.51-$cpu_abi.apk" "$Downloads\com.google.android.apps.youtube.music_6.20.51-$cpu_abi.apk" \
            -e "Change version code" -e "GmsCore support" -OgmsCoreVendorGroupId="com.mgoogle" -OcheckGmsCore=true -e "Return YouTube Username" \
            -e "Custom branding name for YouTube Music" -OappNameNotification="YouTube Music RVX" -OappNameLauncher="YT Music RVX" \
            -e "Custom branding icon for YouTube Music" -OappIcon="$Simplify\branding\music\launcher\google_family" -e "Custom header for YouTube Music" -OcustomHeader="$Simplify\branding\music\header\google_family" \
            --unsigned -f | Tee-Object -FilePath "$Simplify\ytm-rvx-patch_log.txt"
            # --custom-aapt2-binary="$Simplify\aapt2"
          Remove-Item -Path "$Simplify\yt-music-revanced-extended_6.20.51-$cpu_abi-temporary-files" -Recurse -Force
        } elseif (-Not (Test-Path "$Simplify\yt-music-revanced-extended_6.20.51-$cpu_abi.apk")) {
          Write-Host "Oops, YouTube Music 6.20.51 patching failed! Logs saved to 'USERPROFILE\Simplify\ytm-rvx-patch_log.txt'. Share the patch log with the developer."
        }
        # Signing the patched APK
        if (Test-Path "$Simplify\yt-music-revanced-extended_6.20.51-$cpu_abi.apk") {
          Write-Host "Signing YT Music RVX..."
          apksigner sign --ks "$Simplify\ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$Simplify\yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" "$Simplify\yt-music-revanced-extended_6.20.51-$cpu_abi.apk"
        } elseif ((-Not (Test-Path "$Simplify\yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk")) -and $Android -le 6) {
          # Detect if signing failed
          Write-Host "Oops, YT Music RVX 6.20.51 signing failed!"
        }
        # Clean up after successful signing
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk") -and $Android -le 6) {
          Remove-Item "$Simplify\yt-music-revanced-extended_6.20.51-$cpu_abi.apk" -Force
          Remove-Item "$Simplify\yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk.idsig" -Force
        }

        # --- Verify signature info ---
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk") -and $Android -le 6) {
          Write-Host "Verifying Signature info of the signed YT Music 6.20.51 APK..."
          # Get the signer information for the signed APK
          $signedSignature = apksigner verify -v --print-certs "$Simplify\yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk" | Select-String "Signer .* certificate DN"
          Write-Host "Signed YT Music 6.20.51 APK Certificate: $($signedSignature.Line)"
          # Get the path of the installed APK on the device
          Write-Host "Fetching installed YT Music RVX 6.20.51 APK path from the device..."
          $YTMusicRVXPath = adb -s $serial shell pm path app.rvx.android.apps.youtube.music | ForEach-Object { ($_ -replace "package:", "").Trim() }
          if ($YTMusicRVXPath) {
            # Pull the APK from the device
            Write-Host "Pulling YT Music 6.20.51 APK from device: $YTMusicRVXPath"
            adb -s $serial pull $YTMusicRVXPath "$Simplify\base.apk"
            # Verify the signer information of the pulled APK
            Write-Host "Verifying Signature info of the pulled YT Music 6.20.51 APK..."
            $baseSignature = & apksigner verify -v --print-certs "$Simplify\base.apk" | Select-String "Signer .* certificate DN"
            Write-Host "Pulled YT Music 6.20.51 APK Certificate: $($baseSignature.Line)"
            Remove-Item "$Simplify\base.apk" -Force
            # Compare the two signatures
            if ($signedSignature.Line -ne $baseSignature.Line) {
              Write-Host "Signatures do not match! Uninstalling the YT Music 6.20.51 app from the device..."
              adb -s $serial uninstall app.rvx.android.apps.youtube.music
              Write-Host "Please Wait! Installing Patched YT Music 6.20.51 APK"
              adb -s $serial install "$Simplify\yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk"
            } else {
              Write-Host "Signatures match. No action needed."
              Write-Host "Please Wait! Reinstalling Patched YT Music 6.20.51 APK"
              adb -s $serial install -r "$Simplify\yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk"
            }
          } else {
            Write-Host "Failed to fetch the installed YT Music 6.20.51 APK path. Ensure the app is installed on the device."
            Write-Host "Please Wait! Installing Patched YT Music 6.20.51 APK"
            adb -s $serial install "$Simplify\yt-music-revanced-extended-signed_6.20.51-$cpu_abi.apk"
          }
        } else {
          Write-Host "Signed YT Music 6.20.51 APK file does not exist or Android version is unsupported."
        }
        # --- install the APK file (for Android version 6) with the adb installer ---
        $VancedMicroGPath = adb -s $serial shell pm path com.mgoogle.android.gms
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk") -and (Test-Path "$Simplify\$filename_with_tag") -and (!($VancedMicroGPath)) -and $Android -eq 6) {
          Write-Host "VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
          Write-Host "If you already have VancedMicroG, you don't need to install it. Do you want to install the VancedMicroG app?"
          adb -s $serial install "$Simplify\$filename_with_tag"
        }
        # --- Download Vanced MicroG_v0.2.22.212658 from GitHub ---
        if ((!(Test-Path "$Simplify\microg_v0.2.22.apk")) -and $Android -eq 5) {
          Invoke-WebRequest -Uri "https://github.com/TeamVanced/VancedMicroG/releases/download/v0.2.22.212658-212658001/microg.apk" -OutFile "$Simplify\microg_v0.2.22.apk"
        }
        # --- install the APK file (for Android version 5) with the adb installer ---
        $VancedMicroGPath = adb -s $serial shell pm path com.mgoogle.android.gms
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk") -and (Test-Path "$Simplify\microg_v0.2.22.apk") -and (!($VancedMicroGPath)) -and $Android -eq 5) {
          Write-Host "VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it."
          Write-Host "If you already have VancedMicroG, you don't need to install it. Do you want to install the VancedMicroG app?"
          adb -s $serial install "$Simplify\microg_v0.2.22.apk"
        }
        # Final Message
        if ((Test-Path "$Simplify\yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk") -and $Android -le 6) {
          Write-Host "yt-music-revanced-extended-signed_6.42.55-$cpu_abi.apk is located in $Simplify. Share it with your friends and family! ;)"
        }
      } else {
        Write-Host "This YT Music 6.20.51 app is made for older Android versions."
      }
  
      # --- Reddit ReVanced Extended Android 9 and up ---
      if ($Android -ge 9) {
        # Check conditions and execute tasks
        if (-Not (Test-Path "$Downloads\com.reddit.frontpage_$reddit_version.apk") -and (Test-Path "$Downloads\com.reddit.frontpage_$reddit_version.apkm")) {
          Write-Output "Merge splits APKs to standalone APK..."
          # Merge from .apkm to .apk using APKEditor
          java -jar $APKEditorJar m -i $reddit_apk_path -o "$Downloads\com.reddit.frontpage_$reddit_version.apk"
        } elseif (-Not (Test-Path $reddit_apk_path)) {
          Write-Output "Oops, Stock Reddit APKM not found."
        }
        if ((Test-Path "$Downloads\com.reddit.frontpage_$reddit_version.apk") -and (Test-Path "$Downloads\com.reddit.frontpage_$reddit_version.apkm")) {
          Write-Output "Remove Reddit_$reddit_version.apkm..."
          Remove-Item "$Downloads\com.reddit.frontpage_$reddit_version.apkm"
        }
        if (Test-Path "$Downloads\com.reddit.frontpage_$reddit_version.apk") {
          Write-Output "Downloaded Reddit APK found: $Downloads\com.reddit.frontpage_$reddit_version.apk"
          # Execute ReVanced patching for Reddit
          java -jar $revancedCliJar patch -p $patchesRvp <#--legacy-options="$Simplify\revanced-extended-options.json"#> --purge -o "$Simplify\reddit-revanced-extended_$reddit_version.apk" "$Downloads\com.reddit.frontpage_$reddit_version.apk" \
            --rip-lib="" --unsigned -f | Tee-Object -FilePath "$Simplify\reddit-rvx-patch_log.txt"
            # --custom-aapt2-binary="$Simplify\aapt2"
          Remove-Item -Path "$Simplify\reddit-revanced-extended_$reddit_version-temporary-files" -Recurse -Force
        } elseif (-Not (Test-Path "$Simplify\reddit-revanced-extended_$reddit_version.apk")) {
          Write-Output "Oops, Reddit Patching failed!! Logs saved to $env:USERPROFILE\Simplify\reddit-rvx-patch_log.txt. Share the Patchlog with the developer."
        }
        if (Test-Path "$Simplify/reddit-revanced-extended_$reddit_version.apk") {
          # Signing Reddit RVX
          Write-Output "Signing Reddit RVX..."
          apksigner sign --ks "$Simplify\ks.keystore" --ks-key-alias "ReVancedKey" --ks-pass pass:123456 --key-pass pass:123456 --out "$Simplify\reddit-revanced-extended-signed_$reddit_version.apk" "$Simplify\reddit-revanced-extended_$reddit_version.apk"
          # Remove intermediate files
          Remove-Item "$Simplify\reddit-revanced-extended_$reddit_version.apk"
          Remove-Item "$Simplify\reddit-revanced-extended-signed_$reddit_version.apk.idsig"
        # Add Reddit Signing failed detection logic
        } elseif (-Not (Test-Path "$Simplify\reddit-revanced-extended-signed_$reddit_version.apk")) {
          Write-Output "Oops, Reddit RVX Signing failed!!"
        }
        # --- Verify signature info ---
        if ((Test-Path "$Simplify\reddit-revanced-extended-signed_$reddit_version.apk") -and $Android -ge 9) {
          Write-Host "Verifying Signature info of the signed Reddit RVX APK..."
          # Get the signer information for the signed APK
          $signedSignature = apksigner verify -v --print-certs "$Simplify\reddit-revanced-extended-signed_$reddit_version.apk" | Select-String "Signer .* certificate DN"
          Write-Host "Signed Reddit RVX APK Certificate: $($signedSignature.Line)"
          # Get the path of the installed APK on the device
          Write-Host "Fetching installed Reddit RVX APK path from the device..."
          $RedditPath = adb -s $serial shell pm path com.reddit.frontpage | ForEach-Object { ($_ -replace "package:", "").Trim() }
          if ($RedditPath) {
            # Pull the APK from the device
            Write-Host "Pulling Reddit RVX APK from device: $RedditPath"
            adb -s $serial pull $RedditPath "$Simplify\base.apk"
            # Verify the signer information of the pulled APK
            Write-Host "Verifying Signature info of the pulled Reddit RVX APK..."
            $baseSignature = & apksigner verify -v --print-certs "$Simplify\base.apk" | Select-String "Signer .* certificate DN"
            Write-Host "Pulled Reddit RVX APK Certificate: $($baseSignature.Line)"
            Remove-Item "$Simplify\base.apk" -Force
            # Compare the two signatures
            if ($signedSignature.Line -ne $baseSignature.Line) {
              Write-Host "Signatures do not match! Uninstalling the Reddit RVX app from the device..."
              adb -s $serial uninstall com.reddit.frontpage
              Write-Host "Please Wait !! Installing Patched Reddit RVX APK"
              adb -s $serial install "$Simplify\reddit-revanced-extended-signed_$reddit_version.apk"
            } else {
              Write-Host "Signatures match. No action needed."
              Write-Host "Please Wait !! Reinstalling Patched Reddit RVX APK"
              adb -s $serial install -r "$Simplify\reddit-revanced-extended-signed_$reddit_version.apk"
            }
          } else {
            Write-Host "Failed to fetch the installed Reddit RVX APK path. Ensure the app is installed on the device."
            Write-Host "Please Wait !! Installing Patched Reddit RVX APK"
            adb -s $serial install "$Simplify\reddit-revanced-extended-signed_$reddit_version.apk"
          }
        } else {
          Write-Host "Signed Reddit RVX APK file does not exist or Android version is unsupported."
        }
        # Final Message
        if (Test-Path "$Simplify\reddit-revanced-extended-signed_$reddit_version.apk") {
          Write-Output "Locate Reddit RVX in $Simplify dir, Share it with your Friends and Family ;)"
        }
      } else {
        Write-Output "Reddit App not compatible with Android $Android"
      }
  
    }

}

# YouTube RVX Android 6-7
if (($Android -eq 6) -or ($Android -eq 7)) {
  $patchesRvp = Get-ChildItem -Path $Simplify -Filter "patches-*.rvp"; $patchesRvp | ForEach-Object { Write-Output $_.FullName }; $patchesRvp | ForEach-Object { Remove-Item $_.FullName -Force }
  Remove-Item "$patchesRvp" -Force

  # --- ReVanced Extended CLI ---
  Download-AndCleanup `
        -RepoUrl "https://api.github.com/repos/inotia00/revanced-cli/releases/latest" `
        -FilePattern "revanced-cli-[0-9]+\.[0-9]+\.[0-9]+-all\.jar" `
        -FileExtension "jar"
  
  # --- ReVanced Extended Patches for Android 6-7 ---
  Download-AndCleanup `
        -RepoUrl "https://api.github.com/repos/kitadai31/revanced-patches-android6-7/releases/latest" `
        -FilePattern "patches-[0-9]+\.[0-9]+\.[0-9]+\.rvp" `
        -FileExtension "rvp"
  
  # --- VancedMicroG ---
  Download-AndCleanup `
        -RepoUrl "https://api.github.com/repos/inotia00/VancedMicroG/releases/latest" `
        -FilePattern "microg.apk" `
        -FileExtension "apk"

  # Resolve the actual file path for the CLI JAR
  $revancedCliJar = Get-ChildItem -Path "$Simplify\revanced-cli-*-all.jar" | Select-Object -ExpandProperty FullName
  $patchesRvp = Get-ChildItem -Path "$Simplify\patches-*.rvp" | Select-Object -ExpandProperty FullName
  $VancedMicroG = Get-ChildItem -Path "$Simplify\microg-*.apk" | Select-Object -ExpandProperty FullName

  # --- Download YouTube_17.34.36 ---
  if (!(Test-Path "$Downloads\com.google.android.youtube_17.34.36.apk") -and (($Android -eq 6) -or ($Android -eq 7))) {
    Write-Output "Downloading YouTube_17.34.36.apk from GitHub..."
    Invoke-WebRequest -Uri "https://github.com/arghya339/Simplify/releases/download/all/com.google.android.youtube_17.34.36.apk" -OutFile "$Downloads\com.google.android.youtube_17.34.36.apk"
  }
  if ((Test-Path "$Downloads\com.google.android.youtube_17.34.36.apk") -and $Android -le 7) {
    Write-Output "YouTube_17.34.36 already exists in $Downloads..."
    Write-Output "Patching YouTube_17.34.36..."
    java -jar $revancedCliJar patch -p $patchesRvp -o "$Simplify\youtube-revanced-extended_17.34.36.apk" "$Downloads\com.google.android.youtube_17.34.36.apk" \
      <#--legacy-options="$Simplify\revanced-extended-android-6-7-options.json"#><# --custom-aapt2-binary="$Simplify\aapt2"#> -e "Visual preferences icons" -e "Change version code" \
      -e "Custom header for YouTube" -OcustomHeader="$Simplify\branding\youtube\header\google_family" \
      -e "Custom branding icon for YouTube" -OappIcon="$Simplify\branding\youtube\launcher\google_family" \
      -e "Force hide player buttons background" -e "materialyou" -e "Return YouTube Username" -e "Spoof app version" -e "Custom Shorts action buttons" \
      -e "Custom Shorts action buttons" -OiconType="round" \
      -e "GmsCore support" -OgmsCoreVendorGroupId="app.revanced" -OcheckGmsCore=true \
      -e "Hide shortcuts" -Oshorts=false \
      -e "Theme" -OdarkThemeBackgroundColor="@android:color/black" -OlightThemeBackgroundColor="@android:color/white" \
      "$($ripLib -join ' ')" --purge --unsigned | Out-File -FilePath "$Simplify\yt-rvx-a6-7-patch_log.txt"
    Remove-Item -Path "$Simplify\youtube-revanced-extended_17.34.36-temporary-files" -Recurse -Force
    Remove-Item "$patchesRvp" -Force
    Remove-Item "$Downloads\com.google.android.youtube_17.34.36.apk" -Force
  } elseif (!(Test-Path "$Simplify\youtube-revanced-extended_17.34.36.apk") -and $Android -le 7) {
    Write-Output "Oops, YouTube Patching failed! Logs saved to $Simplify\yt-rvx-a6-7-patch_log.txt. Share the patch log with the developer."
  }
  if ((Test-Path "$Simplify\youtube-revanced-extended_17.34.36.apk") -and $Android -le 7) {
    Write-Output "Signing YouTube RVX 17.34.36..."
    apksigner sign --ks "$Simplify\ks.keystore" --ks-key-alias ReVancedKey --ks-pass pass:123456 --key-pass pass:123456 --out "$Simplify\youtube-revanced-extended-signed_17.34.36.apk" "$Simplify\youtube-revanced-extended_17.34.36.apk"
  } elseif ((Test-Path "$Simplify\youtube-revanced-extended-signed_17.34.36.apk") -and $Android -le 7) {
    Remove-Item "$Simplify\youtube-revanced-extended_17.34.36.apk"
    Remove-Item "$Simplify\youtube-revanced-extended-signed_17.34.36.apk.idsig"
  } elseif (!(Test-Path "$Simplify\youtube-revanced-extended-signed_17.34.36.apk") -and $Android -le 7) {
    Write-Output "Oops, YouTube RVX 17.34.36 Signing failed!"
  }
  # --- Verify signature info ---
  if ((Test-Path "$Simplify\youtube-revanced-extended-signed_17.34.36.apk") -and $Android -le 7) {
    Write-Host "Verifying Signature info of the signed YouTube RVX 17.34.36 APK..."
    # Get the signer information for the signed APK
    $signedSignature = apksigner verify -v --print-certs "$Simplify\youtube-revanced-extended-signed_17.34.36.apk" | Select-String "Signer .* certificate DN"
    Write-Host "Signed YouTube RVX 17.34.36 APK Certificate: $($signedSignature.Line)"
    # Get the path of the installed APK on the device
    Write-Host "Fetching installed YouTube RVX 17.34.36 APK path from the device..."
    $YouTubeRVXPath = adb -s $serial shell pm path app.rvx.android.youtube | ForEach-Object { ($_ -replace "package:", "").Trim() }
    if ($YouTubeRVXPath) {
      # Pull the APK from the device
      Write-Host "Pulling YouTube RVX 17.34.36 APK from device: $YouTubeRVXPath"
      adb -s $serial pull $YouTubeRVXPath "$Simplify\base.apk"
      # Verify the signer information of the pulled APK
      Write-Host "Verifying Signature info of the pulled YouTube RVX 17.34.36 APK..."
      $baseSignature = & apksigner verify -v --print-certs "$Simplify\base.apk" | Select-String "Signer .* certificate DN"
      Write-Host "Pulled YouTube RVX 17.34.36 APK Certificate: $($baseSignature.Line)"
      Remove-Item "$Simplify\base.apk" -Force
      # Compare the two signatures
      if ($signedSignature.Line -ne $baseSignature.Line) {
        Write-Host "Signatures do not match! Uninstalling the YouTube RVX 17.34.36 app from the device..."
        adb -s $serial uninstall app.rvx.android.youtube
        Write-Host "Please Wait !! Installing Patched YouTube RVX 17.34.36 APK"
        adb -s $serial install "$Simplify\youtube-revanced-extended-signed_17.34.36.apk"
      } else {
        Write-Host "Signatures match. No action needed."
        Write-Host "Please Wait !! Installing Patched YouTube RVX 17.34.36 APK"
        adb -s $serial install -r "$Simplify\youtube-revanced-extended-signed_17.34.36.apk"
      }
    } else {
      Write-Host "Failed to fetch the installed YouTube RVX 17.34.36 APK path. Ensure the app is installed on the device."
      Write-Host "Please Wait !! Installing Patched YouTube RVX 17.34.36 APK"
      adb -s $serial install "$Simplify\youtube-revanced-extended-signed_17.34.36.apk"
    }
  } else {
    Write-Host "Signed YouTube RVX 17.34.36 APK file does not exist or Android version is unsupported."
  }
  # --- Install the APK file with the adb installer ---
  if ((Test-Path "$Simplify\youtube-revanced-extended-signed_17.34.36.apk") -and (Test-Path "$Simplify\$filename_with_tag") -and $Android -le 7) {
    Write-Host "VancedMicroG is used to run MicroG services without root. YouTube and YouTube Music won't work without it. If you already have VancedMicroG, you don't need to install it. Do you want to install the VancedMicroG app?"
    adb -s $serial install "$Simplify\$filename_with_tag"
  }
  if ((Test-Path "$Simplify\youtube-revanced-extended-signed_17.34.36.apk") -and $Android -le 7) {
    Write-Output "Locate YouTube RVX 17.34.36 in $Simplify. Share it with your friends and family!"
  }
} else {
    Write-Output "This YouTube 17.34.36 app was made for older Android versions."
}

# --- Prompt the user for input ---
$userInput = Write-ColoredPrompt -Message "[?]" -ForegroundColor Yellow -PromptMessage "Are you want any new Feature in this script? (Yes/No)"
# Check the user's input
if ($userInput -in @("Yes", "yes", "Y", "y")) {
  Write-Host "[~]" -ForegroundColor White "Wait, Creating a new Feature request Template using your key words..."
  
  $feature_description = Write-ColoredPrompt -Message "[?]" -ForegroundColor Yellow -PromptMessage "Please discribe whats new Feature you want in this script? (Write here...)"
  Start-Process "https://github.com/arghya339/Simplify/issues/new?title=Feature&body=$feature_description."
  
  Write-Host -ForegroundColor Green "❤️ Thanks for improving Simplify!"

} elseif ($userInput -in @("No", "no", "N", "n")) {
  Write-Host "[~]" -ForegroundColor White "Proceeding..."
} else {
  Write-Host "[i]" -ForegroundColor Blue "Invalid input. Please enter Yes or No."
}

# --- Prompt the user for input ---
$userInput = Write-ColoredPrompt -Message "[?]" -ForegroundColor Yellow -PromptMessage "Are you find any Bugs in this script? (Yes/No)"
# Check the user's input
if ($userInput -in @("Yes", "yes", "Y", "y")) {
  Write-Host "[~]" -ForegroundColor White "Wait, Creating a new Bug reporting Template using your key words..."
  
  $issue_description = Write-ColoredPrompt -Message "[?]" -ForegroundColor Yellow -PromptMessage "Please discribe whats new Feature you want in this script? (Write here...)"
  Start-Process "https://github.com/arghya339/Simplify/issues/new?title=Bug&body=$issue_description."
  
  Write-Host -ForegroundColor Green "🖤 Thanks for provide feedback"

} elseif ($userInput -in @("No", "no", "N", "n")) {
  Write-Host -ForegroundColor Green "💐 Thanks for choosing Simplify!"
} else {
  Write-Host "[i]" -ForegroundColor Blue "Invalid input. Please enter Yes or No."
}

# --- Open a URL in the default browser ---
Write-Host -ForegroundColor Yellow "⭐ Star & 🍻 Fork me..."
Start-Process "https://github.com/arghya339/Simplify"
Write-Host -ForegroundColor Yellow "💲 Donation: PayPal/@arghyadeep339"
Start-Process "https://www.paypal.com/paypalme/arghyadeep339"
Write-Host -ForegroundColor Yellow "🔔 Subscribe: YouTube/@MrPalash360"
Start-Process "https://www.youtube.com/channel/UC_OnjACMLvOR9SXjDdp2Pgg/videos?sub_confirmation=1"
Write-Host -ForegroundColor Yellow "📣 Follow: Telegram"
Start-Process "https://t.me/MrPalash360"
Write-Host -ForegroundColor Yellow "💬 Join: Telegram"
Start-Process "https://t.me/MrPalash360Discussion"

# --- Show developer info ---
Write-Host -ForegroundColor Green "✅ *Done"
Write-Host -ForegroundColor Green "✨ Powered by ReVanced (revanced.app)"
Start-Process "https://revanced.app/"
Write-Host -ForegroundColor Green "🧑‍💻 Author arghya339 (github.com/arghya339)"
Write-Host ""
##############################################################################
