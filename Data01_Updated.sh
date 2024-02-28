#!/bin/bash
host=$(hostname | cut -f1 -d ".")
mount_point="/mnt/DailyBackup"
LogDir="/opt/script/Logs"
date="$(date +%Y-%m-%d)"
output="/opt/script/Logs/DailyBackup_$date.log"
bckreport="/opt/script/bckreport.txt"
find "$LogDir" -type f -mtime +7 -exec rm {} \;
if df -P | awk '{print $6}' | grep -q "^${mount_point}$"; then
    echo "Mount point ${mount_point} is mounted." >> "$output"
echo "From: $host Data01 <altadcgroup@gmail.com>
To: Kundan Singh <kundans@altametrics.com>
Subject: Backup Success: $host($ipaddr) On $backup_date
Content-Type: text/html
</head><body>
<table align='center' border='1'>
<tr bgcolor=#98FB98><td><b>Backup Job</b></td>
<td align='center'>$host</td>
<td><b>Backup Date</b></td>
<td align='center'>$backup_date</td>
</tr>
<tr bgcolor=#98FB98>
<td><b>Status</b></td>
<td align='center'>Success</td>
<td><b>Time</b></td>
<td align='center'>$(date +"%T")</td>
</tr>
<tr align='center'><td colspan='4'><b>Details</b></td></tr>
<tr align='center'><td><b>Drive</b></td><td><b>Backup Size Before Sync</b></td><td><b>Backup Size After Sync</b></td><td><b>Synced Size(MB)</b></td></tr>" >"$bckreport"
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
echo "<tr align='center'><td><b>KDrive</b></td><td><b>$ksizeb</b></td><td><b>$ksizea</b></td><td><b>$((ksizea - ksizeb))</b></td></tr>" >>"$bckreport"
echo "<tr align='center'><td><b>MDrive</b></td><td><b>$msizeb</b></td><td><b>$msizea</b></td><td><b>$((msizea - msizeb))</b></td></tr>" >>"$bckreport"
echo "<tr align='center'><td><b>RDrive</b></td><td><b>$rsizeb</b></td><td><b>$rsizea</b></td><td><b>$((rsizea - rsizeb))</b></td></tr>" >>"$bckreport"
echo "<tr align='center'><td><b>SDrive</b></td><td><b>$ssizeb</b></td><td><b>$ssizea</b></td><td><b>$((ssizea - ssizeb))</b></td></tr>" >>"$bckreport"
echo "<tr align='center'><td><b>UDrive</b></td><td><b>$usizeb</b></td><td><b>$usizea</b></td><td><b>$((usizea - usizeb))</b></td></tr>" >>"$bckreport"
echo "<tr align='center'><td><b>VDrive</b></td><td><b>$vsizeb</b></td><td><b>$vsizea</b></td><td><b>$((vsizea - vsizeb))</b></td></tr>" >>"$bckreport"
echo "<tr align='center'><td><b>YDrive</b></td><td><b>$ysizeb</b></td><td><b>$ysizea</b></td><td><b>$((ysizea - ysizeb))</b></td></tr>" >>"$bckreport"
    echo "</table> </body> </html>" >>"$bckreport"
    /usr/sbin/sendmail -t <"$bckreport"
else
echo "From: $host Data01 <altadcgroup@gmail.com>
To: Kundan Singh <kundans@altametrics.com>
Subject: Backup Failed: $host($ipaddr) On $backup_date
Content-Type: text/html
</head><body>
<table align='center' border='1'>
<tr bgcolor=#ff6347><td><b>Backup Job</b></td>
<td align='center'>$host</td>
<td><b>Backup Date</b></td>
<td align='center'>$backup_date</td>
</tr>
<tr bgcolor=#ff6347>
<td><b>Status</b></td>
<td align='center'>Failed</td>
<td><b>Time</b></td>
<td align='center'>$(date +"%T")</td>
</tr>
    <tr align='center'><td colspan='4'><b>Details</b></td></tr>" >"$bckreport"
    echo "<tr color='#3333ff'> <td colspan='3'><b>Mounting the TrueNAS Drive failed.</b></td><td><center><span style=\"font-size: xx-larger;\">&#9888;</span></center></td></tr>" >>"$bckreport"
    echo "</table> </body> </html>" >>"$bckreport"
    /usr/sbin/sendmail -t <"$bckreport"
    echo "$(date) Mounting the TrueNAS Drive failed." >>"$output"
    rm -rf "$bckreport"
fi