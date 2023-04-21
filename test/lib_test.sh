#!/bin/sh

# Global
: "${exit_status=0}"

execute_echo_from_file(){
  echo_from_pid=""

  if ! is_alpine; then
    cp -f "$(command which echo)" "$1"
    echo_from_pid=$("$1" -e arg1 arg2)
  else
    cat "$(command which coreutils)" > "$1"    # Fill it with a binary
    echo_from_pid=$("$1" --coreutils-prog=echo -e arg1 arg2)
  fi
  printf "%s" "$echo_from_pid"
}


get_fd_number(){
  : 'Return the first fd which contains a memfd'
  i_fd_number=2
  while [ "$i_fd_number" -le 100 ]; do
    exec 9>&2
    exec 2> /dev/null
    proc_fd=$(readlink -f /proc/"$1"/fd/"$i_fd_number")
    case $proc_fd in /memfd*) return "$i_fd_number";; esac
    exec 2>&9
    exec 9>&-
    : $(( i_fd_number += 1 ))
  done
  printf "%b" "\033[31mError: cannot find file descriptor\033[0m"
  exit 1
}


equal(){
  : 'Helper function
    Ex: equal 0 0 "yes it works"
  '
  out_equal=''
  if [ "$1" = "$2" ]; then
    out_equal="\033[32mSUCCESS: $3""\033[0m: (got '$1')"
  else
    exit_status=1
    out_equal="\033[31mERROR  : $3\033[0m: (expected '$1' and got '$2')"
  fi
  printf "%b\n" "$out_equal"
}


is_alpine(){
  : 'Alpine is so small, all commands are busybox'
  [ -f /etc/os-release ] || return 1
  [ alpine = "$(sed -n '/^ID=/s/ID=//p' /etc/os-release)" ] && return 0
  return 1
}
