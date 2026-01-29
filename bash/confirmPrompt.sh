#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

confirmPrompt() {
  Prompt=${1}
  local -n prompt_buttons=$2
  Selected=${3:-0}
  [[ "$Selected" =~ ^(0|true|on|enable)$ ]] && Selected=0 || Selected=1
  
  # breaks long prompts into multiple lines
  mapfile -t lines < <(fmt -w "$cols" <<< "$Prompt")
  
  # print all-lines except last-line
  last_line_index=$(( ${#lines[@]} - 1 ))  # ${#lines[@]} = number of elements in lines array
  for (( i=0; i<last_line_index; i++ )); do
    echo -e "${lines[i]}"
  done
  
  last_line="${lines[$last_line_index]}"
  llcc=${#last_line}
  bcc=$((${#prompt_buttons[0]} + ${#prompt_buttons[1]}))
  pbcc=$((bcc + 8))
  
  [ $((cols - llcc)) -ge $pbcc ] && fits_on_last=true || { fits_on_last=false; echo -e "$last_line"; }
  
  echo -ne '\033[?25l'  # Hide cursor
  while true; do
    show_prompt() {
      echo -ne "\r\033[K"  # n=noNewLine r=returnCursorToStartOfLine \033[K=clearLine
      [ $fits_on_last == true ] && echo -ne "$last_line "
      [ $Selected -eq 0 ] && echo -ne "${whiteBG}$buttonsSymbol ${prompt_buttons[0]} $Reset   ${prompt_buttons[1]}" || echo -ne "  ${prompt_buttons[0]}  ${whiteBG}$buttonsSymbol ${prompt_buttons[1]} $Reset"  # highlight selected bt with white bg
    }; show_prompt

    read -rsn1 key
    case $key in
      $'\E')
      # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
        read -rsn2 -t 0.1 key2  # -r=readRawInput -s=silent(noOutput) -t=timeout -n2=readTwoChar | waits upto 0.1s=100ms to read key 
        case $key2 in 
          '[C') Selected=1 ;;  # right arrow key
          '[D') Selected=0 ;;  # left arrow key
        esac
        ;;
      [Yy]*) Selected=0; show_prompt; break ;;
      [Nn]*) Selected=1; show_prompt; break ;;
      "") break ;;  # Enter key
    esac
  done
  echo -e '\033[?25h' # Show cursor
  return $Selected  # return Selected int index from this fun
}