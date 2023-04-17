# Quickstart

```sh
git clone https://github.com/tinmarino/in_mem_bin.sh InMemBin && cd InMemBin
/proc/self/exe ./in_mem_bin.sh &
ls -l /proc/$!/fd
cp $(command which echo) /proc/$!/fd/3
/proc/$!/fd/3 -e "\e[34mmy message\e[0m"
```

# Credit

Copied from [arget13/ddsc.sh](https://github.com/arget13/DDexec/blob/49498ff6cc0bff4afe848565e6fe7d0558fab5f1/ddsc.sh) => see credit there
