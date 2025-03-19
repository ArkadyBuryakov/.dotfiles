#!/bin/bash

# NMTui doesn't handle well resising. This delay is used to give the terminal time to get its size right.
sleep 0.1 && nmtui
