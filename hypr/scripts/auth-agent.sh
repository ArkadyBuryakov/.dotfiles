#!/bin/bash

# This script is used to launch the polkit-kde-authentication-agent-1 and restart it if it crashes.
while true; do
	/usr/lib/polkit-kde-authentication-agent-1
	sleep 0.1
done
