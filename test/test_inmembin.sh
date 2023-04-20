#!/usr/bin/env bash
# shellcheck disable=SC3037  # In POSIX sh, echo flags are undefined
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
scriptdir=$(dirname "$(readlink -f "$0")")
cmd=$(head -n1 /proc/$$/cmdline | cut -d "" -f1)  # Get shell, not sure why alpine is adding a newline between arguments
cmd=${cmd##*/}

# Clause: check shell: call me with a known shell
r_known_shell="bash|zsh|ash|dash|ksh|mksh|sh"
case $cmd in
  bash|zsh|ash|dash|ksh|mksh|sh) :;;
  *) echo -e "\e[31mError: call me with a command in $r_known_shell (got $cmd: $(echo "$cmd"|xxd))\nTip: ash test_inmembin.sh\e[0m"; exit 1;;
esac

main_test(){
  test_sync
}

test_async(){
  "$cmd" "$scriptdir"/../inmembin.sh &
  pid=$!
  sleep 2
  
  if ! is_alpine; then
    cp -f "$(command which echo)" /proc/"$pid"/fd/4
    out=$(/proc/"$pid"/fd/4 -e arg1 arg2)
  else
    cat "$(command which coreutils)" > /proc/"$pid"/fd/4    # Fill it with a binary
    out=$(/proc/"$pid"/fd/4 --coreutils-prog=echo -e arg1 arg2)
  fi
  
  equal "arg1 arg2" "$out" "ddsc_min.sh should work with $cmd"
}

test_sync(){
  : 'Implemented, TODO remove setarch'
  source "$scriptdir"/../inmembin.sh
  create_memfd
  pid=$$
  
  if ! is_alpine; then
    cp -f "$(command which echo)" /proc/"$pid"/fd/4
    out=$(/proc/"$pid"/fd/4 -e arg1 arg2)
  else
    cat "$(command which coreutils)" > /proc/"$pid"/fd/4    # Fill it with a binary
    out=$(/proc/"$pid"/fd/4 --coreutils-prog=echo -e arg1 arg2)
  fi
  
  equal "arg1 arg2" "$out" "ddsc_min.sh should work with $cmd"
}

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

is_alpine(){
  : 'Alpine is so small, all commands are busybox'
  [ -f /etc/os-release ] || return 1
  [ alpine = "$(sed -n '/^ID=/s/ID=//p' /etc/os-release)" ] && return 0
  return 1
}

main_test
exit "$exit_status"
