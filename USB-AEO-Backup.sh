#!/bin/bash
backup_date=`date +%Y-%m-%d`
logfile="/root/alta-scripts/AEO$backup_date.log"
one_day_ago=$(date -v -1d "+%Y-%m-%d")
source_base_dir="/mnt/data/dbprod/AEO/Postgres"
destination_base_dir="/mnt/USB-BACKUP-01/AEO/Postgres"

for source_dir in "$source_base_dir"/*/; do
    if [ -d "$source_dir" ]; then
        variable=$(basename "$source_dir")
        mkdir -p "$destination_base_dir/$variable"
        source_backup_dir="$source_dir/DailyBackup/$one_day_ago"
        destination_backup_dir="$destination_base_dir/$variable/$one_day_ago"
        if [ -d "$source_backup_dir" ]; then
            cp -r "$source_backup_dir" "$destination_backup_dir"
            echo "Copied $source_backup_dir to $destination_backup_dir"
        else
            echo "Directory $source_backup_dir not present"
            echo "Skipping copying to $destination_backup_dir"
        fi
    fi
done