#!/bin/bash
mount_point="/mnt/DailyBackup"
LogDir="/opt/script/Logs"
date="$(date +%Y-%m-%d)"
output="/opt/script/Logs/DailyBackup_$date.log"
recipient="dcteam@altametrics.com"
subject="Data01(192.168.160.145) Backup Status"
find "$LogDir" -type f -mtime +7 -exec rm {} \;

if df -P | awk '{print $6}' | grep -q "^${mount_point}$"; then
    echo "Mount point ${mount_point} is mounted." >> "$output"
    start_time=$(date +%Y-%m-%d\ %H:%M:%S)
    ksizeb=$(du -sm /mnt/DailyBackup/KDrive | cut -f1)
    msizeb=$(du -sm /mnt/DailyBackup/MDrive | cut -f1)
    rsizeb=$(du -sm /mnt/DailyBackup/RDrive | cut -f1)
    ssizeb=$(du -sm /mnt/DailyBackup/SDrive | cut -f1)
    usizeb=$(du -sm /mnt/DailyBackup/UDrive | cut -f1)
    vsizeb=$(du -sm /mnt/DailyBackup/VDrive | cut -f1)
    ysizeb=$(du -sm /mnt/DailyBackup/YDrive | cut -f1)
    echo "Backup started at: $start_time" >> "$output"

    rsync_with_notification() {
        local source="$1"
        local destination="$2"
        local log_file="$3"

        echo "Starting rsync from $source to $destination"

        rsync -avrp "$source" "$destination" >> "$log_file"
        exit_status=$?
        if [ $exit_status -eq 0 ]; then
            echo "rsync from $source to $destination completed successfully."
        else
            echo "rsync from $source to $destination failed."
            echo "Error occurred during rsync from $source to $destination." | mail -s "$subject" "$recipient"
            exit $exit_status
        fi
    }

    rsync_with_notification "/opt/DATA/KDrive/" "/mnt/DailyBackup/KDrive/" "$output"
    rsync_with_notification "/opt/DATA/MDrive/" "/mnt/DailyBackup/MDrive/" "$output"
    rsync_with_notification "/opt/DATA/RDrive/" "/mnt/DailyBackup/RDrive/" "$output"
    rsync_with_notification "/opt/DATA/SDrive/" "/mnt/DailyBackup/SDrive/" "$output"
    rsync_with_notification "/opt/DATA/UDrive/" "/mnt/DailyBackup/UDrive/" "$output"
    rsync_with_notification "/opt/DATA/VDrive/" "/mnt/DailyBackup/VDrive/" "$output"
    rsync_with_notification "/opt/DATA/YDrive/" "/mnt/DailyBackup/YDrive/" "$output"

    end_time=$(date +%Y-%m-%d\ %H:%M:%S)

    start_time=$(date +%Y-%m-%d\ %H:%M:%S)
    ksizea=$(du -sm /mnt/DailyBackup/KDrive | cut -f1)
    msizea=$(du -sm /mnt/DailyBackup/MDrive | cut -f1)
    rsizea=$(du -sm /mnt/DailyBackup/RDrive | cut -f1)
    ssizea=$(du -sm /mnt/DailyBackup/SDrive | cut -f1)
    usizea=$(du -sm /mnt/DailyBackup/UDrive | cut -f1)
    vsizea=$(du -sm /mnt/DailyBackup/VDrive | cut -f1)
    ysizea=$(du -sm /mnt/DailyBackup/YDrive | cut -f1)

    echo "Script ended at: $end_time" >> "$output"


    # Table headers
    table_headers="Drive        Backup Size Before Sync    Backup Size After Sync      Synced Size(MB)"
       # Table rows
    row1="------------------------------------------------------------------------------------"
    row2=$(printf "%-22s %-22s %-28s %-10s\n" "KDrive"               "$ksizeb"                    "$ksizea"  $((ksizea - ksizeb)))
    row3=$(printf "%-22s %-22s %-28s %-10s\n" "MDrive"               "$msizeb"                    "$msizea"  $((msizea - msizeb)))
    row4=$(printf "%-22s %-22s %-28s %-10s\n" "RDrive"               "$rsizeb"                    "$rsizea"  $((rsizea - rsizeb)))
    row5=$(printf "%-22s %-22s %-28s %-10s\n" "SDrive"               "$ssizeb"                    "$ssizea"  $((ssizea - ssizeb)))
    row6=$(printf "%-22s %-22s %-28s %-10s\n" "UDrive"               "$usizeb"                    "$usizea"  $((usizea - usizeb)))
    row7=$(printf "%-22s %-22s %-28s %-10s\n" "VDrive"               "$vsizeb"                    "$vsizea"  $((vsizea - vsizeb)))
    row8=$(printf "%-22s %-22s %-28s %-10s\n" "YDrive"               "$ysizeb"                    "$ysizea"  $((ysizea - ysizeb)))

    # Construct the message with the table
    table_message="Backup completed successfully. Below is the detailed discription of backup. The Backup Process started at $start_time And ended at $end_time.

$table_headers
$row1
$row2
$row3
$row4
$row5
$row6
$row7
$row8"

    echo -e "$table_message" | mail -s "$subject" "$recipient"
else
    echo "Mount point ${mount_point} is not mounted." >> "$output"
    echo "Skipping Backup!! Mount the above disk and run the script again." >> "$output"
    echo "Backup failed. Mount point ${mount_point} is not mounted." | mail -s "$subject" "$recipient"
fi 