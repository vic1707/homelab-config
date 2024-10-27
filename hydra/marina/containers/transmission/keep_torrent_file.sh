#!/bin/sh

__log() {
    log="$(date +'%Y-%m-%d %H:%M:%S') - $1"
    echo "$log" >> "$PWD/keep_torrent_file.log"
    echo "$1" >> /proc/1/fd/1 # not available on linuxserver's images
}

################################ Pre-existing variables #################################
# TR_APP_VERSION - Transmission's short version string, e.g. 4.0.0                      #
# TR_TIME_LOCALTIME                                                                     #
# TR_TORRENT_BYTES_DOWNLOADED - Number of bytes that were downloaded for this torrent   #
# TR_TORRENT_DIR - Location of the downloaded data                                      #
# TR_TORRENT_HASH - The torrent's info hash                                             #
# TR_TORRENT_ID                                                                         #
# TR_TORRENT_LABELS - A comma-delimited list of the torrent's labels                    #
# TR_TORRENT_NAME - Name of torrent (not filename)                                      #
# TR_TORRENT_TRACKERS - A comma-delimited list of the torrent's trackers' announce URLs #
#########################################################################################
# src: https://github.com/transmission/transmission/blob/main/docs/Scripts.md           #
#########################################################################################

PWD=$(cd "$(dirname "$0")" && pwd && cd - > /dev/null || exit 1)
TORRENT_DIR="$PWD/torrents"
TORRENT_FILE_PATH="$TORRENT_DIR/$TR_TORRENT_HASH.torrent"

if ! [ -f "$TORRENT_FILE_PATH" ]; then
    __log "[$TR_TORRENT_NAME] - $TORRENT_FILE_PATH not found for $TR_TORRENT_NAME !"
    exit 1
fi

cp "$TORRENT_FILE_PATH" "$TR_TORRENT_DIR/$TR_TORRENT_NAME.torrent"
__log "[$TR_TORRENT_NAME] - $TR_TORRENT_HASH.torrent"
