<pre>
   _____ _                 ___ ____    ____  
  / ___/(_)___ ___  ____  / (_) __/_  _\ \ \ 
  \__ \/ / __ `__ \/ __ \/ / / /_/ / / /\ \ \
 ___/ / / / / / / / /_/ / / / __/ /_/ / / / /
/____/_/_/ /_/ /_/ .___/_/_/_/  \__, / /_/_/ 
                /_/            /____/        
</pre>
<div align="center">

# SimplifyNext

**A feature-rich, cross-platform shell script designed to automate APK patching process using ReVanced patcher.**

![Bash Script](https://img.shields.io/badge/bash_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)
</div>

## 📱 Preview

<div align="center">
  <a href="https://youtu.be/NJI1n1otUM8" target="_blank">
    <img src="docs/.images/Main.png" alt="Watch the Demo" width="100%" style="border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.2);" />
  </a>
  <p><i>Click the image above to watch the demo video</i></p>
</div>

<br />

<div align="center">

  <img src="docs/.images/Settings.png" height="350" alt="Settings" style="border-radius: 15px; margin: 5px;" />
  <img src="docs/.images/AdvancedSettings.png" height="350" alt="Advanced Settings" style="border-radius: 15px; margin: 5px;" />
  <img src="docs/.images/InstallationOptions.png" height="350" alt="Installation Options" style="border-radius: 15px; margin: 5px;" />
  <img src="docs/.images/SourceActions.png" height="350" alt="Source Actions" style="border-radius: 15px; margin: 5px;" />
  <img src="docs/.images/FileSelectionInterface.png" height="350" alt="File Selection Interface" style="border-radius: 15px; margin: 5px;" />
  <img src="docs/.images/PatchSelectionInterface.png" height="350" alt="Patch Selection Interface" style="border-radius: 15px; margin: 5px;" />
  <img src="docs/.images/Apps.png" height="350" alt="Apps Actions" style="border-radius: 15px; margin: 5px;" />
</div>

## 💪 Features

* **🎮 Interactive:** Full keyboard navigation with visual feedback.
* **🧑‍💻 Simple Interface:** Easy to use.
* **🧑‍🔧 Manage Patch-options:** User-friendly Patch-options Editor.
* **💁 Lightweight:** Smaller size than any other tool.
* **🚀 Faster:** Efficient than other tools.
* **🖥️ Multi-Platform:** Android, Linux (Debian, Fedora, Arch, SUSE, Alpine), macOS and ~~Windows~~ support.
* **⏱️ Save Time:** Save your valuable time by downloading pre-patched apps from a trusted source without patching them yourself.
* **🛜 Hybrid Mode:** Works without internet connection when offline, seamlessly transitions to online features when connected.
* **📁 File Selector:** Built-in feature rich file browser and section interface.
* **🤝 APKMirror Integration:** Download stock APKs directly from APKMirror.
* **🧩 Split APK Support:** Automatically converts .apks, .apkm, and .xapk split-file formats into standalone .apk files during patching.
* **⚡ Aria2 Integration:** Faster, resumable downloads.
* **🎨 Customize:** choose your preferred symbols for toggle-menu, menu-buttons, secure-prompt.
* **🔄 Self-Updating:** Automatically checks for and installs the latest version of the tool.
* **🧹 Clean Options:** Multiple cleanup choices (delete stock APKs, patched APK, CLI, or patches file).
* **🤖 Auto Cleanup:** Automatically deletes patched APK after installation and stock APK after successful patching.
* **📥 Import:** Import Patch Selection and Android Keystore from ReVanced Manager.
* **📤 Export:** Export Patch Selection and Android Keystore for use in ReVanced Manager.
* **🔑 Keystore Management:** Generate new android keystores for APK signing.
* **\*\* GitHub PAT Support:** Increases GH API rate limit from 60 to 5000 requests/hour.
* **👾 Shizuku support:** rish installer support.
* **😎 Smart Install Flow:** Automatically cascades from root (su) to Shizuku (rish) to standard (session) installer based on availability.
* **🎭 Root:** Support mount installation.
* **🛡️ Security Bypass:** Disable Play Protect verification to prevent installation blocking of patched APK.
* **🌐 Universal Patches:** Enable or disable universal patches across all applications.
* **📚 Library Stripping:** Remove unused native libraries for a smaller APK size.
* **📱 DPI Optimization:** Strip unused density resources to reduce APK size.
* **🌍 Locale Reduction:** Remove unnecessary language resources for a more compact APK.
* **📲 Java Version Switching:** Easily switch between Java 17, 21, 25
* **🧠 Java Memory Limits:** Configure JVM heap size (memory allocation) for optimal patching performance.
* **🔍 View Applied Patches:** See all patches currently applied to installed apps.
* **🦾 Perform Operations:** Execute install, uninstall, mount, unmount, delete operations.
* **➕ Custom Sources:** Add custom patches repositories.
* **📋 View Changelog:** See what's new in patches directly in terminal.
* **🔬 Prerelease Patches:** Use upcoming patch versions before their official stable release.
* **🔭 View Patches:** View all available patches directly within terminal interface with full details.
* **</> Source Code:** Open Patches source code URLs directly in browser.
* **✨ More:** and many more... 🙃

## 🛠 Installation & Usage

![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white) ![macOS](https://img.shields.io/badge/mac%20os-000000?style=for-the-badge&logo=macos&logoColor=F0F0F0) ![Fedora](https://img.shields.io/badge/Fedora-294172?style=for-the-badge&logo=fedora&logoColor=white) ![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)![Debian](https://img.shields.io/badge/Debian-D70A53?style=for-the-badge&logo=debian&logoColor=white)![Linux Mint](https://img.shields.io/badge/Linux%20Mint-87CF3E?style=for-the-badge&logo=Linux%20Mint&logoColor=white)![Zorin OS](https://img.shields.io/badge/-Zorin%20OS-%2310AAEB?style=for-the-badge&logo=zorin&logoColor=white)![Kali](https://img.shields.io/badge/Kali-268BEE?style=for-the-badge&logo=kalilinux&logoColor=white) ![Arch](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=fff&style=for-the-badge)![Manjaro](https://img.shields.io/badge/Manjaro-35BF5C?style=for-the-badge&logo=Manjaro&logoColor=white) ![openSUSE](https://img.shields.io/badge/openSUSE-%2364B345?style=for-the-badge&logo=openSUSE&logoColor=white) ![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-%230D597F.svg?style=for-the-badge&logo=alpine-linux&logoColor=white)

[![Termux](https://avatars.githubusercontent.com/u/8104776?s=50)](https://github.com/termux/termux-app/releases)
```sh
curl -sL -o "$HOME/.simplifyx.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/bash/simplifyx.sh" && bash ~/.simplifyx.sh
```
```sh
wget -q -O "$HOME/.simplifyx.sh" "https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/bash/simplifyx.sh" && bash ~/.simplifyx.sh
```

```
simplifyx
```

![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)

[![PowerShell](https://raw.githubusercontent.com/PowerShell/PowerShell/refs/heads/master/assets/ps_black_64.svg)](https://github.com/PowerShell/PowerShell/releases)
```pwsh

```
```pwsh

```

## 🜲 Thanks & Credits

- [ReVanced](https://github.com/ReVanced)
- [Morphe](https://github.com/MorpheApp)

## 💖 Support

This project is open-source and free. If you enjoy using it, consider buying me a coffee!

[![BuyMeACoffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.paypal.com/paypalme/arghyadeep339)

---

<div align="center">
  <p>Made with 💜 for Geeks by <a href="https://github.com/arghya339">Arghya</a></p>
</div>
