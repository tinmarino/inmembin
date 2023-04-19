#!/bin/sh
: 'Open next available FD with a memfd
-- Used to execute binary in memory (without touching HD)

Ex: bash ./inmembin.sh & sleep 0.3; cp $(command which echo) /proc/$!/fd/4; /proc/$!/fd/4 toto
'

# Global architecture
ARCH=$(uname -m)  # x86_64 or aarch64
: "{DEBUG:=1}"

# Clause: leave if CPU not supported
case $ARCH in x86_64|aarch64):;; *)
  echo "DDexec: Error, this architecture is not supported." >&2
  exit 1;;
esac

create_memfd(){
  : 'Main function: no argument, no return!'
  # Craft the shellcode to be written into the vDSO
  shellcode_hex="$(craft_shellcode)"
  shellcode_addr="$(get_section_start_addr '[vdso]')"

  # Craft the jumper to be written to a syscall ret PC
  jumper_hex="$(craft_jumper "$shellcode_addr")"
  jumper_addr="$(get_read_syscall_ret_addr)"
  
  [ "$DEBUG" != 0 ] && >&2 printf "%s" "InMemBin: shellcode_addr=$shellcode_addr,jumper_addr=$jumper_addr"

  # Backup
  [ "$DEBUG" != 0 ] && >&2 echo Read1
  shellcode_save_hex=$(read_mem "$shellcode_addr" $(( ${#shellcode_hex} / 2 )))
  [ "$DEBUG" != 0 ] && >&2 echo Read2
  jumper_save_hex=$(read_mem "$jumper_addr" $(( ${#jumper_hex} / 2 )))

  # Overwrite vDSO with our shellcode
  [ "$DEBUG" != 0 ] && >&2 echo Write1
  write_mem "$shellcode_addr" "$shellcode_hex"

  # Write jump instruction where it will be found shortly
  [ "$DEBUG" != 0 ] && >&2 echo Write2
  write_mem "$jumper_addr" "$jumper_hex"

  [ "$DEBUG" != 0 ] && >&2 echo Write3
  write_mem "$shellcode_addr" "$shellcode_save_hex"
  write_mem "$jumper_addr" "$jumper_save_hex"

  [ "$DEBUG" != 0 ] && >&2 echo "InMemBin: Function is back"
}


read_mem(){
  : 'Read mem at pos (arg1) with size (arg2)
    TODO: Implementing... bash only
  '
  exec 3< /proc/self/mem
  xxd -s "$1" -l "$2"  -c 1000000 -p <&3
  exec 3<&-
}


write_mem(){
  exec 3> /proc/self/mem
  seek "$1" <&3
  unhexify "$2" >&3
  exec 3>&-
}


craft_shellcode(){
  : 'Craft hex shellcode with: dup2(2, 0); memfd_create;'
  out=''
  case $ARCH in
    x86_64)
      out=4831c04889c6b0024889c7b0210f05  # dup
      ## ORIGIN
      #out="${out}68444541444889e74831f64889f0b401b03f0f054889c7b04d0f05b0220f05";;  # memfd

      ## Debug with jump
      out="${out}68444541444889e74831f64889f0b401b03f0f054889c7b04d"
      out="${out}5831c0"  # pop eax, xor eax, eax
      # memprotect + mov + jump back
      out="${out}b80a00000048bf0040d1f7ff7f0000ba07000000be0c0000000f0549bf9249d1f7ff7f000041c707483d00f041c74704ffff775641c74708c30f1f4441ffe7"
      ;;
    aarch64)
      out=080380d2400080d2010080d2010000d4
      out="${out}802888d2a088a8f2e00f1ff8e0030091210001cae82280d2010000d4c80580d2010000d4881580d2010000d4610280d2281080d2010000d4";;
  esac
  printf "%s" "$out"
}


craft_jumper(){
  : 'Craft hex code to jump to (arg1) hex address
  -- Trampoline to jump to the shellcode
  '
  out="$(printf %016x "$1")"
  case $ARCH in
    x86_64) out="48b8$(endian "$out")ffe0";;
    aarch64) out="4000005800001fd6$(endian "$out")";;
  esac
  printf "%s" "$out"
}


get_section_start_addr(){
  : 'Print offset of start of section with string (arg1)'
  out=""
  while read -r line; do case $line in *"$1"*)
    out=$(printf "%s" "$line" | cut -d- -f1); break
  esac; done < /proc/$$/maps
  hex2dec "0x$out"
}


get_read_syscall_ret_addr(){
  : 'Print decimal addr where a next syscall will return, to put jumper, as trigger'
  read -r syscall_info < /proc/self/syscall
  out="$(printf "%s" "$syscall_info" | cut -d' ' -f9)"
  hex2dec "$out"
}


endian(){
  : 'Change endianness of hex string (arg1)'
  i=0 out=''
  while [ "$i" -lt "${#1}" ]; do
    out="$(printf "%s" "$1" | cut -c$(( i+1 ))-$(( i+2 )))$out"
    i=$((i+2))
  done
  printf "%s" "$out"
}


unhexify(){
  : 'Convert hex string (arg1) to binary stream (stdout)'
  escaped='' i=0 num=0
  while [ "$i" -lt "${#1}" ]; do
    num=$(( 0x$(printf "%s" "$1" | cut -c$(( i+1 ))-$(( i+2 ))) ))
    escaped="$escaped\\$(printf "%o" "$num")"
    i=$(( i+2 ))
  done
  # shellcheck disable=SC2059  # Don't use variables in the p...t string
  printf "$escaped"
}


hex2dec(){
  : 'Convert hex number to decimal number'
  printf "%d" "$1"
}


seek(){
  : 'Seek offset (arg1) on stdin => just to offset the FD'
  dd bs=1 skip="$1" > /dev/null 2>&1
}


# Run if executed (not sourced), warning filename hardcode
case ${0##*/} in
  bash|zsh|dash|ash|ksh|mksh|sh) :;;
  *) create_memfd;;
esac
[ "$DEBUG" != 0 ] && >&2 echo "InMemBin: Over"
