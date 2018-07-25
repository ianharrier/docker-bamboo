#!/bin/sh
set -e

TIMESTAMP=$(date +%Y%m%dT%H%M%S%z)
START_TIME=$(date +%s)

cd "$HOST_PATH"

if [ "$BACKUP_OPERATION" = "disable" ]; then
    echo "[W] Backups are disabled."
else
    if [ ! -d backups ]; then
        echo "[I] Creating backup directory."
        mkdir backups
    fi

    if [ -d backups/tmp_backup ]; then
        echo "[W] Cleaning up from a previously-failed execution."
        rm -rf backups/tmp_backup
    fi

    echo "[I] Creating working directory."
    mkdir -p backups/tmp_backup

    echo "[I] Performing initial backup of Bamboo home directory."
    rsync --archive --delete volumes/web/data/ backups/tmp_backup/home

    echo "[I] Pausing Bamboo."
    STATE=$(curl --silent \
        --user ${BAMBOO_USERNAME}:${BAMBOO_PASSWORD} \
        --request POST \
        --header "Content-Type:application/json" \
        --header "Accept:application/json" \
        "http://web:8085/rest/api/latest/server/pause?os_authType=basic" \
      | jq --raw-output '.state')
    while [ "$STATE" != "PAUSED" ]; do
        if [ "$STATE" = "PAUSING" ]; then
            sleep 1
            STATE=$(curl --silent \
                --user ${BAMBOO_USERNAME}:${BAMBOO_PASSWORD} \
                --request GET \
                --header "Content-Type:application/json" \
                --header "Accept:application/json" \
                "http://web:8085/rest/api/latest/server" \
              | jq --raw-output '.state')
        else
            echo "[E] Failed to pause Bamboo."
            exit 1
        fi
    done
    echo "[I] Successfully paused Bamboo."

    echo "[I] Performing incremental backup of Bamboo home directory."
    rsync --archive --delete volumes/web/data/ backups/tmp_backup/home

    echo "[I] Backing up Bamboo database."
    PGPASSWORD=${POSTGRES_PASSWORD} pg_dump --host=db --username=${POSTGRES_USER} --dbname=${POSTGRES_DB} > backups/tmp_backup/db.sql

    echo "[I] Resuming Bamboo."
    STATE=$(curl --silent \
        --user ${BAMBOO_USERNAME}:${BAMBOO_PASSWORD} \
        --request POST \
        --header "Content-Type:application/json" \
        --header "Accept:application/json" \
        "http://web:8085/rest/api/latest/server/resume?os_authType=basic" \
      | jq --raw-output '.state')
    if [ "$STATE" = "RUNNING" ]; then
        echo "[I] Successfully resumed Bamboo."
    else
        echo "[W] Failed to resume Bamboo."
    fi

    echo "[I] Compressing backup."
    tar -zcf backups/$TIMESTAMP.tar.gz -C backups/tmp_backup .

    echo "[I] Removing working directory."
    rm -rf backups/tmp_backup

    EXPIRED_BACKUPS=$(ls -1tr backups/*.tar.gz 2>/dev/null | head -n -$BACKUP_RETENTION)
    if [ "$EXPIRED_BACKUPS" ]; then
        echo "[I] Cleaning up expired backup(s):"
        for BACKUP in $EXPIRED_BACKUPS; do
            echo "      $BACKUP"
            rm "$BACKUP"
        done
    fi
fi

END_TIME=$(date +%s)

echo "[I] Script complete. Time elapsed: $((END_TIME-START_TIME)) seconds."
