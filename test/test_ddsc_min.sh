#!/usr/bin/env bash
: '
TODO:
tcsh

Notes:
1/ Ksh do not support 64 bit unsigned arithmetic so those fail
tail -c +$(($1 + 1)) >/dev/null 2>&1
jumper_addr=$(($(echo "$syscall_info" | cut -d' ' -f9)))
'

# Global
exit_status=0
scriptdir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

equal(){
    : 'Helper function
      Ex: equal 0 0 "yes it works"
    '
    local msg=''
    if [ "$1" = "$2" ]; then
      msg="\e[32mSUCCESS: $3\e[0m: (got '$1')"
    else
      exit_status=1
      msg="\e[31mERROR  : $3\e[0m: (expected '$1' and got '$2')"
    fi
    echo -e "$msg"
}

for test_shell in bash zsh ash ksh sh; do
  "$test_shell" "$scriptdir"/../in_mem_bin.sh &
  pid=$!
  sleep 0.3
  #ls -l /proc/$pid/fd/
  cp "$(command which echo)" /proc/$pid/fd/3
  out=$(/proc/$pid/fd/3 -e "arg1"  "arg2")
  equal "arg1 arg2" "$out" "ddsc_min.sh should work with $test_shell"
done

exit "$exit_status"
