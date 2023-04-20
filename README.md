# In Memory Binary

| Shell | Debian | Archlinux | Alpine |
| ---   | ---    | ---       | --- |
| __bash__  | [![Bash on Debian](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_bash_on_debian.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) | [![Bash on Arch](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_bash_on_archlinux.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) | [![Bash on Alpine](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_bash_on_alpine.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) |
| __zsh__  | [![Zsh on Debian](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_zsh_on_debian.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) | [![Zsh on Arch](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_zsh_on_archlinux.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) | [![Zsh on Alpine](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_zsh_on_alpine.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) |
| __ash__  | [![Ash on Debian](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_ash_on_debian.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) | [![Ash on Arch](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_ash_on_archlinux.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) | [![Ash on Alpine](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_ash_on_alpine.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) |
| __ksh__  | [![Ash on Debian](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_ksh_on_debian.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) | [![Ksh on Arch](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_ksh_on_archlinux.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) | [![Ksh on Alpine](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_ksh_on_alpine.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) |
| __sh__  | [![Ash on Debian](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_sh_on_debian.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) | [![Sh on Arch](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_sh_on_archlinux.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) | [![Sh on Alpine](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tinmarino/7b40042f91625feffeaa1941f7aba953/raw/in_mem_bin_CI_sh_on_alpine.json)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/main.yml) |

[![license](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Typos](https://github.com/tinmarino/in_mem_bin.sh/workflows/Typos/badge.svg)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/typos.yml)
[![Shellcheck](https://github.com/tinmarino/in_mem_bin.sh/workflows/Shellcheck/badge.svg)](https://github.com/tinmarino/in_mem_bin.sh/actions/workflows/shellcheck.yml)

Execute binary code from shell without touching the filesystem. Hard copied from [arget13/ddsc.sh](https://github.com/arget13/DDexec/blob/49498ff6cc0bff4afe848565e6fe7d0558fab5f1/ddsc.sh)

# Quickstart

```sh
git clone --depth=1 https://github.com/tinmarino/in_mem_bin.sh InMemBin && cd InMemBin

/proc/self/exe ./in_mem_bin.sh & pid=$!         # Create memfd
sleep 0.3 
cp "$(command which echo)" /proc/"$pid"/fd/4    # Fill it with a binary
/proc/"$pid"/fd/4 -e "\e[34mmy message\e[0m"    # Execute the in-mem binary
```

# Feature

Requires: dd uname cut

Supports: bash zsh ash (dash) ksh (mksh) sh

# Verbose shell code description

### main

The main routine is crafting and writing in memory

1. shellcode
2. jumper: small `jmp` instruction to jump to it.

### hex2dec

Using the printf method

```sh
printf "%d" 0x10  # Posix compatible
$(( 0x10 ))  # More readable
```

Ksh (mksh) do not support 64 bit arithmetic and hardly support unsigned integer (I did not succeed). So the hex2dec: $((0x10)) used by @arget13 was replaced by printf "%d"

### readmem


### seek

Using the dd method

```sh
dd bs=1 skip="$1" > /dev/null 2>&1  # From coreutils
tail -c +$(( $1 + 1 )) >/dev/null 2>&1  # From coreutils + Bad for ksh
od -j $(( $1 + 1 )) -N 0 >/dev/null 2>&1  # From coreutils
cmp -i "$1" /dev/null > /dev/null 2>&1  # From diffutils
hexdump -s "$1" > /dev/null 2>&1  # From util-linux
xxd -s "$1" > /dev/null 2>&1  # From vim
```

Ksh is not supporting the `$(( $1 + 1 ))` arithmetic. This is unfortunate, I would have preferred to use tail like @arget13, just for personal affinity.

Silence error to avoid: error reading standard input: Bad file descriptor, which I do not care

### endian

String indexing is not supported in sh and ash. As shellcode are supposed to be small, just invert pair of chars by preprending each next pair (like vim `:g/.*/m0`).

Initially I was appending, but anyway the `+=` operator is not supported in ash.

### unhexlify

In shell, variable cannot hold null byte as strings are zero terminated. So byte streams must be send to pipes

```sh
printf "\\$(printf "%o" 0x41)"  # Posix compatible
printf "\x41"  # Bash but not posix compatible
```

### fetch addresses

Basic parsing of the /proc filesystem

### craft shellcode and jumper

Embed hex strings of binaries, maybe with recently fetched pointers

# Linux magic path

* /proc/self/mem
* /proc/self/maps
* /proc/self/syscalls


# Asm


### 0/ debug

```nasm
"ELF"  ; 7f454c
int    0x3  ; 0: cd 03 => just a sheetcheat

pop eax       ; 58
xor eax, eax  ; 31c0
```

```sh
nasm syscall_memfd_create.asm -o syscall_memfd_create.bin
objdump -b binary -m i386:x86-64 -D syscall_memfd_create.bin

sudo xxd -s $((0x7f5a53314992)) -c 10000 -l 10000 -p /proc/$$/mem | xxd -r -p > tail.bin

objdump -b binary -m i386:x86-64 -D -M intel tail.bin > tail.asm

setarch x86_64 -R bash in_mem_bin.sh
```


### 1/ [dup2](https://chromium.googlesource.com/chromiumos/docs/+/HEAD/constants/syscalls.md#arm_63)

Arget13 is duplicating 0<-2 because his stdin was redirected from a pipe.

```nasm
xor    rax,rax  ; 0:   48 31 c0                
mov    rsi,rax  ; 3:   48 89 c6                
mov    al,0x2   ; 6:   b0 02                   
mov    rdi,rax  ; 8:   48 89 c7                
mov    al,0x21  ; b:   b0 21                   
syscall         ; d:   0f 05                   
```

### 2/ [memfd_create](https://chromium.googlesource.com/chromiumos/docs/+/HEAD/constants/syscalls.md#x86_64_319)

```c
int memfd_create(char* filename, unsigned int flags) // sig 0x164
// Return 4 <= FD
```

If filename is NULL => Segmentation fault (I think this is subobtimal impl from Linux kernel as the name is useless)


Original: (20 bytes, including 8 to set filename string)

68444541444889e74831f64889f0b401b03f0f054889c7b04d0f05b0220f05

```nasm
push   0x44414544   ; 0:   68 44 45 41 44 => "DEAD"
mov    rdi,rsp      ; 5:   48 89 e7 => arg1: Point to "DEAD"
xor    rsi,rsi      ; 8:   48 31 f6 => arg2: Flag 0
mov    rax,rsi      ; b:   48 89 f0
mov    ah,0x1       ; e:   b4 01
mov    al,0x3f      ;10:   b0 3f
syscall             ;12:   0f 05
```

Naive: For comparison, here is my naive intent (17 bytes but crash)

```nasm
mov    eax,0x13f  ;0:   b8 3f 01 00 00          
mov    edi,0x0    ;5:   bf 00 00 00 00          
mov    esi,0x0    ;a:   be 00 00 00 00          
syscall           ;f:   0f 05                   
```

### 3/ [ftruncate](https://chromium.googlesource.com/chromiumos/docs/+/HEAD/constants/syscalls.md#x86_64_77)
Optional, seems to be for early fail

```c
int truncate(const char *path, off_t length);  // sig 0x4d
// Return 0 => success
```

```nasm
mov    rdi,rax      ;14:   48 89 c7
mov    al,0x4d      ;17:   b0 4d
syscall             ;19:   0f 05
```

### 4/ [pause](https://chromium.googlesource.com/chromiumos/docs/+/HEAD/constants/syscalls.md#x86_64_34)
Wait for a signal

```c
int pause(void);
// Do not return or returns -1 in case a signal stopped it
// -- but, for me, return 0xfffffffffffffdfe = -514
// -- with debugger and ctrl-c
```

```nasm
mov    al,0x22      ;1b:   b0 22
syscall             ;1d:   0f 05
```

### 5/ [mprotect](https://chromium.googlesource.com/chromiumos/docs/+/HEAD/constants/syscalls.md#x86_64_10)

```c
int mprotect(void *addr, size_t len, int prot);  // sig 0xa
```

Page size is 4096


# Temporary Dump

Jumper addr: page, hex, dec
7ffff7d14000
7ffff7d14992
140737351076242

# Credit

Copied from [arget13/ddsc.sh](https://github.com/arget13/DDexec/blob/49498ff6cc0bff4afe848565e6fe7d0558fab5f1/ddsc.sh) => see credit there

# Link

* [syscall and arguments](https://chromium.googlesource.com/chromiumos/docs/+/HEAD/constants/syscalls.md)
* [parent project (ddexec)](https://github.com/arget13/DDexec)
