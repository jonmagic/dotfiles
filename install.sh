#!/bin/bash

if [[ -n "$CODESPACES" ]]
then
  install-codespaces.sh
elif [[ $OSTYPE == darwin* ]]; then
  install-macos.sh
else
  echo "Unsupported operating system: $OSTYPE"
fi
