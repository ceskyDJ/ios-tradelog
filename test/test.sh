#!/bin/bash

# This file is for local tests (on GNU/Linux OSes) only

PROJECT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$PROJECT_PATH/../" || exit

echo "$PWD"

# Run PHP tests
./test/iotest -l