#!/bin/bash

N=$(dpkg -l | grep ttf-bitstream-vera | wc -l)

if [ $N -lt 1 ]; then
	echo "Please install ubuntu package ttf-bitstream-vera. It is not installed."
	exit 1
fi

export GDFONTPATH=/usr/share/fonts/truetype/ttf-bitstream-vera

gnuplot ./gnuplot-xkcd-raw-linscale.gp

cp ./incoming-anomaly-scores-distribution.png ../incoming-anomaly-scores-distribution.png
