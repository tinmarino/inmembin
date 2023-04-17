#!/bin/sh
: 'Open next available FD with a memfd to execute elf in memory
Must be executed in a async job becasue I will sleep

Requires: dd uname cut
Supports: bash zsh ash ksh sh

Ex:
/proc/self/exe ./in_mem_bin.sh &
ls -l /proc/$!/fd
cp $(command which echo) /proc/$!/fd/4
/proc/$!/fd/4 -e "\e[34mmy message\e[0m"

From: https://github.com/arget13/DDexec/blob/main/ddsc.sh
'

arch=$(uname -m)  # x86_64 or aarch64

create_memfd(){
  : 'Main: no argument'
  local shellcode_hex shellcode_addr jumper_hex jumper_addr

  # Init shell
  config_if_zsh

  # Craft the shellcode and jumper hex
  shellcode_hex="$(craft_shellcode)"
  # -- The shellcode will be written into the vDSO
  shellcode_addr="0x$(get_section_map_start '[vdso]')"
  shellcode_addr=$(hex2dec "$shellcode_addr")
  jumper_hex="$(craft_jumper "$shellcode_addr")"
  read -r syscall_info < /proc/self/syscall
  jumper_addr=$(printf "%s" "$syscall_info" | cut -d' ' -f9)
  jumper_addr=$(hex2dec "$jumper_addr")
  
  # Overwrite vDSO with our shellcode
  echo Tin1
  ls -l /proc/$$/fd
  exec 3> /proc/self/mem
  seek "$shellcode_addr" <&3
  unhexify "$shellcode_hex" >&3
  exec 3>&-

  # Write jump instruction where it will be found shortly
  exec 3> /proc/self/mem
  echo Tin2
  ls -l /proc/$$/fd
  seek "$jumper_addr" <&3
  unhexify "$jumper_hex" >&3

  # Trigger jumper (this does not return)
  read -r syscall_info < /proc/self/syscall
  exec 3>&-
}


seek(){
  : 'Seek offset (arg1) on stdin => just to offset the FD
    -- silence error to avoid: error reading standard input: Bad file descriptor, which I do not care
    dd bs=1 skip="$1" > /dev/null 2>&1  # From coreutils
    tail -c +$(($1 + 1)) >/dev/null 2>&1  # From coreutils + Bad for ksh
    cmp -i "$1" /dev/null > /dev/null 2>&1  # From diffutils
    hexdump -s "$1" > /dev/null 2>&1  # From util-linux
    xxd -s "$1" > /dev/null 2>&1  # From vim
  '
  dd bs=1 skip="$1" > /dev/null 2>&1  # From coreutils
}


endian(){
  : 'Change endianness of hex string (arg1)'
  local i=${#1} out=''
  while [ "$i" -ge 0 ]; do
    out="$out$(printf "%s" "$1" | cut -c$(( i+1 ))-$(( i+2 )))"
    i=$((i-2))
  done
  printf "%s" "$out"
}


unhexify(){
  : 'Convert hex string (arg1) to binary stream to stdout
    Dev: in POSIX sh, no printf "\x41" is allowed, so go octal
  '
  local escaped='' i=0 num=0
  while [ "$i" -lt "${#1}" ]; do
    num=$((0x$(printf "%s" "$1" | cut -c$(( i+1 ))-$(( i+2 )))))
    escaped="$escaped\\$(printf "%o" "$num")"
    i=$(( i+2 ))
  done
    
  # shellcheck disable=SC2059  # Don't use variables in the p...t string
  printf "$escaped"
}


hex2dec(){
  : 'ksh do not support 64 bit arithmetic (as 2023 fo mksh)'
  #printf "$(( $1 ))"
  printf "%d" "$1"
}


get_section_map_start(){
  : 'Print offset of start of section with string (arg1)'
  while read -r line; do
    case $line in *"$1"*)
      printf "%s" "$line" | cut -d- -f1
    esac
  done < /proc/$$/maps
}


craft_shellcode(){
  : 'Craft hex shellcode with: dup2(2, 0); memfd_create;'
  local out=''
  case $arch in
    x86_64)
      out=4831c04889c6b0024889c7b0210f05  # dup
      out="${out}68444541444889e74831f64889f0b401b03f0f054889c7b04d0f05b0220f05"  # memfd
      ;;
    aarch64)
      out=080380d2400080d2010080d2010000d4
      out="${out}802888d2a088a8f2e00f1ff8e0030091210001cae82280d2010000d4c80580d2010000d4881580d2010000d4610280d2281080d2010000d4"
      ;;
    *)
      echo "DDexec: Error, this architecture is not supported." >&2
      exit 1
  esac
  printf "%s" "$out"
}


craft_jumper(){
  : 'Craft hex code to jump to (arg1) hex address
  -- Trampoline to jump to the shellcode
  '
  local out="$(printf %016x "$1")"
  case $arch in
    x86_64) out="48b8$(endian "$out")ffe0";;
    aarch64) out="4000005800001fd6$(endian "$out")";;
  esac
  printf "%s" "$out"
}


config_if_zsh(){
  : 'Make zsh behave somewhat like bash'
  [ -z "$ZSH_VERSION" ] && return
  setopt SH_WORD_SPLIT
  setopt KSH_ARRAYS
}


# Run if executed (not sourced), warning filename harcode
case ${0##*/} in
  sh|bash|zsh|dash|ash|ksh) :;;
  *) create_memfd;;
esac
