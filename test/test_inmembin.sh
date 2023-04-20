#!/bin/sh
# shellcheck disable=SC2059  # Don't use variables in the p...t string
# shellcheck disable=SC3037,SC1091  # In POSIX sh, echo flags are undefined | not following

: '
TODO:
tcsh

Notes:
1/ Ksh do not support 64 bit unsigned arithmetic so those fail
tail -c +$(($1 + 1)) >/dev/null 2>&1
jumper_addr=$(($(echo "$syscall_info" | cut -d' ' -f9)))
'

: "${INMEMBIN_DEBUG:=1}"

# Global
exit_status=0
scriptdir=$(dirname "$(readlink -f "$0")")
cmd=$(head -n1 /proc/$$/cmdline | cut -d "" -f1)  # Get shell, not sure why alpine is adding a newline between arguments
cmd=${cmd##*/}

# Clause: check shell: call me with a known shell
r_known_shell="bash|zsh|ash|dash|ksh|mksh|sh|ksh93"
case $cmd in
  bash|zsh|ash|dash|ksh|mksh|sh|ksh93) :;;
  *) printf "%b\n" "\033[31mError: call me with a command in $r_known_shell (got $cmd: $(echo "$cmd"|xxd))\nTip: ash test_inmembin.sh\033[0m"; exit 1;;
esac


main_test(){
  case "$*" in *--async*) test_async;; esac
  case "$*" in *--sync*) test_sync;; esac
  return "$exit_status"
}


test_async(){
  printf "%bTesting %4s %5s:%b " "\033[34m" "$cmd" async "\033[0m"
  "$cmd" "$scriptdir"/../inmembin.sh &
  pid=$!
  sleep 2

  get_fd_number "$pid"; fd=$?
  out=$(execute_echo_from_file "/proc/$pid/fd/$fd")

  equal "arg1 arg2" "$out" "shell=$cmd,mode=async: executing script should create the fd (fd=$fd,pid=$pid)"
}


test_sync(){
  : 'Implementing, TODO remove setarch'
  printf "%bTesting %4s %5s:%b " "\033[34m" "$cmd" sync "\033[0m"
  out=''

  [ "$INMEMBIN_DEBUG" != 0 ] && echo "Test: Source"
  INMEMBIN_SOURCED=1 . "$scriptdir"/../inmembin.sh
  [ "$INMEMBIN_DEBUG" != 0 ] && echo "Test: Execute"
  create_memfd
  pid=$$

  get_fd_number "$pid"; fd=$?
  out=$(execute_echo_from_file "/proc/$pid/fd/$fd")

  equal "arg1 arg2" "$out" "shell=$cmd,mode=sync: executing function should fill current shell (fd=$fd,pid=$pid)"
}


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
  for fd_number in 5 4 3; do
    exec 9>&2
    exec 2> /dev/null
    proc_fd=$(readlink -f /proc/"$1"/fd/"$fd_number")
    case $proc_fd in /memfd*) return "$fd_number";; esac
    exec 2>&9
    exec 9>&-
  done
  printf "%b" "\033[31mError: cannot find file descriptor\033[0m"
  exit 1
}


equal(){
  : 'Helper function
    Ex: equal 0 0 "yes it works"
  '
  msg=''
  if [ "$1" = "$2" ]; then
    msg="\033[32mSUCCESS: $3""\033[0m: (got '$1')"
  else
    exit_status=1
    msg="\033[31mERROR  : $3\033[0m: (expected '$1' and got '$2')"
  fi
  printf "%b\n" "$msg"
}


is_alpine(){
  : 'Alpine is so small, all commands are busybox'
  [ -f /etc/os-release ] || return 1
  [ alpine = "$(sed -n '/^ID=/s/ID=//p' /etc/os-release)" ] && return 0
  return 1
}

main_test "$@" || exit "$exit_status"
