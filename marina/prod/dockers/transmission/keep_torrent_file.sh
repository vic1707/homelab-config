#!/bin/sh

__log() {
  echo "$1" >> "$PWD/keep_torrent_file.log"
  echo "$1" >> /proc/1/fd/1
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
TORRENT_DIR="/config/transmission-home/torrents"

if [ -f "$TORRENT_DIR/$TR_TORRENT_HASH.torrent" ]; then
  cp "$TORRENT_DIR/$TR_TORRENT_HASH.torrent" "/data/completed/$TR_TORRENT_NAME.torrent"
  __log "$(date +'%Y-%m-%d %H:%M:%S') - Backed up $TR_TORRENT_HASH.torrent as $TR_TORRENT_NAME.torrent"
  exit 0
fi
__log "$(date +'%Y-%m-%d %H:%M:%S') - $TR_TORRENT_HASH.torrent not found for $TR_TORRENT_NAME"
exit 1
