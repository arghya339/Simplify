#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

confirmPrompt() {
  Prompt=${1}
  local -n prompt_buttons=$2
  Selected=${3}
  if [ -n "$Selected" ]; then
    ([ "$Selected" == "0" ] || [ "$Selected" == "true" ] || [ "$Selected" == "on" ] || [ "$Selected" == "enable" ]) && Selected=0 || Selected=1  # (0 1)/(true false)/(on off)/(enable disable)
  else
    Selected=0
  fi
  maxLen=$cols
  
  # breaks long prompts into multiple lines (50 characters per line)
  lines=()  # empty array
  while [ -n "$Prompt" ]; do
    lines+=("${Prompt:0:$maxLen}")  # take first 50 characters from $Prompt starting at index 0
    Prompt="${Prompt:$maxLen}"  # removes first 50 characters from $Prompt by starting at 50 to 0
  done
  
  # print all-lines except last-line
  last_line_index=$(( ${#lines[@]} - 1 ))  # ${#lines[@]} = number of elements in lines array
  for (( i=0; i<last_line_index; i++ )); do
    echo -e "${lines[i]}"
  done
  last_line="${lines[$last_line_index]}"
  
  echo -ne '\033[?25l'  # Hide cursor
  while true; do
    show_prompt() {
      echo -ne "\r\033[K"  # n=noNewLine r=returnCursorToStartOfLine \033[K=clearLine
      echo -ne "$last_line "
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