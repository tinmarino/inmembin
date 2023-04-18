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

# Verbose coding patterns

### hex2dec

Using the printf method

```sh
printf "%d" 0x10  # Posix compatible
$(( 0x10 ))  # More readable
```


Ksh (mksh) do not support 64 bit arithmetic and hardly suport unsigned integer (I did not succeed). So the hex2dec: $((0x10)) used by @arget13 was replaced by printf "%d"

### `seek`

Using the dd method

```sh
dd bs=1 skip="$1" > /dev/null 2>&1  # From coreutils
tail -c +$(($1 + 1)) >/dev/null 2>&1  # From coreutils + Bad for ksh
cmp -i "$1" /dev/null > /dev/null 2>&1  # From diffutils
hexdump -s "$1" > /dev/null 2>&1  # From util-linux
xxd -s "$1" > /dev/null 2>&1  # From vim
```

Ksh is not supporting the `$(( $1 + 1 ))` arithmetic. This is unfortunate, I would have prefered to use tail like @arget13, just for personal afinity.

# Credit

Copied from [arget13/ddsc.sh](https://github.com/arget13/DDexec/blob/49498ff6cc0bff4afe848565e6fe7d0558fab5f1/ddsc.sh) => see credit there
