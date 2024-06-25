#!/bin/bash
#Script Owner: Kundan Singh

############# Oracle Backup Process ######################
host=$(hostname | cut -f1 -d ".")

dates=""
for i in {0..5}; do
    dates+=$(date -d "+$i day" +"%d_%m_%Y")" "
done
dates=$(echo $dates | sed 's/ $//')
backup_date=$(date +%Y-%m-%d)
local_backup_dir="/redo/stgodb_backupdir/DB_$dates"
logfile="/opt/script/DailyBackup/TrueNAS/DBlog/ora_$backup_date.log"
mkdir -p /opt/script/DailyBackup/TrueNAS/DBlog/
mount_point="/backup/RemoteBackup"
type="AEO"
dbtype="Oracle"
backuptype="DailyBackup"
target_directory="$local_backup_dir"
server_address="10.220.11.251"
share="/mnt/data/dbstg"
mkdir -p "$mount_point"
backup_dir="$mount_point/$type/$dbtype/$host/$backuptype/"
mkdir -p "$backup_dir"
bckreport="/opt/script/DailyBackup/TrueNAS/report.txt"
find /redo/stgodb_backupdir/ -type d -mtime +1 -exec rm -rf {} \;
find /opt/script/DailyBackup/TrueNAS/DBlog/ -type f -mtime +30 -exec rm {} \;
echo "$(date) Starting backup of databases $backup_date " >"$logfile"
umount "$mount_point" >>"$logfile"
mount -t nfs "$server_address:$share" "$mount_point"
if [ $? -eq 0 ]; then
    mkdir -p "$backup_dir"
    echo "$(date) TrueNAS share mounted successfully at $mount_point." >>"$logfile"
    cp -avr $local_backup_dir $backup_dir  >>"$logfile"
    find /redo/stgodb_backupdir/ -type d -mtime +7 -exec rm -rf {} \;
else
echo "Mounting the TrueNAS Drive failed." >>"$logfile"
fi
exit 0