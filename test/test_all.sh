#!/usr/bin/env bash

scriptdir=$(dirname "$(readlink -f "$0")")

test_shell_mode(){
  "$1" "$scriptdir"/test_inmembin.sh --"$2"
}

colorize(){
  case $1 in
    0) printf "%b" "\e[32m$1\e[0m";;
    [0-9*]) printf "%b" "\e[31m$1\e[0m";;
    *) printf "%b" "\e[37m$1\e[0m";;
  esac
}

declare -a a_shell=(Shell ---) a_sync=(Sync ---) a_async=(Async ---)

for shell in bash zsh ash ksh sh; do
  a_shell+=("$shell")
  test_shell_mode "$shell" --sync; a_sync+=($?)
  test_shell_mode "$shell" --async; a_async+=($?)
done

for ((i=0; i < ${#a_shell[@]}; i++)); do
  c1=$(colorize "${a_shell[$i]}")
  c2=$(colorize "${a_sync[$i]}")
  c3=$(colorize "${a_async[$i]}")
  printf '| %-14s | %-13s | %-14s |\n' "$c1" "$c2" "$c3"
done
