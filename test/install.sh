#!/usr/bin/env bash
# Arg1: image
# Arg2: shell
# No include, I will be copied
# shellcheck disable=SC2089,SC2090  # Quotes/backslashes will be

install_main(){
  set -x
  PS4="$(printf %b "\033[34m")Running: \$(date +\"%F %T\"):$(printf %b "\033[0m") "

  image=$1
  shell=$2
  apt=""

  # Discriminate package name
  case "$shell" in
    # Sh do not require install
    sh)
      :
      ;;
    # Ash is called dash
    ash)
      if [ alpine = "$image" ] \
          || [ archlinux = "$image" ]; then
        apt=dash
      else
        apt=ash
      fi
      ;;
    ksh)
      if [ alpine = "$image" ]; then
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
      # Update
      pacman -Syyu --noconfirm
      # pacman -Sy --noconfirm openssl-1.1 # Bug, because pacman friends need it
      pacman -Sy --noconfirm which
      pacman -Sy --noconfirm xxd
      pacman -Sy --noconfirm diffutils  # cmp command for binary file comparison
      [ -n "$apt" ] && [ "$apt" != yash ] && pacman -Sy --noconfirm "$apt"
      [ dash = "$apt" ] && ln -s /bin/dash /bin/ash
      [ yash = "$apt" ] && {
        # Prepare: Must install from AUR
        pacman -Sy --noconfirm wget  # To download the AUR maker
        pacman -Sy --noconfirm sudo  # To avoid being root for makepkg (not allowed)
        pacman -Sy --noconfirm fakeroot  # To Install pack for AUR
        pacman -Sy --noconfirm base-devel  # Strip to install package from AUR
        pacman -Sy --noconfirm ed  # Required by yash, the venerable editor lol!

        # Install yash
        # -- Get
        wget https://aur.archlinux.org/cgit/aur.git/snapshot/yash.tar.gz
        tar xf yash.tar.gz
        cd yash || return 42
        # -- Make
        chmod 777 .
        sudo -u nobody makepkg
        # -- Install
        pacman --noconfirm -U yash-*pkg.tar.*
      }
      ;;
  esac

  # Yash need latin1 as it is really character wise and not bytewise
  if [ yash = "$shell" ]; then
    case $image in
      debian) apt-get install -y wget;;
      alpine)     apk add wget;;
      archlinux)  pacman -Sy --noconfirm wget;;
    esac

    wget https://github.com/tinmarino/inmembin/raw/ci/test/ISO-8859-15.gz
    mkdir -p /usr/share/i18n/charmaps
    cp ISO-8859-15.gz /usr/share/i18n/charmaps/ISO-8859-15.gz

    case $image in
      debian)
        apt install -y locales
        # locale-gen en_US.ISO-8859-15
        echo en_US ISO-8859-15 >> /etc/locale.gen
        locale-gen
        update-locale  # sudo

        echo -e "LANG=en_US.ISO-8859-15\nLC_CTYPE=en_US.ISO-8859-15" >> /etc/locale.conf
        ;;
      alpine)
        ;;
      archlinux)
        echo "en_US ISO-8859-15" >> /etc/locale.gen
        locale-gen
        echo -e "LANG=en_US.ISO-8859-15\nLC_CTYPE=en_US.ISO-8859-15" >> /etc/locale.conf
        # Reload
        unset LANG LC_CTYPE
        source /etc/profile.d/locale.sh
        ;;
    esac
  fi


  export PS4='+ '
  set +x

  return 0
}
