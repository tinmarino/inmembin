#!/bin/sh

: 'Unit tests for inmembin.sh functions'

# Include
scriptdir=$(dirname "$(readlink -f "$0")"); . "$scriptdir/lib_test.sh"

# Set PS4
try_set_ps4

# Include
scriptdir=$(dirname "$(readlink -f "$0")")
. "$scriptdir/lib_test.sh"
: "${exit_status=0}"  # Silence shellcheck


# Source inmembin.sh
INMEMBIN_SOURCED=1 . "$scriptdir"/../inmembin.sh

main_test(){
  test_unknown_arch
  test_craft_arm_mov_imm
  #test_get_arch  # Not working with qemu
  test_seek
  test_hex2dec
  test_hexify
  test_unhexify
  return "$exit_status"
}


test_unknown_arch(){
  out=$(mktemp -t -p /tmp)
  err=$(mktemp -t -p /tmp)
  INMEMBIN_ARCH=grepme INMEMBIN_SOURCED=1 "$scriptdir"/../inmembin.sh > "$out" 2> "$err"
  ret=$?
  equal 0 $(( ! ret )) "script inmembin.sh must fail if cpu in env is unknown"
  equal "" "$(cat "$out")"  "script inmembin.sh must not print to stdout even if cpu in env is unknown"
  case $(cat "$err") in
    *grepme*) grepme=grepme;;
    *) grepme=did-not-grep-me;;
  esac
  equal "grepme" "$grepme" "script inmembin.sh must print to stderr if cpu in env is unknown"
}


test_craft_arm_mov_imm(){
  : '
    Note: starting with low bytes: important for test but the order should not matter
    movk     x0, #0xcdef, lsl #0
    movk     x0, #0x89ab, lsl #16
    movk     x0, #0x4567, lsl #32
    movk     x0, #0x0123, lsl #48
  '
  in=0123456789abcdef
  ref=e0bd99f26035b1f2e0acc8f26024e0f2
  out=$(craft_arm_mov_imm "$in")
  equal "$ref" "$out" "function craft_arm_mov_imm: should create the expected hex string for immediate in ($in)"
}


test_get_arch(){
  equal "$(uname -m)" "$(get_arch)" "function get_arch should return the current architecture, like uname -m, x86_64 or aarch64"
}


test_seek(){
  ref0=1234567890123456789
  tmpfile=$(mktemp -t -p /tmp)
  echo "$ref0" > "$tmpfile"

  # Before 0
  exec 3< "$tmpfile"
  pos=$(cat /proc/$$/fdinfo/3 | sed -n "/pos/s/ *pos:[[:space:]]*//p")
  equal 0 "$pos" "function seek: 0: pos should be 0 at start"
  out=$(cat "$tmpfile")
  equal "$ref0" "$out" "function seek: 0: tmpfile should contain what I hard wrote"

  # Seek 1: pos
  exec 3< "$tmpfile"
  seek 10 <&3
  pos=$(sed -n "/pos/s/ *pos:[[:space:]]*//p" /proc/$$/fdinfo/3)
  equal 10 "$pos" "function seek: 1: should change pos in /proc/$$/fdinfo/3"

  ## Commented <= Not In ksh
  ## Seek 2: pos in child
  #exec 3< "$tmpfile"
  #seek 10 <&3
  #pos=$(sed -n "/pos/s/ *pos:[[:space:]]*//p" /proc/self/fdinfo/3)
  #equal 10 "$pos" "function seek: 2: should change pos also for child in /proc/self/fdinfo/3"

  # Seek 3: write
  exec 3<> "$tmpfile"
  seek 10 <&3
  printf %s AAA >&3
  out=$(cat "$tmpfile")
  ref=1234567890AAA456789
  equal "$ref" "$out" "function seek: 3: subsequent write should respect offset"
}


test_hex2dec(){
  in=A ref=10 out=$(hex2dec "$in")
  equal "$ref" "$out" "function hex2dec: upper: 0x$in should eaqual $ref"

  in=a ref=10 out=$(hex2dec "$in")
  equal "$ref" "$out" "function hex2dec: lower: 0x$in should equal $ref"

  in=CACACACA ref=3402287818 out=$(hex2dec "$in")
  equal "$ref" "$out" "function hex2dec: dword: 0x$in should equal $ref"

  in=0ACACACACACACACA ref=777656858009324234 out=$(hex2dec "$in")
  equal "$ref" "$out" "function hex2dec: qword: 0x$in should equal $ref"

  # Not implemented
  # -- Currently reutrning bash: printf: warning: 0xcacacacacacacaca: Numerical result out of range
  # -- Anyway I will not go to the upper 64 bits addresses (reserved for kernel)
  in=CACACACACACACACA ref=14612714913291487946  # out=$(hex2dec "$in")
  equal 0 0 "function hex2dec: qword unsigned: Not implemented 0x$in should equal $ref"
}


test_hexify(){
  in=ABCD len=4
  ref=41424344
  out=$(echo "$in" | hexify "$len")
  equal "$ref" "$out" "function unhexify: should easily care upper case ascii"
}


test_unhexify(){
  in=41424344
  ref=ABCD
  out=$(unhexify "$in")
  equal "$ref" "$out" "function hexify: should easily care upper case ascii"
}


test_endian(){
  in=AAABACADBABBBCBDCACBCCCD
  ref=CDCCCBCABDBCBBBAADACABAA
  out=$(endian "$in")

  equal "$ref" "$out" "function endian should invert these hex encoded bytes"
}


main_test "$@" || exit "$exit_status"
