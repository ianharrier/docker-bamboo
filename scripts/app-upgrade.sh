#!/bin/sh
set -e

START_TIME=$(date +%s)

# The backup process will fail if the db and web containers are not started.

echo "=== Starting backup container. ================================================="
docker-compose up -d backup

echo "=== Backing up application stack. =============================================="
docker-compose exec backup app-backup

echo "=== Removing currnet application stack. ========================================"
docker-compose down

echo "=== Pulling changes from repo. ================================================="
git pull

echo "=== Updating environment file. ================================================="
OLD_BAMBOO_VERSION=$(grep ^BAMBOO_VERSION= .env | cut -d = -f 2)
NEW_BAMBOO_VERSION=$(grep ^BAMBOO_VERSION= .env.template | cut -d = -f 2)
echo "[I] Upgrading Bamboo from '$OLD_BAMBOO_VERSION' to '$NEW_BAMBOO_VERSION'."
sed -i.bak "s/^BAMBOO_VERSION=.*/BAMBOO_VERSION=$NEW_BAMBOO_VERSION/g" .env

echo "=== Deleting old images. ======================================================="
IMAGE_BACKUP=$(docker images ianharrier/bamboo-backup -q)
IMAGE_WEB=$(docker images ianharrier/bamboo -q)
docker rmi $IMAGE_BACKUP $IMAGE_WEB

echo "=== Building new images. ======================================================="
docker-compose build --pull

echo "=== Pulling updated database image. ============================================"
docker-compose pull db

echo "=== Starting backup container. ================================================="
docker-compose up -d backup

echo "=== Restoring application stack to most recent backup. ========================="
cd backups
LATEST_BACKUP=$(ls -1tr *.tar.gz 2> /dev/null | tail -n 1)
cd ..
docker-compose exec backup app-restore $LATEST_BACKUP

END_TIME=$(date +%s)

echo "=== Upgrade complete. =========================================================="
echo "[I] Time elapsed: $((END_TIME-START_TIME)) seconds."
