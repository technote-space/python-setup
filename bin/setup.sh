#!/bin/bash

set -e

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <python version> <name>"
  exit 1
fi

if [[ $(uname -s) == 'Darwin' ]]; then
  # for macOS
  if ! command -v brew 1>/dev/null 2>&1; then
    # install Homebrew if not installed
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi

  if ! command -v pyenv 1>/dev/null 2>&1; then
    # install pyenv and pyenv-virtualenv if not installed
    brew install pyenv
    brew install pyenv-virtualenv
  fi
else
  # for Linux
  # install packages for pyenv (@see https://github.com/pyenv/pyenv/wiki/Common-build-problems)
  if command -v yum 1>/dev/null 2>&1; then
    sudo yum install -y @development zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel xz xz-devel libffi-devel findutils
  else
    sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python-openssl git
  fi

  if ! command -v pyenv 1>/dev/null 2>&1; then
    # install pyenv and pyenv-virtualenv if not installed
    git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv
  fi
fi

# settings file
PROFILE="$HOME/.bash_profile"
if test -f "$HOME/.zsh_history"; then
  # for macOS
  PROFILE="$HOME/.zshrc"
fi

if ! grep <"$PROFILE" -q pyenv; then
  # https://github.com/pyenv/pyenv
  # https://github.com/pyenv/pyenv-virtualenv

  # shellcheck disable=SC2016
  echo 'export PYENV_ROOT="$HOME/.pyenv"' | sudo tee -a "$PROFILE"
  # shellcheck disable=SC2016
  echo 'export PATH="$PYENV_ROOT/bin:$PATH"' | sudo tee -a "$PROFILE"
  # shellcheck disable=SC2016
  echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\n  eval "$(pyenv virtualenv-init -)"\nfi' | sudo tee -a "$PROFILE"
fi

REQUIRED_RUN_SOURCE=
if ! echo "$PATH" | grep -q pyenv; then
  # shellcheck disable=SC1090
  source "$PROFILE"
  REQUIRED_RUN_SOURCE=1
fi

VERSION=${1}
ESCAPED="$(printf '%s' "$VERSION" | sed 's/[.[\*^$]/\\&/g')"
if ! pyenv versions --bare --skip-aliases | grep -e "^$ESCAPED$" 1>/dev/null 2>&1; then
  if [[ $(uname -s) == 'Darwin' ]] && [[ $(uname -m) == 'arm64' ]]; then
    arch -arch x86_64 env PATH=${PATH/\/opt\/homebrew\/bin:/} pyenv install "$VERSION"
  else
    pyenv install "$VERSION"
  fi
fi

if ! test -f .python-version; then
  NAME=${2}
  ESCAPED="$(printf '%s' "$NAME" | sed 's/[.[\*^$]/\\&/g')"
  if ! pyenv versions --bare | grep -e "^$ESCAPED$" 1>/dev/null 2>&1; then
    pyenv virtualenv "$VERSION" "$NAME"
  fi
  pyenv local "$NAME"
fi

# dump python version
python --version

# install pipenv
pip install pipenv
pipenv --version

if test -n "$REQUIRED_RUN_SOURCE"; then
  ESC=$(printf '\033')
  echo
  echo "============================="
  echo
  printf "${ESC}[31m%s${ESC}[m\n" 'Please run following command:'
  echo "source $PROFILE"
  echo
  echo "============================="
fi
