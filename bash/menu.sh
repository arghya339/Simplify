#!/usr/bin/env bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

shopt -s extglob

menu() {
  local -n menu_options=$1
  local -n menu_buttons=$2
  local -n menu_descriptions=$3
  local -n menu_others=$4
  selected_option=${5:-0}  # :- set value as 0 if unset
  selected_button=0
  cItems=7  # 2LnMenuGuide Space + Space menuButtons Space pageStatus
  [ -n "$menu_descriptions" ] && cItems=$((cItems + 2))
  [ -n "$menu_others" ] && cItems=$((cItems + 2))
  items_per_page=$((rows - cItems))
  current_page=0
  total_pages=$(( (${#menu_options[@]} + items_per_page - 1) / items_per_page ))  # Convert to integer from floating point page number

  show_menu() {
    printf '\033[2J\033[3J\033[H'
    # Display guide
    echo -n "Navigate with [↑] [↓] [←] [→]"
    [ $total_pages -gt 1 ] && echo -n " [PGUP] [PGDN]"
    echo -e "\nSelect with [↵]\n"
    
    # Calculate start and end indices for current page
    start_index=$(( current_page * items_per_page ))
    end_index=$(( start_index + (items_per_page - 1) ))
    [ $end_index -ge ${#menu_options[@]} ] && end_index=$((${#menu_options[@]} - 1))
    
    # Display menu options for current page
    for ((i=start_index; i<=end_index; i++)); do
      if [ $i -eq $selected_option ]; then
        echo -e "${whiteBG}$buttonsSymbol ${menu_options[$i]} $Reset"
      else
        [ $(($i + 1)) -le 9 ] && echo " $(($i + 1)). ${menu_options[$i]}" || echo "$(($i + 1)). ${menu_options[$i]}"
      fi
    done
    
    for ((i=end_index+1; i < start_index + items_per_page; i++)); do echo; done  # Fill remaining lines if current page has fewer than items/page options
    
    # Display buttons
    echo
    for ((i=0; i<=$((${#menu_buttons[@]} - 1)); i++)); do
      if [ $i -eq $selected_button ]; then
        [ $i -eq 0 ] && echo -ne "${whiteBG}$buttonsSymbol ${menu_buttons[$i]} $Reset" || echo -ne "  ${whiteBG}$buttonsSymbol ${menu_buttons[$i]} $Reset"
      else
        [ $i -eq 0 ] && echo -n "  ${menu_buttons[$i]}" || echo -n "   ${menu_buttons[$i]}"
      fi
    done
    
    echo
    [ $total_pages -gt 1 ] && echo -ne "\nPage: $((current_page + 1))/$total_pages"  # Display page info if multiple pages exist
    
    [ -n "${menu_others[$selected_option]}" ] && echo -ne "\n${menu_others[$selected_option]}"
    [ -n "${menu_descriptions[$selected_option]}" ] && echo -ne "\nⓘ ${menu_descriptions[$selected_option]}"
  }

  printf '\033[?25l'
  while true; do
    show_menu
    read -rsn1 key
    case $key in
      $'\E')  # ESC
        # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
        read -rsn2 -t 0.1 key2
        case "$key2" in
          '[A')  # Up arrow
            selected_option=$((selected_option - 1))
            [ $selected_option -lt 0 ] && selected_option=$((${#menu_options[@]} - 1))
            current_page=$((selected_option / items_per_page))  # Auto switch page
            ;;
          '[B')  # Down arrow
            selected_option=$((selected_option + 1))
            [ $selected_option -ge ${#menu_options[@]} ] && selected_option=0
            current_page=$((selected_option / items_per_page))  # Auto switch page
            ;;
          '[C')  # Right arrow
            [ $selected_button -lt $((${#menu_buttons[@]} - 1)) ] && selected_button=$((selected_button + 1))
            ;;
          '[D')  # Left arrow
            [ $selected_button -gt 0 ] && selected_button=$((selected_button - 1))
            ;;
          '[5') # Page Up
            read -rsn1 -t 0.1 key3
            if [ "$key3" == "~" ]; then
              current_page=$((current_page - 1))
              [ $current_page -lt 0 ] && current_page=$((total_pages - 1))
              selected_option=$((current_page * items_per_page))  # Update selected option to start indices on new page
            fi
            ;;
          '[6') # Page Down
            read -rsn1 -t 0.1 key3
            if [ "$key3" == "~" ]; then
              current_page=$((current_page + 1))
              [ $current_page -ge $total_pages ] && current_page=0
              selected_option=$((current_page * items_per_page))  # Update selected option to start indices on new page
            fi
            ;;
        esac
        ;;
      '')  # Enter key
        break
        ;;
      [0-9])
        read -rsn2 -t0.5 key2
        [[ "$key2" == [0-9] ]] && { key="${key}${key2}"; key=$((10#$key)); }  # Convert to integer (decimal) from strings
        if [ $key -eq 0 ]; then
          selected_option=$((${#menu_options[@]} - 1))
        elif [ $key -gt ${#menu_options[@]} ]; then
          selected_option=0
        else
          selected_option=$(($key - 1))
        fi
        current_page=$((selected_option / items_per_page))  # Auto switch page
        show_menu; sleep 0.5; break
       ;;
    esac
  done
  printf '\033[?25h'

  [ $selected_button -eq 0 ] && { printf '\033[2J\033[3J\033[H'; selected=$selected_option; }
  if [ $selected_button -eq $((${#menu_buttons[@]} - 1)) ]; then
    [ "${menu_buttons[$((${#menu_buttons[@]} - 1))]}" == "<Exit>" ] && { [ $isOverwriteTermuxProp -eq 1 ] && sed -i '/allow-external-apps/s/^/# /' "$HOME/.termux/termux.properties"; printf '\033[2J\033[3J\033[H'; echo "Script exited !!"; exit 0; } || { printf '\033[2J\033[3J\033[H'; return 1; }
  fi
}