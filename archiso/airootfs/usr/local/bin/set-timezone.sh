#!/usr/bin/env bash

# Auto-detect the timezone using GeoIP. NetworkManager may still be bringing
# the connection up when this runs during boot, so briefly retry failures.
for attempt in {1..5}; do
    response=$(curl --fail --silent --show-error \
        --connect-timeout 5 --max-time 10 \
        https://geoip.kde.org/v1/ubiquity 2>/dev/null) || response=""

    # KDE's GeoIP service returns the IANA zone in an XML TimeZone element.
    timezone=$(sed -n 's:.*<TimeZone>\([^<]*\)</TimeZone>.*:\1:p' <<< "$response")

    # Accept only a timezone name that exists in the installed timezone data.
    case "$timezone" in
        ""|/*|*..*) ;;
        *)
            if [[ -e "/usr/share/zoneinfo/$timezone" ]]; then
                echo "Setting timezone to $timezone"
                exec timedatectl set-timezone "$timezone"
            fi
            ;;
    esac

    echo "Timezone detection attempt $attempt failed" >&2
    (( attempt < 5 )) && sleep 3
done

echo "Unable to detect a valid timezone from the KDE GeoIP service" >&2
exit 1
