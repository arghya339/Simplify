#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

printArt() {
  FMT_RAINBOW="
    $(printf '\033[38;5;196m')
    $(printf '\033[38;5;202m')
    $(printf '\033[38;5;226m')
    $(printf '\033[38;5;082m')
    $(printf '\033[36m')
    $(printf '\033[38;5;021m')
    $(printf '\033[38;5;093m')
    $(printf '\033[38;5;54m')
    $(printf '\033[35m')
  "
  FMT_RESET=$(printf '\033[0m')
  printf '\033[2J\033[3J\033[H'
  printf '%s   _____%s _%s         %s      %s  __%s_ %s____%s   %s ____  %s\n' $FMT_RAINBOW $FMT_RESET
  printf '%s  / ___/%s(_)%s___ ___ %s ____ %s / %s(_)%s __/%s_  _%s\ \ \ %s\n' $FMT_RAINBOW $FMT_RESET
  printf '%s  \__ \%s/ /%s __ `__ \%s/ __ \%s/ /%s /%s /_/%s / / /%s\ \ \%s\n' $FMT_RAINBOW $FMT_RESET
  printf '%s ___/ /%s /%s / / / / /%s /_/ /%s /%s /%s __/%s /_/ /%s / / /%s\n' $FMT_RAINBOW $FMT_RESET
  printf '%s/____/%s_/%s_/ /_/ /_/%s .___/%s_/%s_/%s_/  %s\__, /%s /_/_/ %s\n' $FMT_RAINBOW $FMT_RESET
  printf '%s      %s %s         %s/_/     %s  %s  %s   %s/____/%s        %s\n' $FMT_RAINBOW $FMT_RESET
  printf '\n'
}