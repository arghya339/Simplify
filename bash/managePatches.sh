#!/usr/bin/env bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

shopt -s extglob

managePatches() {
  mapfile -t patchNames < <(jq -r --arg pkg "$package" '.[] | select(.compatiblePackages[]?.name == $pkg) | .name' $sourceDir/patches-$patchesVersion.json)
  mapfile -t patchDescriptions < <(jq -r --arg pkg "$package" '.[] | select(.compatiblePackages[]?.name == $pkg) | .description' $sourceDir/patches-$patchesVersion.json)
  mapfile -t compatibleVersions < <(jq -c --arg pkg "$package" '.[] | select(any(.compatiblePackages[]?; .name == $pkg)) | .compatiblePackages[] | select(.name == $pkg) | .versions' $sourceDir/patches-$patchesVersion.json)
  if [ "$patches" == "d4n3436/revanced-patches-android5" ] || [ "$patches" == "inotia00/revanced-patches-arsclib" ]; then
    mapfile -t excludeds < <(jq -r --arg pkg "$package" '.[] | select(.compatiblePackages[]?.name == $pkg) | .excluded' $sourceDir/patches-$patchesVersion.json)
    patchUses=()
    for ((i=0; i<${#excludeds[@]}; i++)); do
      [ "${excludeds[$i]}" == "false" ] && patchUse=true || patchUse=false
      patchUses+=($patchUse)
    done
  else
    mapfile -t patchUses < <(jq -r --arg pkg "$package" '.[] | select(.compatiblePackages[]?.name == $pkg) | .use' $sourceDir/patches-$patchesVersion.json)
  fi

  if [ "$ShowUniversalPatches" == "true" ]; then
    mapfile -t uPatchNames < <(jq -r '.[] | select(.compatiblePackages == null) .name' $sourceDir/patches-$patchesVersion.json)
    mapfile -t uPatchDescriptions < <(jq -r '.[] | select(.compatiblePackages == null) .description' $sourceDir/patches-$patchesVersion.json)
    if [ "$patches" == "d4n3436/revanced-patches-android5" ] || [ "$patches" == "inotia00/revanced-patches-arsclib" ]; then
      mapfile -t uExcludeds < <(jq -r '.[] | select(.compatiblePackages == null) .excluded' $sourceDir/patches-$patchesVersion.json)
      uPatchUses=()
      for ((i=0; i<${#uExcludeds[@]}; i++)); do
        [ "${uExcludeds[i]}" == "false" ] && patchUse=true || patchUse=false
        uPatchUses+=($patchUse)
      done
    else
      mapfile -t uPatchUses < <(jq -r '.[] | select(.compatiblePackages == null) .use' $sourceDir/patches-$patchesVersion.json)
    fi
  fi

  declare -gA itemsStates
  for ((i=0; i<${#patchNames[@]}; i++)); do
    [ "${patchUses[i]}" == "true" ] && patchStates=1 || patchStates=0
    itemsStates["${patchNames[i]}"]=$patchStates
  done

  declare -A defaultItemsStates
  for key in "${!itemsStates[@]}"; do
    defaultItemsStates["$key"]=${itemsStates["$key"]}
  done

  declare -A itemsDescriptions
  for ((i=0; i<${#patchDescriptions[@]}; i++)); do
    itemsDescriptions["${patchNames[i]}"]=${patchDescriptions[i]}
  done

  declare -A itemsVersions
  for ((i=0; i<${#compatibleVersions[@]}; i++)); do
    itemsVersions["${patchNames[i]}"]=${compatibleVersions[i]}
  done

  if [ "$ShowUniversalPatches" == "true" ]; then
    for ((i=0; i<${#uPatchNames[@]}; i++)); do
      patchName="${uPatchNames[i]}"
      [ "${uPatchUses[i]}" == "true" ] && patchStates=1 || patchStates=0
      itemsStates["$patchName"]=$patchStates
      defaultItemsStates["$patchName"]=${itemsStates["$patchName"]}
      itemsDescriptions["$patchName"]="${uPatchDescriptions[i]}"
      itemsVersions["$patchName"]="null"
      patchNames+=("$patchName")
    done
  fi

  selectedItems=()
  for name in "${patchNames[@]}"; do
    if [[ ${itemsStates["$name"]} -eq 1 ]]; then
      selectedItems+=("$name")
    fi
  done
  
  [ $highlightedItem -ge ${#patchNames[@]} ] && highlightedItem=0

  highlightedItem=0
  highlightedButton=0
  includeAllState=0  # 0 for Include All, 1 for Exclude All

  items_per_page=$((rows - 13))

  currentPage=0
  totalPages=$(( (${#patchNames[@]} + items_per_page - 1) / items_per_page ))

  show_menu() {
    printf '\033[2J\033[3J\033[H'
    echo -n "Navigate with [↑] [↓] [→] [←]"
    [ $isMacOS == false ] && echo -n " [PGUP] [PGDN]"
    echo -e "\nToggle with [␣]"
    echo -e "Confirm with [↵]\n"

    start_index=$((currentPage * items_per_page))
    end_index=$((start_index + items_per_page - 1))
    [ $end_index -ge ${#patchNames[@]} ] && end_index=$((${#patchNames[@]} - 1))

    for ((i=start_index; i<=end_index; i++)); do
      name="${patchNames[i]}"
      state=${itemsStates["$name"]}
      [ $state -eq 1 ] && mark="$symbol1" || mark="$symbol0"

      if [ $i -eq $highlightedItem ]; then
        echo -e "${whiteBG}$mark $name${Reset}"
      else
        echo -e "$mark $name"
      fi
    done

    for ((i=end_index+1; i<(start_index + items_per_page); i++)); do
      echo
    done

    [ $includeAllState -eq 0 ] && ieLabel="<Include All>" || ieLabel="<Exclude All>"
    if [ $highlightedButton -eq 0 ]; then
      echo -e "\n${whiteBG}$buttonsSymbol <Select> ${Reset}    <Recommend>     $ieLabel     <Back>"
    elif [ $highlightedButton -eq 1 ]; then
      echo -e "\n  <Select>   ${whiteBG}$buttonsSymbol <Recommend> ${Reset}    $ieLabel     <Back>"
    elif [ $highlightedButton -eq 2 ]; then
      echo -e "\n  <Select>     <Recommend>   ${whiteBG}$buttonsSymbol $ieLabel ${Reset}    <Back>"
    else
      echo -e "\n  <Select>     <Recommend>     $ieLabel   ${whiteBG}$buttonsSymbol <Back> ${Reset}"
    fi

    [ ${#selectedItems[@]} -le 1 ] && echo -e "\nSelected: ${#selectedItems[@]} item" || echo -e "\nSelected: ${#selectedItems[@]} items"

    currentPageItems=$((end_index - start_index + 1))
    previousPageItems=$((currentPage * items_per_page))
    echo "Items: $((previousPageItems + currentPageItems))/${#patchNames[@]}"
  
    [ ${#patchNames[@]} -gt $items_per_page ] && echo "Page $((currentPage + 1))/$totalPages"

    highlightedItemName="${patchNames[$highlightedItem]}"
    [ -n "${itemsVersions[$highlightedItemName]}" ] && echo "${itemsVersions[$highlightedItemName]}"
    [ -n "${itemsDescriptions[$highlightedItemName]}" ] && echo -ne "ⓘ ${itemsDescriptions[$highlightedItemName]}"
  }

  printf '\033[?25l'
  while true; do
    currentPage=$((highlightedItem / items_per_page))
    show_menu
    IFS= read -rsn1 key
      case $key in
        $'\E')  # ESC
          # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
          read -rsn2 -t 0.1 key2
          case "$key2" in
            '[A')  # Up arrow
              if [ $highlightedItem -gt 0 ]; then
                ((highlightedItem--))
              else
                highlightedItem=$((${#patchNames[@]} - 1))
              fi
              ;;
            '[B')  # Dn arrow
              if [ $highlightedItem -lt $(( ${#patchNames[@]} - 1 )) ]; then
                ((highlightedItem++))
              else
                highlightedItem=0
              fi
              ;;
            '[5')  # PgUp
              targetPage=$((currentPage - 1))
              if [ $targetPage -lt 0 ]; then
                 targetPage=$((totalPages - 1))
              fi
              highlightedItem=$((targetPage * items_per_page))
              ;;
            '[6')  # PgDn
              targetPage=$((currentPage + 1))
              if [ $targetPage -ge $totalPages ]; then
               targetPage=0
              fi
              highlightedItem=$((targetPage * items_per_page))
              ;;
            '[C')  # right arrow
              ((highlightedButton++))
              [ $highlightedButton -gt 3 ] && highlightedButton=0 ;;
            '[D')  # left arrow
              ((highlightedButton--))
              [ $highlightedButton -lt 0 ] && highlightedButton=3 ;;
          esac
          ;;
        " ")  # Space
          if [ ${itemsStates["$highlightedItemName"]} -eq 1 ]; then
            itemsStates["$highlightedItemName"]=0
            for i in "${!selectedItems[@]}"; do
              if [ "${selectedItems[i]}" == "$highlightedItemName" ]; then
                unset 'selectedItems[i]'
              fi
            done
            selectedItems=("${selectedItems[@]}")
          else
            itemsStates["$highlightedItemName"]=1
            if [[ ! " ${selectedItems[@]} " =~ " ${highlightedItemName} " ]]; then
              selectedItems+=("$highlightedItemName")
            fi
          fi
          ;;
        "")  # Enter
          if [ $highlightedButton -eq 0 ]; then
            if [ ${#selectedItems[@]} -gt 0 ]; then
              printf '\033[2J\033[3J\033[H'
              for item in "${selectedItems[@]}"; do
                echo "$item"
              done
              break
            else
              printf '\033[2J\033[3J\033[H'
              echo "NO ITEMS SELECTED !!"
              echo; read -p "Press Enter to continue..."
            fi
          elif [ $highlightedButton -eq 1 ]; then
            for key in "${!itemsStates[@]}"; do
              itemsStates["$key"]=${defaultItemsStates["$key"]}
            done
            selectedItems=()
            for name in "${patchNames[@]}"; do
              if [ ${itemsStates["$name"]} -eq 1 ]; then
                selectedItems+=("$name")
              fi
            done
          elif [ $highlightedButton -eq 2 ]; then
            if [ $includeAllState -eq 0 ]; then
              for name in "${patchNames[@]}"; do
                itemsStates["$name"]=1
              done
              selectedItems=("${patchNames[@]}")
              includeAllState=1
            else
              for name in "${patchNames[@]}"; do
                itemsStates["$name"]=0
              done
              selectedItems=()
              includeAllState=0
            fi
          else
            printf '\033[2J\033[3J\033[H'
            return 1
            break
          fi
          ;;
      esac
  done
  printf '\033[?25h'
  if [ $highlightedButton -eq 0 ]; then
    for ((i=0; i<${#patchNames[@]}; i++)); do
      patchName="${patchNames[i]}"
      state="${itemsStates["$patchName"]}"
      [ $state -eq 1 ] && { patchStatesB="true"; excluded=false; } || { patchStatesB="false"; excluded=true; }
      ([ "$patches" == "d4n3436/revanced-patches-android5" ] || [ "$patches" == "inotia00/revanced-patches-arsclib" ]) && { patchKey="excluded"; value="$excluded"; } || { patchKey="use"; value="$patchStatesB"; }
      isUniversal=$(jq -r --arg pn "$patchName" '.[] | select(.name == $pn) | if .compatiblePackages == null then "true" else "false" end' $sourceDir/patches-$patchesVersion.json)
      if [ "$isUniversal" == "true" ]; then
        jq --arg pn "$patchName" --arg key "$patchKey" --argjson v "$value" 'map(if .name == $pn and .compatiblePackages == null then .[$key] = $v else . end)' $sourceDir/patches-$patchesVersion.json > tmp.json && mv tmp.json $sourceDir/patches-$patchesVersion.json
      else
        jq --arg pkg "$package" --arg pn "$patchName" --arg key "$patchKey" --argjson v "$value" 'map(if .name == $pn and any(.compatiblePackages[]?; .name == $pkg) then .[$key] = $v else . end)' $sourceDir/patches-$patchesVersion.json > tmp.json && mv tmp.json $sourceDir/patches-$patchesVersion.json
      fi
    done
    [ $cliv -ge 5 ] && editOptions || editOptionsJson
    buildPatchCmd
    return 0
  fi
}