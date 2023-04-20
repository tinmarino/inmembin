#!/bin/sh
: 'Open next available FD with a memfd
-- Used to execute binary in memory (without touching HD)

Ex: bash ./inmembin.sh & sleep 0.3; cp $(command which echo) /proc/$!/fd/4; /proc/$!/fd/4 toto
'

# Global architecture
ARCH=$(uname -m)  # x86_64 or aarch64
SOURCED=0
: "{DEBUG:=1}"

# Clause: leave if CPU not supported
case $ARCH in x86_64|aarch64):;; *)
  echo "DDexec: Error, this architecture is not supported." >&2
  exit 1;;
esac

create_memfd(){
  : 'Main function: no argument, no return!'
  # Craft the shellcode to be written into the vDSO
  shellcode_addr_hex="$(get_section_start_addr '[vdso]')"
  shellcode_addr_dec="$(hex2dec "0x$shellcode_addr_hex")"

  # Craft the jumper to be written to a syscall ret PC
  jumper_addr_hex="$(get_read_syscall_ret_addr)"
  while [ ${#jumper_addr_hex} -lt 16 ]; do
    jumper_addr_hex="0$jumper_addr_hex"
  done
  jumper_addr_hex_endian="$(endian "$jumper_addr_hex")"
  jumper_addr_hex_endian_page="0000${jumper_addr_hex_endian#????}"  # Protect 16 pages !
  jumper_addr_dec="$(hex2dec "0x$jumper_addr_hex")"
  
  # Craft shellcode and jumper
  shellcode_hex="$(craft_shellcode)"
  jumper_hex="$(craft_jumper "$shellcode_addr_dec")"

  # Backup
  [ "$DEBUG" != 0 ] && >&2 echo Read1
  shellcode_save_hex=$(read_mem "$shellcode_addr_dec" $(( ${#shellcode_hex} / 2 )))
  #[ "$DEBUG" != 0 ] && >&2 echo Read2
  #jumper_save_hex=$(read_mem "$jumper_addr" $(( ${#jumper_hex} / 2 )))

  [ "$DEBUG" != 0 ] && >&2 echo "InMemBin:
    shellcode_addr_hex=$shellcode_addr_hex
    shellcode_hex=$shellcode_hex
    shellcode_save_hex=$shellcode_save_hex

    jumper_addr____________=$jumper_addr_hex
    jumper_addr_endian_____=$jumper_addr_hex_endian
    jumper_addr_endian_page=$jumper_addr_hex_endian_page
    jumper_hex=$jumper_hex
    jumper_save_hex=$jumper_hex
  "

  # Overwrite vDSO with our shellcode
  [ "$DEBUG" != 0 ] && >&2 echo Write1
  write_mem "$shellcode_addr_dec" "$shellcode_hex"

  # Write jump instruction where it will be found shortly
  [ "$DEBUG" != 0 ] && >&2 echo Write2
  write_mem "$jumper_addr_dec" "$jumper_hex"

  [ "$DEBUG" != 0 ] && >&2 echo Write3
  if [ "$SOURCED" = 0 ] && [ bash != "$SHELL" ]; then
    # I do not know why bash freeze on this line
    write_mem "$shellcode_addr_dec" "$shellcode_save_hex"
  fi

  # Done by shellcode
  [ "$DEBUG" != 0 ] && >&2 echo Write4
  #write_mem "$jumper_addr" "$jumper_save_hex"

  [ "$DEBUG" != 0 ] && >&2 echo "InMemBin: Function is back"
  ls -l /proc/$$/fd
}


read_mem(){
  : 'Read mem at pos (arg1) with size (arg2)
    TODO: Implementing... bash only
  '
  exec 3< /proc/self/mem
  xxd -s "$1" -l "$2"  -c 100000 -p <&3
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
      #out="${out}b80a00000048bf0040d1f7ff7f0000ba07000000be0c0000000f0549bf9249d1f7ff7f000041c707483d00f041c74704ffff775641c74708c30f1f4441ffe7"
      #out="${out}b80a00000048bfcacacacacacacacaba07000000be0c0000000f0549bfcbcbcbcbcbcbcbcb41c707483d00f041c74704ffff775641c74708c30f1f4441ffe7"
      out="${out}b80a00000048bf${jumper_addr_hex_endian_page}ba07000000be000001000f0549bf${jumper_addr_hex_endian}41c707483d00f041c74704ffff775641c74708c30f1f4441ffe7"
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
  while read -r line; do
    case $line in *"$1"*) out=$(printf "%s" "$line" | cut -d- -f1); break; esac
  done < /proc/$$/maps
  printf "%s" "$out"
}


get_read_syscall_ret_addr(){
  : 'Print decimal addr where a next syscall will return, to put jumper, as trigger'
  read -r syscall_info < /proc/self/syscall
  out="$(printf "%s" "$syscall_info" | cut -d' ' -f9)"
  printf "%s" "${out##??}"  # Remove the 0x prefix
}


endian(){
  : 'Change endianness of hex string (arg1)'
  out='' rest="$1"
  while [ -n "$rest" ]; do
    tail="${rest#??}"
    out="${rest%"$tail"}$out"
    rest="$tail"
  done
  printf "%s" "$out"
}


unhexify(){
  : 'Convert hex string (arg1) to binary stream (stdout): see README'
  escaped='' rest="$1"
  while [ -n "$rest" ]; do
    tail="${rest#??}"
    escaped="$escaped\\$(printf "%o" 0x"${rest%"$tail"}")"
    rest="$tail"
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


# Is script sourced?  # From: https://stackoverflow.com/a/28776166/2544873
if [ -n "$ZSH_VERSION" ]; then
  case $ZSH_EVAL_CONTEXT in *:file) SOURCED=1;; esac
elif [ -n "$KSH_VERSION" ]; then
  # shellcheck disable=SC2296  # Parameter expansions can't start with ..
  [ "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ] && SOURCED=1
elif [ -n "$BASH_VERSION" ]; then
  (return 0 2>/dev/null) && SOURCED=1
else # All other shells: examine $0 for known shell binary filenames.
  # Detects `sh` and `dash`; add additional shell filenames as needed.
  case ${0##*/} in sh|-sh|dash|-dash) SOURCED=1;; esac
fi

[ "$SOURCED" = 0 ] && create_memfd
