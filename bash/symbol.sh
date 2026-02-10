#!/bin/bash

# Copyright (C) 2026, Arghyadeep Mondal <github.com/arghya339>

ButtonsSymbol="$(jq -r '.ButtonsSymbol' "$simplifyNextJson" 2>/dev/null)"
case "$ButtonsSymbol" in
  "27A4") buttonsSymbol="➤" ;;
  "27A3") buttonsSymbol="➣" ;;
  "27A2") buttonsSymbol="➢" ;;
  "25B6") buttonsSymbol="▶" ;;
  "25B7") buttonsSymbol="▷" ;;
  "276F") buttonsSymbol="❯" ;;
  "2771") buttonsSymbol="❱" ;;
  "00AA") buttonsSymbol="»" ;;
  "2A20") buttonsSymbol="⨠" ;;
  "279C") buttonsSymbol="➜" ;;
  "279E") buttonsSymbol="➞" ;;
  "2794") buttonsSymbol="➔" ;;
  "27A0") buttonsSymbol="➠" ;;
  "27BE") buttonsSymbol="➾" ;;
  "1433") buttonsSymbol="ᐳ" ;;
esac

ToggleSymbol="$(jq -r '.ToggleSymbol' "$simplifyNextJson" 2>/dev/null)"
case "$ToggleSymbol" in
  asteriskBox) symbol0="[ ]"; symbol1="[*]" ;;
  hashBox) symbol0="[ ]"; symbol1="[#]" ;;
  plusBox) symbol0="[ ]"; symbol1="[+]" ;;
  Binary) symbol0="[0]" symbol1="[1]" ;;
  tickBox) symbol0="[ ]"; symbol1="[✓]" ;;
  checkBox) symbol0="☐"; symbol1="☑" ;;
  Regulus) symbol0=" "; symbol1="🜲" ;;
  Toggle) symbol0="〇━"; symbol1="━⚪" ;;
  radioButton) symbol0="〇"; symbol1="🔘" ;;
  Hexagon) symbol0=" "; symbol1="⬢" ;;
  Star) symbol0=" "; symbol1="★" ;;
  Sparkle) symbol0=" "; symbol1="✦" ;;
  Dymond) symbol0=" "; symbol1="⬧" ;;
  Flag) symbol0=" "; symbol1="⚑" ;;
esac

SecureSymbol="$(jq -r '.SecureSymbol' "$simplifyNextJson" 2>/dev/null)"
case "$SecureSymbol" in
  Asterisk) secureSymbol="*" ;;
  solidCircle) secureSymbol="●" ;;
  Hash) secureSymbol="#" ;;
  Multiplication) secureSymbol="×" ;;
  Star) secureSymbol="★" ;;
  Sparkle) secureSymbol="✦" ;;
  Dymond) secureSymbol="⬧" ;;
  Hexagon) secureSymbol="⬢" ;;
  Square) secureSymbol="■" ;;
  dollarSign) secureSymbol="$" ;;
esac