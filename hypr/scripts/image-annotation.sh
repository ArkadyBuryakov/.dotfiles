#!/bin/bash

if wl-paste -l | grep -q "image/png"; then
  wl-paste -t image/png | swappy -f -
elif wl-paste -l | grep -q "text/uri-list"; then
  path=$(gio info $(wl-paste) | grep 'local path: ')
  path=${path##local path: }
  swappy -f ${path}
else
  notify-send "Image annotation" "No image in clipboard."
fi
