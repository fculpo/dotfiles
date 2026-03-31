#!/bin/bash
# Toggle between normal (8px) and wide (120px) left/right margins
CONFIG="$HOME/.config/aerospace/aerospace.toml"

if grep -q 'outer.left = 120' "$CONFIG"; then
  sed -i '' 's/outer.left = 120/outer.left = 8/' "$CONFIG"
  sed -i '' 's/outer.right = 120/outer.right = 8/' "$CONFIG"
else
  sed -i '' 's/outer.left = 8/outer.left = 120/' "$CONFIG"
  sed -i '' 's/outer.right = 8/outer.right = 120/' "$CONFIG"
fi

aerospace reload-config
