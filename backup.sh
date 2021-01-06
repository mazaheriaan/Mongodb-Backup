#!/bin/bash

# Writing bu Morteza Saki Jan 06 2021

# A script to perform incremental backups using rsync

set -o errexit
set -o nounset
set -o pipefail

# Check if collenction name set
if  [[ -z $1 ]]; then
    echo "Collection name is empty."
    exit 1
fi

# First parameter for collaction name
readonly DATABASE_NAME="mydb"
readonly COLLECTION_NAME="mycollection"
readonly BACKUP_DIR="mybackups"
readonly DATETIME="$(date '+%Y-%m-%d_%H:%M:%S')"
readonly DUMP_PATH="${BACKUP_DIR}/${COLLECTION_NAME}"
readonly FILE_NAME="${COLLECTION_NAME}_${DATETIME}.tar.gz"
readonly COMPRESS_PATH="${BACKUP_DIR}/${FILE_NAME}"
readonly PATH_DIR="${DATABASE_NAME}/${COLLECTION_NAME}"
readonly RMDATE="$(date --iso -d '4 days ago')"  # TODAY minus X days - too old files
readonly RMWEEK="$(date --iso -d '4 weeks ago')"  # TODAY minus X weeks - too old files
readonly RMDAYS="$(date --iso -d '80 days ago')"  # TODAY minus X days - too old files

# Dump users collection
if [[ "$COLLECTION_NAME" != "others" ]]; then
    mongodump -d ${DATABASE_NAME} -c ${COLLECTION_NAME} -o "${DUMP_PATH}"
else
    mongodump -d ${DATABASE_NAME} --excludeCollection=collection1 --excludeCollection=collection2 --excludeCollection=collection3 -o "${DUMP_PATH}"
fi

# Compress users collection
tar -zcvf ${COMPRESS_PATH} ${DUMP_PATH}

# Remove users collection folder
rm -rf "${DUMP_PATH}"

# Creat collection folder in backup storage
echo -e "mkdir ${PATH_DIR}" | sftp Backup

# Send backup to Backup storage on Hetzner
if sudo rsync --progress -e ssh ${COMPRESS_PATH} Backup:${PATH_DIR} ; then
    rm ${COMPRESS_PATH}
    printf "Done Backup\n"
else
    printf "Error in backup\n"
fi

# For delete old files
echo -e "cd ${PATH_DIR} \n rm ${COLLECTION_NAME}_${RMDATE}*" | sftp Backup # For daily backup
echo -e "cd ${PATH_DIR} \n rm ${COLLECTION_NAME}_${RMWEEK}*" | sftp Backup # For weekly backups
echo -e "cd ${PATH_DIR} \n rm ${COLLECTION_NAME}_${RMDAYS}*" | sftp Backup # For join channel collection
