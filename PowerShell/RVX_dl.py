import json
import os
import requests
import subprocess
import sys

def extract_latest_versions(json_file):
    """
    Extracts the name and latest version numbers from the JSON data.
    Handles cases where 'versions' might be missing or invalid.

    Args:
        json_file (str): Path to the JSON file.

    Returns:
        dict: A dictionary with package names as keys and a list of
              versions (sorted in descending order) as values.
    """

    with open(json_file, 'r') as f:
        data = json.load(f)

    latest_versions = {}
    for item in data:
        if 'compatiblePackages' in item and item['compatiblePackages']:
            for package in item['compatiblePackages']:
                name = package['name']
                if name == "com.reddit.frontpage":  # Check if it's the Reddit package
                    versions = package.get('versions')
                    if versions is None:
                        print("Reddit versions are missing in patches.json.")
                        return latest_versions  # Exit the function after printing the message
                else:
                    versions = package.get('versions')
                    if versions is not None and isinstance(versions, list):
                        latest_versions[name] = sorted(versions, reverse=True)
                    else:
                        print(f"Warning: Invalid or missing versions for package: {name}")

    return latest_versions


def download_apk(base_url, package_name, versions, arch=None, download_dir=None, serial=None):
    """
    Downloads an APK file to a specified directory, trying the second latest
    version if the latest is not found.
    Removes older versions of the APK if found, only considering versions
    listed in the 'versions' argument.
    Skips download if the latest version already exists.
    Handles .apkm extension for Reddit.
    """
    if not download_dir:
        download_dir = os.environ.get('USERPROFILE', '') + '\\Downloads'
    latest_version = versions[0]  # Get the latest version from the list
    
    if package_name == "com.google.android.apps.youtube.music":
       if not arch:
        try:
            if serial:
                arch = subprocess.check_output(["adb", "-s", serial, "shell", "getprop", "ro.product.cpu.abi"]).decode().strip()
            else:
                arch = subprocess.check_output(["adb", "shell", "getprop", "ro.product.cpu.abi"]).decode().strip()
        except FileNotFoundError:
            print("Error: adb not found. Please make sure adb is in your system path.")
            return None
       latest_file_name = f"{package_name}_{latest_version}-{arch}.apk"
    elif arch:
        latest_file_name = f"{package_name}_{latest_version}-{arch}.apk"
    elif package_name == "com.reddit.frontpage":  # Use .apkm for Reddit
        latest_file_name = f"{package_name}_{latest_version}.apkm"
    else:
        latest_file_name = f"{package_name}_{latest_version}.apk"

    # Construct the full path for the downloaded file
    latest_file_path = os.path.join(download_dir, latest_file_name)

    # Check if the latest version already exists in the specified directory
    if os.path.exists(latest_file_path):
        print(f"Latest version ({latest_file_name}) already exists in "
              f"{download_dir}. Skipping download.")
        return latest_file_name  # Return the filename if it exists

    downloaded_version = None  # Track the successfully downloaded version
    downloaded_file_name = None  # Track the successfully downloaded filename

    for version in versions:  # Try each version in the list
         if package_name == "com.google.android.apps.youtube.music": # Added this to handle CPU arch
             if not arch:
              try:
                  if serial:
                      arch = subprocess.check_output(["adb", "-s", serial, "shell", "getprop", "ro.product.cpu.abi"]).decode().strip()
                  else:
                       arch = subprocess.check_output(["adb", "shell", "getprop", "ro.product.cpu.abi"]).decode().strip()
              except FileNotFoundError:
                print("Error: adb not found. Please make sure adb is in your system path.")
                return None
             file_name = f"{package_name}_{version}-{arch}.apk"
             url = f"{base_url}{package_name}_{version}-{arch}.apk"
         elif arch:
            file_name = f"{package_name}_{version}-{arch}.apk"
            url = f"{base_url}{package_name}_{version}-{arch}.apk"
         elif package_name == "com.reddit.frontpage":  # Use .apkm for Reddit
            file_name = f"{package_name}_{version}.apkm"
            url = f"{base_url}{package_name}_{version}.apkm"
         else:
             file_name = f"{package_name}_{version}.apk"
             url = f"{base_url}{package_name}_{version}.apk"

        # Construct the full path for the downloaded file
         file_path = os.path.join(download_dir, file_name)

         # Check if this version already exists
         if os.path.exists(file_path):
             print(f"Version ({file_name}) already exists in "
                   f"{download_dir}. Skipping download.")
             downloaded_version = version
             downloaded_file_name = file_name
             break  # Exit the loop

         try:
             response = requests.get(url, stream=True)
             response.raise_for_status()  # Raise an exception for bad status codes

             total_size = int(response.headers.get('content-length', 0))
             downloaded_size = 0

             with open(file_path, 'wb') as f:
                 for chunk in response.iter_content(chunk_size=8192):
                     if chunk:
                         f.write(chunk)
                         downloaded_size += len(chunk)

             # Check if the downloaded file size matches the expected size
             if total_size != 0 and downloaded_size != total_size:
                 print(f"Warning: Downloaded file size ({downloaded_size} bytes) "
                       f"doesn't match expected size ({total_size} bytes). "
                       f"The file might be corrupted.")
             else:
                 print(f"Downloaded {file_name} to {download_dir}")
                 downloaded_version = version
                 downloaded_file_name = file_name
                 break  # Exit the loop after successful download

         except requests.exceptions.RequestException as e:
            if response.status_code == 404:  # Check for "Not Found" error
               print(f"Error downloading {file_name}: Not Found in {base_url} Try another version")
            else:
                print(f"Error downloading {file_name}: {e}")
         except Exception as e:
             print(f"An unexpected error occurred: {e}")
             return  # Exit on unexpected errors

    # Remove older versions if a new version was downloaded
    if downloaded_version:
        for old_version in versions:
            if old_version != downloaded_version:
                if arch:
                    old_file_name = f"{package_name}_{old_version}-{arch}.apk"
                elif package_name == "com.reddit.frontpage":
                    old_file_name = f"{package_name}_{old_version}.apkm"
                else:
                    old_file_name = f"{package_name}_{old_version}.apk"
                old_file_path = os.path.join(download_dir, old_file_name)
                if os.path.exists(old_file_path):
                    os.remove(old_file_path)
                    print(f"Removed old version: {old_file_name} from "
                          f"{download_dir}")

    return downloaded_file_name


if __name__ == "__main__":
    # --- Get serial and CPU ABI from environment variables ---
    serial = os.environ.get('RVX_SERIAL')
    
    # --- Determine the actual $env:USERPROFILE path or set default if not found ---
    home_dir = os.environ.get('USERPROFILE')
    if not home_dir:
        print("Error: USERPROFILE environment variable not found.")
        sys.exit(1)

    # --- Determine the download_dir from  environment variables ---
    download_dir = os.environ.get('RVX_DOWNLOADS')
    if not download_dir:
        print("Error: RVX_DOWNLOADS environment variable not found.")
        sys.exit(1)
    
    file_path = os.path.join(home_dir, 'Simplify', 'patches.json')

    # Print the resolved file path (for debugging)
    print(f"File path: {file_path}")

    latest_versions = extract_latest_versions(file_path)

    base_download_url = ("https://github.com/arghya339/Simplify/"
                         "releases/download/all/")

    # Get the package name from the command-line arguments
    if len(sys.argv) > 1:
        package_name = sys.argv[1]

        # --- Download the APK ---
        versions = latest_versions.get(package_name)
        if versions:
            # Check if an apk for this package and version already exists
             if any(os.path.exists(os.path.join(download_dir, f"{package_name}_{version}.apk")) or os.path.exists(os.path.join(download_dir, f"{package_name}_{version}.apkm"))  for version in versions) :
                 print(f"Skipping download for {package_name}: An APK with one of its versions already exists.")
             else :
                downloaded_apk = download_apk(base_download_url, package_name, versions, serial = serial, download_dir=download_dir)
                if downloaded_apk:
                    print(f"Downloaded APK: {downloaded_apk}")
        else:
            print(f"{package_name} versions not found in {file_path}")

    # --- If no argument is provided, download YouTube, YouTube Music, and Reddit ---
    else:
        # --- Download YouTube APK ---
        youtube_package_name = "com.google.android.youtube"
        youtube_versions = latest_versions.get(youtube_package_name)
        if youtube_versions:
            downloaded_youtube_apk = download_apk(
                base_download_url, youtube_package_name, youtube_versions,  serial=serial, download_dir=download_dir
            )
            if downloaded_youtube_apk:
                youtube_version = downloaded_youtube_apk.split("_")[1].split(".apk")[0]
                print(f"Downloaded YouTube APK: {downloaded_youtube_apk}")
                print(f"YouTube version: {youtube_version}")
        else:
            print(f"YouTube versions not found in {file_path}")
            downloaded_youtube_apk = None

        # --- Download YouTube Music APK ---
        yt_music_package_name = "com.google.android.apps.youtube.music"
        yt_music_versions = latest_versions.get(yt_music_package_name)
        if yt_music_versions:
            downloaded_yt_music_apk = download_apk(
                base_download_url,
                yt_music_package_name,
                yt_music_versions,
                 download_dir=download_dir,
                serial = serial
            )
            if downloaded_yt_music_apk:
                yt_music_version = downloaded_yt_music_apk.split("_")[1].split("-")[0]
                print(f"Downloaded YouTube Music APK: "
                      f"{downloaded_yt_music_apk}")
                print(f"YouTube Music version: {yt_music_version}")
        else:
            print(f"YouTube Music versions not found in {file_path}")
            downloaded_yt_music_apk = None

        # --- Download Reddit APK ---
        reddit_package_name = "com.reddit.frontpage"
        reddit_versions = latest_versions.get(reddit_package_name)

        # Check if Reddit versions are missing
        if reddit_versions is None:
            print("Reddit versions are missing in patches.json.")

        # --- Download Reddit APK ---
        reddit_package_name = "com.reddit.frontpage"

        # --- Hardcode Reddit versions here ---
        reddit_versions = ["2025.05.0-2194266"]  # Replace with the actual versions

        if reddit_versions:
            downloaded_reddit_apk = download_apk(
                base_download_url, reddit_package_name, reddit_versions, download_dir=download_dir
            )
            if downloaded_reddit_apk:
                try:
                    reddit_version = downloaded_reddit_apk.split("_")[1].split(".apkm")[0]
                    print(f"Downloaded Reddit APK: {downloaded_reddit_apk}")
                    print(f"Reddit version: {reddit_version}")
                except IndexError:
                    print(f"Error extracting version from filename: {downloaded_reddit_apk}")
        