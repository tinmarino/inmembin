#!/bin/sh
# Arg1: image
# Arg2: shell


install_main(){
  image=$1
  shell=$2
  # Discriminate package name
  apt=""
  case "$shell" in
    # Sh do not require install
    sh)
      :
      ;;
    # Ash is called dash
    ash)
      if [ "$image" = alpine ] \
          || [ "$image" = archlinux ]; then
        apt=dash
      else
        apt=ash
      fi
      ;;
    ksh)
      if [ "$image" = alpine ]; then
        apt=mksh
      else
        apt=ksh
      fi
      ;;
    *)
      apt=$shell
      ;;
  esac

  # Discriminate installation method
  case "$image" in
    alpine)
      apk update
      apk add which bash
      apk add coreutils
      apk add xxd
      [ -n "$apt" ] && apk add "$apt"
      [ mksh = "$apt" ] && ln -s /bin/mksh /bin/ksh
      ;;
    debian)
      apt-get update
      apt-get install -y xxd
      [ -n "$apt" ] && apt-get install -y "$apt"
      ;;
    archlinux)
      pacman -Sy --noconfirm which
      pacman -Sy --noconfirm xxd
      [ -n "$apt" ] && pacman -Sy --noconfirm "$apt"
      [ dash = "$apt" ] && ln -s /bin/dash /bin/ash
      ;;
  esac
  return 0
}
