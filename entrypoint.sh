#!/bin/bash -e

EFT_BINARY=/opt/tarkov/EscapeFromTarkov.exe
LIVE_DIR=/opt/live/
PREFIX=/home/ubuntu/.wine
PREFIX_LIVE_DIR=$PREFIX/drive_c/live
XVFB_RUN="xvfb-run -a"
NOGRAPHICS="-nographics"
BATCHMODE="-batchmode"
NODYNAMICAI="-noDynamicAI"

export DISPLAY=:0.0

if [ "$XVFB_DEBUG" == "true" ]; then
    echo "Xvfb debug is ON. This is only supported for Xvfb running in foreground"
    XVFB_RUN="$XVFB_RUN -e /dev/stdout"
fi

if [ "$USE_GRAPHICS" == "true" ]; then
    echo "Using graphics"
    NOGRAPHICS=""
fi

if [ "$DISABLE_BATCHMODE" == "true" ]; then
    echo "Disabling batchmode"
    BATCHMODE=""
fi

if [ "$DISABLE_NODYNAMICAI" == "true" ]; then
    echo "Allowing dynamic AI"
    NODYNAMICAI=""
fi

if [ "$USE_MODSYNC" = "true" ]; then
    echo "Running Xvfb in background for modsync"
    XVFB_RUN=""
fi

# If directory doesn't exist or is empty
if [ ! -d $PREFIX_LIVE_DIR ] || [ -z "$(ls -A $PREFIX_LIVE_DIR)" ]; then
    echo "Symlinking live dir"
    ln -s /opt/live $PREFIX_LIVE_DIR
# TODO make this more robust
elif [ ! -f $PREFIX_LIVE_DIR/ConsistencyInfo ]; then
    echo "Live files not found! Make sure you mount a folder containing the live files to /opt/live"
    exit 1
fi

if [ "$USE_DGPU" == "true" ]; then
	source /opt/scripts/install_nvidia_deps.sh

	# Run Xorg server with required extensions
	sudo /usr/bin/Xorg "${DISPLAY}" vt7 -noreset -novtswitch -sharevts -dpi "${DISPLAY_DPI}" +extension "COMPOSITE" +extension "DAMAGE" +extension "GLX" +extension "RANDR" +extension "RENDER" +extension "MIT-SHM" +extension "XFIXES" +extension "XTEST" &

	# Wait for X server to start
	echo 'Waiting for X Socket' && until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do sleep 0.5; done && echo 'X Server is ready'
	unset XVFB_RUN
fi

if [ ! -f $EFT_BINARY ]; then
    echo "EFT Binary $EFT_BINARY not found! Please make sure you have mounted the Fika client directory to /opt/tarkov"
    exit 1
fi

run_xvfb() {
   /usr/bin/Xvfb ":0" -screen 0 1024x768x16 >/dev/null 2>&1 &
}

run_client() {
    WINEDEBUG=-all $XVFB_RUN wine $EFT_BINARY $BATCHMODE $NOGRAPHICS $NODYNAMICAI -token="$PROFILE_ID" -config="{'BackendUrl':'http://$SERVER_URL:$SERVER_PORT', 'Version':'live'}"
}

if [ "$USE_MODSYNC" == "true" ]; then
    while true; do
	# Anticipate the client exiting due to modsync, and restart it after modsync external updater has done its thing
	# I don't know why, but it seems on second run of the client it always fails to create a batchmode window,
	# so we have to restart xvfb after each run
	echo "Starting Xvfb in background"
	run_xvfb
	XVFB_PID=$!

	echo "Starting client. Xvfb running PID is $XVFB_PID"
	run_client
	echo "Dedi client closed with exit code $?. Restarting.." >&2
	kill -9 $XVFB_PID
	sleep 5
    done
else
    # run_xvfb
    run_client
fi
