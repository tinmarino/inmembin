#!/bin/sh

: 'Open next available FD with a memfd
-- Used to execute binary in memory (without touching HD)
--
-- Ex: bash ./inmembin.sh & sleep 0.3; cp $(command which echo) /proc/$!/fd/4; /proc/$!/fd/4 toto
'

get_arch(){
  : 'Print Cpu architecture: x86_64 or aarch64.
    -- read -r INMEMBIN_ARCH < /proc/sys/kernel/arch  # Not working before 2022
  '
  while IFS=: read -r cpuinfo_key cpuinfo_value; do
    case $cpuinfo_key in flags*|Features*)
        case $cpuinfo_value in
          *" lm "*|*lm$) printf %s x86_64;;
          *" lpae "*|*lpae$|*" fp "*|*fp$) printf %s aarch64;;
          *) printf %s unknown;;
        esac
    break;; esac
  done < /proc/cpuinfo
}

# Global architecture
: "${INMEMBIN_ARCH:=$(get_arch)}"  # x86_64 or aarch64
: "${INMEMBIN_SOURCED:=0}"  # Is the file sourced, or executed?
: "${INMEMBIN_DEBUG:=0}"  # Add debug symbols?

# Clause: leave if CPU not supported
case $INMEMBIN_ARCH in x86_64|aarch64):;; *)
  echo "DDexec: Error, this architecture is not supported ($INMEMBIN_ARCH)" >&2
  exit 1;;
esac

create_memfd(){
  : 'Main function: no argument, no return!'
  # Craft the shellcode to be written into the vDSO
  shellcode_addr_hex=$(get_section_start_addr '[vdso]')
  shellcode_addr_dec=$(hex2dec "$shellcode_addr_hex")

  # Craft the jumper to be written to a syscall ret PC
  jumper_addr_hex=$(get_read_syscall_ret_addr)
  while [ ${#jumper_addr_hex} -lt 16 ]; do
    jumper_addr_hex="0$jumper_addr_hex"
  done
  jumper_addr_hex_endian=$(endian "$jumper_addr_hex")
  jumper_addr_hex_endian_page="0000${jumper_addr_hex_endian#????}"  # Protect 16 pages !
  jumper_addr_hex_page=$(endian "$jumper_addr_hex_endian_page")
  jumper_addr_dec="$(hex2dec "$jumper_addr_hex")"
  
  # Craft jumper
  jumper_hex="$(craft_jumper "$shellcode_addr_dec")"

  # Backup jumper
  jumper_save_hex=$(read_mem "$jumper_addr_dec" $(( ${#jumper_hex} / 2 )))

  # Craft shellcode
  shellcode_hex="$(craft_shellcode "$jumper_addr_dec" "$jumper_save_hex")"

  # Backup shellcode
  shellcode_save_hex=$(read_mem "$shellcode_addr_dec" $(( ${#shellcode_hex} / 2 )))
  # Expects: 483d00f0ffff7756c30f1f44

  [ "$INMEMBIN_DEBUG" != 0 ] && >&2 echo "InMemBin:
    --pid=$$

    --shellcode_addr_hex=$shellcode_addr_hex
    --shellcode_hex=$shellcode_hex
    --shellcode_save_hex=$shellcode_save_hex

    --jumper_addr____________=$jumper_addr_hex
    --jumper_addr_endian_____=$jumper_addr_hex_endian
    --jumper_addr_endian_page=$jumper_addr_hex_endian_page
    --jumper_hex=$jumper_hex
    --jumper_save_hex=$jumper_save_hex
  "

  # Overwrite vDSO with our shellcode
  [ "$INMEMBIN_DEBUG" != 0 ] && >&2 echo "InMemBin: Write shellcode"
  write_mem "$shellcode_addr_dec" "$shellcode_hex"

  # Write jump instruction where it will be found shortly
  [ "$INMEMBIN_DEBUG" != 0 ] && >&2 echo "InMemBin: Write jumper"
  write_mem "$jumper_addr_dec" "$jumper_hex"
  # -- Wait: Fd still not created at this point

  # Trigger
  [ "$INMEMBIN_DEBUG" != 0 ] && >&2 echo "InMemBin: Trigger"
  if [ -n "$KSH_VERSION" ]; then
    read -r _syscall_info < /proc/self/syscall
  fi

  if [ -z "$KSH_VERSION" ]; then
    # This destroys the FD with ksh93
    write_mem "$shellcode_addr_dec" "$shellcode_save_hex"
  fi

  [ "$INMEMBIN_DEBUG" != 0 ] && >&2 echo "InMemBin: Function is back"
}


read_mem(){
  : 'Read mem at pos (arg1) with size (arg2)
    -- TODO: Implementing... bash only
  '
  exec 6< /proc/self/mem
  dd bs=1 skip="$1" count="$2" <&6 2> /dev/null | hexify "$2" 2> /dev/null
  exec 6<&-
}


write_mem(){
  : 'Write memory at pos (arg1) content (arg2)'
  exec 6> /proc/self/mem
  seek "$1" <&6
  unhexify "$2" >&6
  exec 6>&-
}


seek(){
  : 'Seek offset (arg1) on stdin => just to offset the FD'
  dd bs=1 skip="$1" count=0 > /dev/null 2>&1
}


craft_shellcode(){
  : 'Craft hex shellcode with: dup2(2, 0); memfd_create;'
  out_sc=''
  case $INMEMBIN_ARCH in
    x86_64)
      # Divide in 3 dw
      save_rest="$jumper_save_hex"
      tail="${save_rest#????????}"; save_dw1="${save_rest%"$tail"}"; save_rest=$tail
      tail="${save_rest#????????}"; save_dw2="${save_rest%"$tail"}"; save_rest=$tail
      tail="${save_rest#????????}"; save_dw3="${save_rest%"$tail"}"; save_rest=$tail

      out_sc=''
      # Debug
      #out_sc="${out_sc}cd03"

      # Pre
      # -- Dup fd
      out_sc="${out_sc}4831c04889c6b0024889c7b0210f05"
      # -- mov 15, jumper addr
      out_sc="${out_sc}49bf${jumper_addr_hex_endian}"
      # -- memprotect RW
      out_sc="${out_sc}b80a00000048bf${jumper_addr_hex_endian_page}ba03000000be000001000f05"
      # -- write jumper saved
      out_sc="${out_sc}41c707${save_dw1}41c74704${save_dw2}41c74708${save_dw3}"
      # -- memprotect RX
      out_sc="${out_sc}b80a00000048bf${jumper_addr_hex_endian_page}ba05000000be000001000f05"

      # In
      # -- syscall memfd 0x164
      out_sc="${out_sc}68444541444889e74831f64889f0b401b03f0f054889c7b04d"
      # -- pop eax, xor eax, eax <= did a push for the syscall
      out_sc="${out_sc}5831c0"

      # Post
      # -- mov 15, jumper addr
      out_sc="${out_sc}49bf${jumper_addr_hex_endian}"
      # -- jump r15
      out_sc="${out_sc}41ffe7"
      ;;
    aarch64)
      out_sc="${out_sc}080380d2400080d2010080d2010000d4"

      # Break
      out_sc="${out_sc}fedeffe7"

      # syscall memfd
      out_sc="${out_sc}802888d2a088a8f2e00f1ff8e0030091210001cae82280d2010000d4"

      # mov x15, jumper addr, osea mov x15, x0 = ef0300aa
      out_sc="${out_sc}$( craft_arm_mov_imm "$jumper_addr_hex" )ef0300aa"
      # memprotect RW => 3, note: mov x0, x15 = e0030faa
      out_sc="${out_sc}2100a0d2620080d2$( craft_arm_mov_imm "$jumper_addr_hex_page" )481c80d2010000d4"
      # write jumper saved
      # -- Fortunately is size is 31 bits = 2 x 16
      jmp_rest=$jumper_save_hex
      while [ -n "$jmp_rest" ]; do
         jmp_tail="${jmp_rest#????????????????}"; jmp_cur=${jmp_rest%"$jmp_tail"}; jmp_rest="$jmp_tail"
         out_sc="${out_sc}$( craft_arm_mov_imm "$(endian "$jmp_cur")" )"
         out_sc="${out_sc}e00100f9"  # str x0, [x15]
         out_sc="${out_sc}ef410091"  # add, x15, x15, #16
      done

      #out_sc="${out_sc}41c707${save_dw1}41c74704${save_dw2}41c74708${save_dw3}"
      # memprotect RX => 5
      out_sc="${out_sc}2100a0d2a20080d2$( craft_arm_mov_imm "$jumper_addr_hex_page" )481c80d2010000d4"
      # mov x15, jumper addr, osea mov x15, x0 = ef0300aa
      out_sc="${out_sc}$( craft_arm_mov_imm "$jumper_addr_hex" )ef0300aa"
      # jump: br x15
      out_sc="${out_sc}e0011fd6"
      # Ftruncate and pause
      #out_sc="${out_sc}c80580d2010000d4881580d2010000d4610280d2281080d2010000d4"
      ;;
  esac
  printf "%s" "$out_sc"
}


craft_jumper(){
  : 'Craft hex code to jump to (arg1) hex address
    -- Trampoline to jump to the shellcode
  '
  out_jp="$(printf %016x "$1")"
  case $INMEMBIN_ARCH in
    x86_64) out_jp="48b8$(endian "$out_jp")ffe0";;
    aarch64) out_jp="4000005800001fd6$(endian "$out_jp")";;
  esac
  printf "%s" "$out_jp"
}


craft_arm_mov_imm(){
  : 'Craft hex code for arm mov 64 bit immediate
    -- ins1=$((  (0x"$w1" << 5) + (1 << 31) + (1 << 30) + (1 << 28) + (1 << 25) + (1 << 23) + (0 << 22) + (0 << 4) ))
  '
  imm_rest=$(printf %016x 0x"$1")

  # Split in words
  imm_tail=${imm_rest#????}; w1=${imm_rest%"$imm_tail"}; imm_rest=$imm_tail
  imm_tail=${imm_rest#????}; w2=${imm_rest%"$imm_tail"}; imm_rest=$imm_tail
  imm_tail=${imm_rest#????}; w3=${imm_rest%"$imm_tail"}; imm_rest=$imm_tail
  imm_tail=${imm_rest#????}; w4=${imm_rest%"$imm_tail"}; imm_rest=$imm_tail

  imm_shift=0
  for imm_word in "$w4" "$w3" "$w2" "$w1"; do
    inst=$(printf %08x $(( 0xf2800000 + (0x$imm_word << 5) + (imm_shift << 21) )))
    # Ksh may prefix with 8 f as its arith expansion returns signed
    [ "${#inst}" -gt 8 ] && inst=${inst#????????}
    endian "$inst"
    : $(( imm_shift += 1 ))
  done
}


get_section_start_addr(){
  : 'Print offset of start of section with string (arg1)'
  while IFS=- read -r section_addr_out section_rest; do
    case "$section_rest" in *"$1"*) printf %s "$section_addr_out"; break; esac
  done < /proc/$$/maps
}


get_read_syscall_ret_addr(){
  : 'Print decimal addr where a next syscall will return, to put jumper, as trigger'
  #read -r syscall_info < /proc/self/syscall
  IFS=' ' read -r _sys_nb _sys_a1 _sys_a2 _sys_a3 _sys_a4 _sys_a5 _sys_a6 _sys_sp sys_ret < /proc/self/syscall
  printf "%s" "${sys_ret##??}"  # Remove the 0x prefix
}


endian(){
  : 'Change endianness of hex string (arg1)'
  out_endian='' rest="$1"
  while [ -n "$rest" ]; do
    tail="${rest#??}"
    out_endian="${rest%"$tail"}$out_endian"
    rest="$tail"
  done
  printf "%s" "$out_endian"
}


unhexify(){
  : 'Convert hex string (arg1) to binary stream (stdout): see README'
  escaped='' rest="$1"
  while [ -n "$rest" ]; do
    tail="${rest#??}"
    escaped="$escaped\\$(printf "%o" 0x"${rest%"$tail"}")"
    rest="$tail"
  done
  printf "$escaped"
}



hexify(){
  : 'Convert (arg1) bytes (stdin) to ascii hex (stdout) [WARNING: slow]'
  byte_counter=0
  while [ "$byte_counter" -lt "$1" ]; do
    # read one byte, using a work around for the fact that command
    # substitution strips the last character.
    c=$(dd bs=1 count=1 2> /dev/null; echo .)
    c=${c%.} 2> /dev/null
    printf "%02x" "'$c"
    : $((byte_counter+=1))
  done
}


hex2dec(){
  : 'Convert hex number to decimal number'
  printf "%d" 0x"$1"
}


is_sourced(){
  : 'Is script sourced?  # From: https://stackoverflow.com/a/28776166/2544873'
  [ -z "$INMEMBIN_SOURCED" ] && [ "$INMEMBIN_SOURCED" -ne 0 ] && return "$INMEMBIN_SOURCED"

  if [ -n "$ZSH_VERSION" ]; then
    case $ZSH_EVAL_CONTEXT in *:file) INMEMBIN_SOURCED=1;; esac
  elif [ -n "$BASH_VERSION" ]; then
    # shellcheck disable=SC3028,SC3054  # In POSIX sh, BASH_SOURCE, array reference also undefined
    [ "${BASH_SOURCE[0]}" != "$0" ] && INMEMBIN_SOURCED=1
  elif [ -n "$KSH_VERSION" ]; then
    # shellcheck disable=SC2296  # Parameter expansions can't start with .
    case $KSH_VERSION in
      *AJM*) [ "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ] && INMEMBIN_SOURCED=1;;  # ksh83
      *) case ${0##*/} in ksh|mksh) INMEMBIN_SOURCED=1; esac;;  # mksh, including *MIRBSD*|*"PD KSH"*)
    esac
  else # All other shells: examine $0 for known shell binary filenames.
    # Detects sh and dash and ksh; add additional shell filenames as needed.
    case ${0##*/} in sh|-sh|ash|-ash|dash|-dash|yash|test_inmembin.sh) INMEMBIN_SOURCED=1;; esac
  fi
  return $(( ! INMEMBIN_SOURCED ))
}


# __main__
is_sourced || { create_memfd; tail -f /dev/null; }
