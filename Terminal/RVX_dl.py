import json
import os
import requests
import subprocess
import sys

def extract_latest_versions(json_file):
    """
    Extracts the latest version numbers from patches.json.
    If 'versions' is missing, it will handle the error.
    """
    try:
        with open(json_file, 'r') as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        print(f"Error: Cannot read {json_file}. Check the file path or JSON format.")
        return {}

    latest_versions = {}
    reddit_versions_missing_warned = False  # Flag to track if Reddit warning was shown

    for item in data:
        if 'compatiblePackages' in item and item['compatiblePackages']:
            for package in item['compatiblePackages']:
                name = package['name']
                versions = package.get('versions')

                if versions and isinstance(versions, list):
                    latest_versions[name] = sorted(versions, reverse=True)
                else:
                    if name == "com.reddit.frontpage":
                        if not reddit_versions_missing_warned: # Check flag *before* any Reddit warning
                            print("Warning: Reddit versions are missing or invalid in patches.json.")
                            reddit_versions_missing_warned = True
                        # Do NOT print individual package warning for Reddit *after* the general warning
                        # continue # Optional: Skip to the next package if you want to be extra sure
                    else: # For other packages, keep showing individual warnings
                        print(f"Warning: Invalid or missing versions for package: {name}")

    return latest_versions


def download_apk(base_url, package_name, versions, arch=None, download_dir=os.path.expanduser("~/Downloads")): # Keep default download_dir in function definition
    """
    Downloads the latest available APK, removes old versions, and handles errors.
    """
    if not versions:
        print(f"No valid versions found for {package_name}. Skipping download.")
        return None

    latest_version = versions[0]  # Get the latest version

    if arch:
        latest_file_name = f"{package_name}_{latest_version}-{arch}.apk"
    elif package_name == "com.reddit.frontpage":
        latest_file_name = f"{package_name}_{latest_version}.apkm"  # Reddit uses .apkm
    else:
        latest_file_name = f"{package_name}_{latest_version}.apk"

    latest_file_path = os.path.join(download_dir, latest_file_name)

    # Check if the latest version already exists
    if os.path.exists(latest_file_path):
        print(f"Latest version ({latest_file_name}) already exists. Skipping download.")
        return latest_file_name

    downloaded_file_name = None

    for version in versions:  # Try each version in the list
        if arch:
            file_name = f"{package_name}_{version}-{arch}.apk"
        elif package_name == "com.reddit.frontpage":
            file_name = f"{package_name}_{version}.apkm"
        else:
            file_name = f"{package_name}_{version}.apk"

        url = f"{base_url}{file_name}"
        file_path = os.path.join(download_dir, file_name)

        # Check if this version is already downloaded
        if os.path.exists(file_path):
            print(f"Version ({file_name}) already exists. Skipping download.")
            return file_name

        # Download the file
        try:
            response = requests.get(url, stream=True)
            response.raise_for_status()

            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)

            print(f"Downloaded {file_name} to {download_dir}")
            downloaded_file_name = file_name
            break

        except requests.exceptions.RequestException as e:
            if response.status_code == 404:
                print(f"Error downloading {file_name}: Not Found. Trying another version.")
            else:
                print(f"Download failed: {e}")

    # Remove older versions if a new version was downloaded
    if downloaded_file_name:
        for old_version in versions:
            if old_version != latest_version:
                old_file = f"{package_name}_{old_version}.apk" if package_name != "com.reddit.frontpage" else f"{package_name}_{old_version}.apkm"
                old_file_path = os.path.join(download_dir, old_file)
                if os.path.exists(old_file_path):
                    os.remove(old_file_path)
                    print(f"Removed old version: {old_file}")

    return downloaded_file_name


if __name__ == "__main__":
    # --- Get serial and CPU ABI from environment variables ---
    serial = os.environ.get('RVX_SERIAL')
    arch = os.environ.get('RVX_ARCH')     # Get ARCH from environment variable set by RVX.sh

    # --- Determine the actual HOME path (equivalent of USERPROFILE on macOS) ---
    home_dir = os.environ.get('HOME')
    if not home_dir:
      print("Error: HOME environment variable not found.")
      sys.exit(1)

    # --- Determine the download_dir from environment variables ---
    download_dir = os.environ.get('RVX_DOWNLOADS')
    if not download_dir:
      print("Error: RVX_DOWNLOADS environment variable not found.")
      sys.exit(1)

    # Construct the path to patches.json (in the Simplify directory under the user's home)
    file_path = os.path.join(home_dir, 'Simplify', 'patches.json')

    print(f"File path: {file_path}")

    latest_versions = extract_latest_versions(file_path)

    base_download_url = "https://github.com/arghya339/Simplify/releases/download/all/"

    # If a package name is given in command-line arguments, download only that package
    if len(sys.argv) > 1:
        package_name = sys.argv[1]
        versions = latest_versions.get(package_name)

        if versions:
            downloaded_apk = download_apk(base_download_url, package_name, versions, download_dir=download_dir) # Pass download_dir here
            if downloaded_apk:
                print(f"Downloaded APK: {downloaded_apk}")
        else:
            print(f"{package_name} versions not found in {file_path}")

    # If no arguments, download YouTube, YouTube Music, and Reddit
    else:
        # --- Download YouTube APK ---
        youtube_package_name = "com.google.android.youtube"
        youtube_versions = latest_versions.get(youtube_package_name)
        if youtube_versions:
            downloaded_youtube_apk = download_apk(base_download_url, youtube_package_name, youtube_versions, download_dir=download_dir) # Pass download_dir here
            if downloaded_youtube_apk:
                print(f"Downloaded YouTube APK: {downloaded_youtube_apk}")


        # --- Download YouTube Music APK ---
        yt_music_package_name = "com.google.android.apps.youtube.music"
        yt_music_versions = latest_versions.get(yt_music_package_name)
        if yt_music_versions:
            downloaded_yt_music_apk = download_apk(base_download_url, yt_music_package_name, yt_music_versions, arch, download_dir=download_dir) # Pass download_dir and arch
            if downloaded_yt_music_apk:
                print(f"Downloaded YouTube Music APK: {downloaded_yt_music_apk}")

        # --- Download Reddit APK ---
        reddit_package_name = "com.reddit.frontpage"
        reddit_versions = latest_versions.get(reddit_package_name)

        # If missing, use the hardcoded version
        if not reddit_versions:
            print("Reddit versions are missing in patches.json. Using hardcoded version.")
            reddit_versions = ["2025.05.0-2194266"]

        downloaded_reddit_apk = download_apk(base_download_url, reddit_package_name, reddit_versions, download_dir=download_dir) # Pass download_dir here
        if downloaded_reddit_apk:
            print(f"Downloaded Reddit APK: {downloaded_reddit_apk}")

# brew instll python@3.13
# pip3 install --upgrade pip
# brew install jq
