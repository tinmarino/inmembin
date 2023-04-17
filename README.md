Execute binary code from shell without touching the filesystem. Hard copied from [arget13/ddsc.sh](https://github.com/arget13/DDexec/blob/49498ff6cc0bff4afe848565e6fe7d0558fab5f1/ddsc.sh)

# Quickstart

```sh
git clone --depth=1 https://github.com/tinmarino/in_mem_bin.sh InMemBin && cd InMemBin

/proc/self/exe ./in_mem_bin.sh & sleep 0.3  # Create memfd
cp "$(command which echo)" /proc/$!/fd/3    # Fill it with a binary
/proc/$!/fd/3 -e "\e[34mmy message\e[0m"    # Execute the in-mem binary
```

# Feature

Requires: dd uname cut

Supports: bash zsh ash ksh sh

# Credit

Copied from [arget13/ddsc.sh](https://github.com/arget13/DDexec/blob/49498ff6cc0bff4afe848565e6fe7d0558fab5f1/ddsc.sh) => see credit there
