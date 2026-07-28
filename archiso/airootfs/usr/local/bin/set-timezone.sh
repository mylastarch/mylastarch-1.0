#!/bin/bash
# Auto-detect and set timezone using GeoIP
TIMEZONE=$(curl -s https://ipapi.co/timezone 2>/dev/null)
if [ -n "$TIMEZONE" ] && [ "$TIMEZONE" != "undefined" ]; then
    timedatectl set-timezone "$TIMEZONE"
fi