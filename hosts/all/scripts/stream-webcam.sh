#!/bin/bash

if ! [ -f /etc/enable-webcam-stream ]; then
    echo "webcam stream disabled (/etc/enable-webcam-stream not present)"
    exit 0
fi

video_devices="$(ls -1 /dev/video[0-9] 2>/dev/null)"

if [ ! "$video_devices" ]; then
    echo "no video devices found"
    exit 0
fi

for video_dev in $video_devices; do
    good_idx=
    mapped_idx=
    v4l2loopback_video_nr=
    echo "checking $video_dev..."
    if v4l2-ctl -V -d "$video_dev"; then
        echo "  ...looks good"
        idx=$(echo "$video_dev"|sed -r 's/.*([0-1]+)$/\1/')
	if [ ! "$idx" ]; then
		echo "invalid video dev name $video_dev"
	fi
        mapped_idx=$((100 + $idx))
	sudo -u user cvlc v4l2://$video_dev:chroma=MJPG:fps=10:size=1920x1080 --live-caching=100 --sout "#standard{access=http,mux=mpjpeg,dst=:8$mapped_idx,fps=10}" --no-sout-audio &
    else
        echo "  ...skipping"
    fi
done
