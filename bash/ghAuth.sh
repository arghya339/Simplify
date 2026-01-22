#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

ghPAT() {
  echo -e "${running} Creating Personal Access Token.."
  url="https://github.com/settings/tokens/new?scopes=public_repo&description=simplifyNext" # Create a PAT with scope `public_repo`
  if [ $isAndroid == true ]; then termux-open-url "$url"; elif [ $isMacOS == true ]; then open "$url"; else xdg-open "$url" &>/dev/null; fi

  echo -n "PAT: "
  while IFS= read -rsn 1 char; do
    if [[ "$char" == $'\0' || "$char" == $'\n' || "$char" == $'\r' ]]; then
      if [[ -n "$input" && ! "$input" =~ ^[[:space:]] && ! "$input" =~ [[:space:]] ]]; then
        curl -sL -f -H "Authorization: Bearer ${input}" "https://api.github.com/repos/ReVanced/revanced-patches/releases/latest" | jq -r '.tag_name'
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
          echo -e "\n$good ${Green}Successfully added your GitHub PAT.${Reset}"
          echo -e "$notice ${Yellow}Your GitHub API rate limit has been increased!${Reset}"
          break
        else
          echo -ne "\r\033[K"
          echo -e "$notice ${Yellow}Invalid PAT!${Reset}"
          input=""
          echo -n "PAT: "
        fi
      else
        continue
      fi
    fi
    if [[ "$char" == $'\177' ]]; then
      if [ -n "$input" ]; then
        input="${input%?}"
        echo -ne "\b \b"
      fi
      continue
    fi
    if [[ "$char" == $'\E' ]]; then
      read -rsn1 -t 0.1 seq1
      if [[ "$seq1" == '[' ]]; then
        read -rsn2 -t 0.1 seq2
        case "$seq2" in
          '3~')  # Delete
            if [ -n "$input" ]; then
              input="${input%?}"
              echo -ne "\b \b"
            fi
            ;;
        esac
      fi
      continue
    fi
    if [[ "$char" =~ [[:print:]] ]]; then
      input+="$char"
      echo -n "$secureSymbol"
    fi
  done
  config "PAT" "$input"
}

ghAuth() {
  while true; do
    if gh auth status >/dev/null 2>&1 || jq -e '.PAT' "$simplifyNextJson" >/dev/null 2>&1; then
      confirmPrompt "You already have a GitHub token! Do you want to delete it?" "ynButtons" "1" && userInput=Yes || userInput=No
      case "$userInput" in
        Yes)
          if gh auth status >/dev/null 2>&1; then
            gh auth logout
            if [ $isAndroid == true ]; then termux-open-url "https://github.com/settings/applications"; elif [ $isMacOS == true ]; then open "https://github.com/settings/applications"; else xdg-open "https://github.com/settings/applications" &>/dev/null; fi
          elif jq -e '.PAT' "$simplifyNextJson" >/dev/null 2>&1; then
            jq 'del(.PAT)' "$simplifyNextJson" > temp.json && mv temp.json "$simplifyNextJson"
            if [ $isAndroid == true ]; then termux-open-url "https://github.com/settings/tokens"; elif [ $isMacOS == true ]; then open "https://github.com/settings/tokens"; else xdg-open "https://github.com/settings/tokens" &>/dev/null; fi
          fi
          echo -e "$good ${Green}Successfully deleted your GitHub token!${Reset}"
          ;;
        No) break ;;
      esac
    else
      confirmPrompt "Do you want to increase the GitHub API rate limit by adding a github token?" "ynButtons" && userInput=Yes || userInput=No
      case "$userInput" in
        Yes)
          pButtons=("<GH>" "<PAT>"); confirmPrompt "Select a method to create a GitHub access token: (GH) GitHub CLI or (PAT) Personal Access Token" "pButtons" "1" && method=GH || method=PAT
          case "$method" in
            GH)
              if [ $isAndroid == true ]; then
                pkgInstall "gh"
              elif [ $isMacOS == true ]; then
                formulaeInstall "gh"
              fi
              echo -e "$running Creating GitHub access token using GitHub CLI.."
              gh auth login
              gh api "repos/ReVanced/revanced-patches/releases/latest" | cat | jq -r '.tag_name'
              if [ ${PIPESTATUS[0]} -eq 0 ]; then
                echo -e "$good ${Green}Successfully authenticated with GitHub CLI.${Reset}"
                echo -e "$notice ${Yellow}Your GitHub API rate limit has been increased!${Reset}"
                break
              fi
              ;;
            PAT)
              ghPAT
              break
              ;;
          esac
          ;;
        No) break ;;
      esac
    fi
  done
  if gh auth status >/dev/null 2>&1; then
    ghToken="$(gh auth token)"
  elif jq -e '.PAT' "$simplifyNextJson" >/dev/null 2>&1; then
    ghToken="$(jq -r '.PAT' "$simplifyNextJson" 2>/dev/null)"
  fi
  [ -n "$ghToken" ] && ghAuthH="-H \"Authorization: Bearer $ghToken\"" || ghAuthH=""
}