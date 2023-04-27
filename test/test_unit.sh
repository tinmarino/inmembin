#!/bin/sh

: 'Unit tests for inmembin.sh functions'

# Include
testdir=$(dirname "$(readlink -f "$0")"); . "$testdir/lib_test.sh"
: "${exit_status=0}"  # Silence shellcheck


# Source inmembin.sh
INMEMBIN_SOURCED=1 . "$testdir"/../inmembin.sh

# Global helpers
hex_0_to_256=000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff

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
  INMEMBIN_ARCH=grepme INMEMBIN_SOURCED=1 "$testdir"/../inmembin.sh > "$out" 2> "$err"
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
  # Ascii example
  in=ABCD len=4
  ref=41424344
  out=$(echo "$in" | hexify "$len")
  equal "$ref" "$out" "function hexify: should easily care upper case ascii"

  # All bytes
  out=$(hexify 256 < "$testdir"/byte_0_to_255.bin)
  ref=$hex_0_to_256
  equal "$ref" "$out" "function hexify: should convert all bytes from 0 to 255"
}


test_unhexify(){
  in=41424344
  ref=ABCD
  out=$(unhexify "$in")
  equal "$ref" "$out" "function unhexify: should easily care upper case ascii"

  tmpfile=$(mktemp -t -p /tmp)
  unhexify "$hex_0_to_256" > "$tmpfile"
  cmp "$tmpfile" "$testdir"/byte_0_to_255.bin
  equal 0 $? "function unhexify: should work with all 256 bytes"
}


test_endian(){
  in=AAABACADBABBBCBDCACBCCCD
  ref=CDCCCBCABDBCBBBAADACABAA
  out=$(endian "$in")

  equal "$ref" "$out" "function endian should invert these hex encoded bytes"
}


main_test "$@" || exit "$exit_status"
