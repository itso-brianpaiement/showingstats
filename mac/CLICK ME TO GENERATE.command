#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo "=========================================="
echo "  Showing System Member Count Generator"
echo "=========================================="
echo

KEY_FILE="keys"
if [[ ! -f "$KEY_FILE" ]]; then
  if [[ -f "keys.txt" ]]; then
    KEY_FILE="keys.txt"
  else
    echo "ERROR: keys file not found."
    echo
    echo "Expected file name: keys"
    echo
    echo "Open the file named keys, enter your Bridge API values, and save it."
    echo
    read -n 1 -r -p "Press any key to close..."
    echo
    exit 1
  fi
fi

if [[ "$KEY_FILE" == "keys" ]] && grep -q "REPLACE_THIS_WITH_" "keys"; then
  if [[ -f "keys.txt" ]]; then
    KEY_FILE="keys.txt"
    echo "Detected placeholder values in keys. Using keys.txt instead."
    echo
  else
    echo "ERROR: The keys file still has template values."
    echo
    echo "Open the file named keys and replace all REPLACE_THIS_WITH_... values."
    echo "Then save the file and run this script again."
    echo
    read -n 1 -r -p "Press any key to close..."
    echo
    exit 1
  fi
fi

if [[ ! -x "/usr/bin/python3" ]]; then
  echo "ERROR: Python3 was not found at /usr/bin/python3."
  echo
  echo "This Mac runner needs python3 that normally ships with macOS."
  echo "If your Mac does not have it, contact IT for a packaged app build."
  echo
  read -n 1 -r -p "Press any key to close..."
  echo
  exit 1
fi

echo "Running data pull and report generation..."
echo

/usr/bin/python3 "./run_member_counts.py" --keys-file "./${KEY_FILE}"
EXIT_CODE=$?

echo
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "Generation failed. Exit code: $EXIT_CODE"
  echo
  read -n 1 -r -p "Press any key to close..."
  echo
  exit $EXIT_CODE
fi

echo "Generation complete."
echo "The files are in the output folder."
echo
read -n 1 -r -p "Press any key to close..."
echo
exit 0
