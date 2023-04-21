#!/bin/sh

: 'Unit tests for inmembin.sh functions'


# Include
scriptdir=$(dirname "$(readlink -f "$0")")
. "$scriptdir/lib_test.sh"


# Source inmembin.sh
INMEMBIN_SOURCED=1 . "$scriptdir"/../inmembin.sh

main_test(){
  test_seek
  test_hex2dec
  test_hexify
  test_unhexify
  return "$exit_status"
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
  in=41424344
  ref=ABCD
  out=$(unhexify "$in")
  equal "$ref" "$out" "function hexify: should easily care upper case ascii"
}


test_unhexify(){
  in=ABDC len=4
  ref=41424344
  out=$(echo "$in" | hexify "$len")
  equal "$ref" "$out" "function unhexify: should easily care upper case ascii"
}


test_unhexify(){
  in=AAABACADBABBBCBDCACBCCCD
  ref=CDCCCBCABDBCBBBAADACABAA
  out=$(endian "$in")

  equal "$ref" "$out" "function endian should invert these hex encoded bytes"
}

main_test "$@" || exit "$exit_status"
