#!/bin/bash
#
# Backup personal data from trakt.tv service.
#
# This script downloads my personal cloud data from the aforementioned
# service and dumps it to the console in a machine readable format. It
# can be used as a cronjob to produce regular backups.
#
# (c) Copyright 2015 Michael Starzinger. All Rights Reserved.
# Use of this work is governed by a license found in the LICENSE file.
#

BASE="$(cd "$(dirname "$0")" && pwd)"
CLIENT_FILE="$BASE/api-client"

# Parse all command line options.
while [[ $# > 1 ]]; do
  case "$1" in
    -u|--username)
      USERNAME="$2"
      shift
      ;;
    -f|--restore-file)
      RESTORE_FILE="$2"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Check that a username has been provided.
if [ -z "$USERNAME" ]; then
  echo "No username has been provided."
  exit 1
fi

# Check that a restore file has been preovided
if [ -z "$RESTORE_FILE" ]; then
  echo "No restore file has been provided."
  exit 1
fi

# The API client ID we are using to connect.
CLIENT_ID=$(grep "CLIENT_ID" "$CLIENT_FILE" | awk -F '=' '{ print $2 }')
if [ -z "$CLIENT_ID" ]; then
  echo "No CLIENT_ID has been specified."
  exit 1
fi

# Check that the 'auth' file exists.
AUTH_FILE="$BASE/auth-$USERNAME"
if [ ! -f "$AUTH_FILE" ]; then
  echo "No 'auth-$USERNAME' file present."
  exit 1
fi

# The authentication refresh token to be used.
AUTH_TOKEN=$(grep -e '^[^#]' "$AUTH_FILE" | tail -n 1 | awk -F ' ' '{ print $2 }')
if [ -z "$AUTH_TOKEN" ]; then
  echo "No authentication token provided."
  exit 1
fi

# Create temporary working directory.
TMP_DIR=$(mktemp -d)

# Extract the file to be restored
tar -x -z -f "$RESTORE_FILE" -C "$TMP_DIR" --strip 1

# Clear Trakt history to prevent duplicate watches
HISTORY_IDS=$(curl --silent\
    --header "Authorization: Bearer $AUTH_TOKEN" \
    --header "Content-Type: application/json" \
    --header "trakt-api-version: 2" \
    --header "trakt-api-key: $CLIENT_ID" \
    "https://api.trakt.tv/users/$USERNAME/history/?page=1&limit=999999" | grep -oP '(?<=\"id":).*?(?=,)' | paste -sd "," -)
curl --silent \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header "Content-Type: application/json" \
  --header "trakt-api-version: 2" \
  --header "trakt-api-key: $CLIENT_ID" \
  --data "{\"ids\":[$HISTORY_IDS]}" \
  --output restore-remove.log \
  "https://api.trakt.tv/sync/history/remove" -X POST

# Restore collections
COLLECTION_MOVIES=$(<$TMP_DIR/collection_movies.json)
COLLECTION_MOVIES=$(echo $COLLECTION_MOVIES | sed -e 's|"movie":{||g')
COLLECTION_MOVIES=$(echo $COLLECTION_MOVIES | sed -e 's|}}}|}}|g')
COLLECTION_SHOWS=$(<$TMP_DIR/collection_shows.json)
COLLECTION_SHOWS=$(echo $COLLECTION_SHOWS | sed -e 's|"show":{||g')
COLLECTION_SHOWS=$(echo $COLLECTION_SHOWS | sed -e 's|}}|}|g')
COLLECTION="{\"movies\":$COLLECTION_MOVIES,\"shows\":$COLLECTION_SHOWS}"
curl --silent \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header "Content-Type: application/json" \
  --header "trakt-api-version: 2" \
  --header "trakt-api-key: $CLIENT_ID" \
  --data @- \
  --output restore-collection.log \
  "https://api.trakt.tv/sync/collection" -X POST \
  <<CURL_DATA
  $COLLECTION
CURL_DATA

# Restore history
HISTORY_MOVIES=$(<$TMP_DIR/history_movies.json)
HISTORY_MOVIES=$(echo $HISTORY_MOVIES | sed -e 's|"movie":{||g')
HISTORY_MOVIES=$(echo $HISTORY_MOVIES | sed -e 's|}}}|}}|g')
HISTORY_SHOWS=$(<$TMP_DIR/history_shows.json)
HISTORY_SHOWS=$(echo $HISTORY_SHOWS | sed -e 's|"episode":{||g')
HISTORY_SHOWS=$(echo $HISTORY_SHOWS | sed -e 's|}},"show"|},"show"|g')
HISTORY_SHOWS=$(echo $HISTORY_SHOWS | perl -pe 's|,"show":\{.*?\}.*?\}||g')
HISTORY="{\"movies\":$HISTORY_MOVIES,\"episodes\":$HISTORY_SHOWS}"
curl --silent \
  --header "Authorization: Bearer $AUTH_TOKEN" \
  --header "Content-Type: application/json" \
  --header "trakt-api-version: 2" \
  --header "trakt-api-key: $CLIENT_ID" \
  --data @- \
  --output restore-history.log \
  "https://api.trakt.tv/sync/history" -X POST \
  <<CURL_DATA
  $HISTORY
CURL_DATA

# Cleanup after ourself.
rm -r "$TMP_DIR"
