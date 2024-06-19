#!/bin/bash

# Define the NFS mount path
NFS_MOUNT="/mnt/backup"

# Check if NFS mount exists
if [ -d "$NFS_MOUNT" ]; then
    echo "NFS mount exists at $NFS_MOUNT"
    # Create a backup directory with the current timestamp
    BACKUP_DIR="${NFS_MOUNT}/$(date +%Y-%m-%d_%H-%M-%S)"
    mkdir -p "${BACKUP_DIR}"

    # Backup each running Docker container
    for CONTAINER_ID in $(docker ps -q); do
        CONTAINER_NAME=$(docker inspect -f '{{.Name}}' "${CONTAINER_ID}" | sed 's/\///')
        BACKUP_FILE="${BACKUP_DIR}/${CONTAINER_NAME}.tar"

        # Backup the container to a tar file
        echo "Backing up ${CONTAINER_NAME} to ${BACKUP_FILE}"
        docker export "${CONTAINER_ID}" > "${BACKUP_FILE}"
    done

    echo "Docker containers backup completed!"

else
    echo "NFS mount does not exist at $NFS_MOUNT"
    exit 1
fi