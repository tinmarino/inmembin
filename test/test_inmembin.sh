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

# Include
scriptdir=$(dirname "$(readlink -f "$0")")
. "$scriptdir/lib_test.sh"


# Global
: "${INMEMBIN_DEBUG:=1}"
exit_status=0
cmd=$(head -n1 /proc/$$/cmdline | cut -d "" -f1)  # Get shell, not sure why alpine is adding a newline between arguments
cmd=${cmd##*/}

# Clause: check shell: call me with a known shell
r_known_shell="bash|zsh|ash|dash|ksh|mksh|sh|ksh93"
case $cmd in
  bash|zsh|ash|dash|ksh|mksh|sh|ksh93) :;;
  *) printf "%b\n" "\033[31mError: call me with a command in $r_known_shell (got $cmd: $(echo "$cmd"|xxd))\nTip: ash test_inmembin.sh\033[0m"; exit 1;;
esac


main_test(){
  case "$*" in *--unit*) test_unit;; esac
  case "$*" in *--async*) test_async;; esac
  case "$*" in *--sync*) test_sync;; esac
  return "$exit_status"
}


test_unit(){
  printf "%bTesting %4s %5s:%b " "\033[34m" "$cmd" unit "\033[0m"
  "$cmd" "$scriptdir/test_unit.sh";
  : $(( exit_status |= $? ))
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


main_test "$@" || exit "$exit_status"
