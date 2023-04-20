#!/usr/bin/env bash

scriptdir=$(dirname "$(readlink -f "$0")")

test_shell_mode(){
  "$1" "$scriptdir"/test_inmembin.sh --"$2"
}

for shell in bash zsh ash ksh; do
  for mode in sync async; do
    test_shell_mode "$shell" "$mode"
  done
done
