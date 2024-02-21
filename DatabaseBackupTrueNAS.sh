#!/bin/bash
#Script Owner: Kundan Singh

############# Local Backup Parameter ######################
l_start_time=$(date +"%T")
backup_start_time=$(date +%s)
host=$(hostname | cut -f1 -d ".")
ipaddr=$(hostname -I | awk '{print $1}')
# Location to place backups and logfile.
backup_date=$(date +%Y-%m-%d)
local_backup_dir="/backup/DB_Backup/$backup_date"
logfile="/opt/script/DailyBackup/TrueNAS/DBlog/pgsql_$backup_date.log"
bckreport="/opt/script/DailyBackup/TrueNAS/report.txt"
mkdir -p "$local_backup_dir"
last_backup_date=$(date --date="yesterday" "+%Y-%m-%d")
mkdir -p /opt/script/DailyBackup/TrueNAS/DBlog/
success_count=0
error_count=0
warning_count=0
error_messages=""
warning_messages=""
local_count=$(find "/backup/DB_Backup/" -mindepth 1 -type d | wc -l)
local_size=$(du -sh "/backup/DB_Backup/" | awk -F" " '{print $1}')
############# TrueNAS Backup Parameter ######################
mount_point="/backup/RemoteBackup"
type="AEO"
dbtype="Postgres"
backuptype="DailyBackup"
target_directory="$local_backup_dir"
server_address="10.120.11.241"
share="/mnt/data/dbprod"
day_of_week=$(date +%w)
mkdir -p "$mount_point"
backup_dir="$mount_point/$type/$dbtype/$host/$backuptype/"
mkdir -p "$backup_dir"
jsonreport="/opt/script/DailyBackup/TrueNAS/report.json"
local_start_time=$(date +%s)
local_ss_time=$(date +"%T")

####################### Global Part ######################
echo "From: $host BackupAgent <produtilalerts@ersaltametrics.com>
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
<tr align='center'><td><b>Schema Name</b></td><td><b>Time Taken</b></td><td><b>Backup Size</b></td><td><b>Error/Warning</b></td></tr>" >"$bckreport"
rm -rf "$jsonreport"
sl_time=$(date +%s)
################ Taking Local Backup #####################
find /backup/DB_Backup/ -type d -mtime +1 -exec rm -rf {} \;
find /opt/script/DailyBackup/TrueNAS/DBlog/ -type f -mtime +30 -exec rm {} \;
databases=$(sudo -u postgres psql -l -t | cut -d'|' -f1 | grep -w -v -e "template0" -e "template1" -e "pg_profile" -e "postgres" | sed -e 's/ //g' -e '/^$/d')
echo "$(date) Starting backup of databases $backup_date " >"$logfile"
for i in $databases; do
    ls_time=$(date +"%T")
    backupfile="$local_backup_dir/$i.$backup_date.sql.gz"
    
    echo Dumping $i to $backupfile
    s_time=$(date +%s)
    temp_err_file=$(mktemp)
    sudo -u postgres pg_dump -Z1 -Fc "$i" >"$backupfile" 2>"$temp_err_file"
    dump_exit_code=$?
    e_time=$(date +%s)
    echo "$(date) Backup and Vacuum complete on $backup_date for database: $i " >>"$logfile"
    t_taken=$(echo $((e_time - s_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}')
    dumpsize=$(ls -ltr --block-size=M "$backupfile" | awk -F" " '{print $5}')
    if [ "$dump_exit_code" -eq 0 ]; then
        echo "<tr align=center><td>$i</td><td>$t_taken</td><td>$dumpsize</td><td>NA</td></tr>" >>"$bckreport"
    elif [ "$dump_exit_code" -eq 1 ]; then
        warning_count=$((warning_count + 1))
        warning_messages+="Warning for $i: $(cat "$temp_err_file")"$'\n'
        echo "<tr align=center><td>$i</td><td>$t_taken</td><td>$dumpsize</td><td>Warning Count: $warning_count, Warning: $warning_messages</td></tr>" >>"$bckreport"
    else
        error_count=$((error_count + 1))
        error_messages+="Error for $i: $(cat "$temp_err_file")"$'\n'
        echo "<tr align=center><td>$i</td><td>$t_taken</td><td>$dumpsize</td><td>Error Count: $error_count, Error: $error_messages</td></tr>" >>"$bckreport"
    fi
done
totalSize=$(du -sh "$local_backup_dir" | awk -F" " '{print $1}')
el_time=$(date +%s)
totalTime=`echo $((el_time - sl_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'`
echo "$(date) Done backup of databases " >>"$logfile"
echo "<tr><td><b> Local Backup Total </b></td> <td align=center> <b> $totalTime </b></td><td align=center><b> $totalSize </b></td><td><b> Warning: $warning_count, Error: $error_count </b></td></tr>" >>"$bckreport"

################ Taking Remote Backup #####################
umount "$mount_point" >>"$logfile"
mount -t nfs "$server_address:$share" "$mount_point"
if [ $? -eq 0 ]; then
    mkdir -p "$backup_dir"
    echo "$(date) TrueNAS share mounted successfully at $mount_point." >>"$logfile"
    weekly="$mount_point/$type/$dbtype/$host/WeeklyBackup/"
    mkdir -p "$weekly"

    if [ "$day_of_week" -eq 0 ]; then
        last_day_size=$(du -sh "$backup_dir$last_backup_date" | awk -F" " '{print $1}')
        last_day_size_numeric=$(echo "$last_day_size" | sed 's/[^0-9]*//g')
    elif [ "$day_of_week" -eq 1 ]; then
        last_day_size=$(du -sh "$weekly$last_backup_date" | awk -F" " '{print $1}')
        last_day_size_numeric=$(echo "$last_day_size" | sed 's/[^0-9]*//g')
    else
        last_day_size=$(du -sh "$backup_dir$last_backup_date" | awk -F" " '{print $1}')
        last_day_size_numeric=$(echo "$last_day_size" | sed 's/[^0-9]*//g')
    fi

    ############################################# If Sunday Then The below Code will execute ######################################################
    if [ "$day_of_week" -eq 0 ]; then
        echo "$(date) Today is Sunday. Skipping Daily Backup. Taking weekly backup $target_directory to Remote..." >>"$logfile"
        rsync -av "$target_directory" "$weekly"
        week_file=$backup_date
        week_size=$(du -sh "$weekly$backup_date" | awk -F" " '{print $1}')
        today_size_numeric=$(echo "$week_size" | sed 's/[^0-9]*//g')
        echo "Weekly backup copied to NAS Drive" >>"$logfile"
        week_to_delete=$(ls -t "$weekly" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" | tail -n +6)
        if [ -z "$week_to_delete" ]; then
            deleted_week_size="NA"
            deleted_week_dirs="NA (Fewer Than 5 Copies Are Available)"
            directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
            directory_daily_count=$(find "$backup_dir" -mindepth 1 -type d | wc -l)
            remote_week_size=$(du -sh "$weekly" | awk -F" " '{print $1}')
            remote_daily_size=$(du -sh "$backup_dir" | awk -F" " '{print $1}')
        else
            echo "$(date) Deleting Older than 5 weeks backup from WeeklyBackup Directory" >>"$logfile"
            deleted_week_size=$(du -sh "$weekly$week_to_delete" | awk -F" " '{print $1}')
            deleted_week_dirs=$week_to_delete
            rm -rf "$weekly$week_to_delete"
            for week in $week_to_delete; do
                rm -rf "$weekly$week"
            done
            directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
            directory_daily_count=$(find "$backup_dir" -mindepth 1 -type d | wc -l)
            remote_week_size=$(du -sh "$weekly" | awk -F" " '{print $1}')
            remote_daily_size=$(du -sh "$backup_dir" | awk -F" " '{print $1}')
        fi
        growth=$((today_size_numeric - last_day_size_numeric))
        disk_usage=$(df -h "$mount_point")
        total_disk_size=$(echo "$disk_usage" | awk 'NR==2 {print $2}')
        available_size=$(echo "$disk_usage" | awk 'NR==2 {print $4}')
        echo "<tr align=center><td colspan='4'><b>Retention Policy</b></td></tr>" >>"$bckreport"
        echo "<tr><td><b>Local Backup Count</b></td> <td align=center>$local_count</td><td><b>Local Backup Size</b></td> <td align=center>$local_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Remote Count(Daily)</b></td> <td align=center>$directory_daily_count</td><td><b>Local Backup Size</b></td> <td align=center>$remote_daily_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Remote Count(Weekly)</b></td> <td align=center>$directory_week_count</td><td><b>Local Backup Size</b></td> <td align=center>$remote_week_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Remote Disk Size</b></td> <td align=center>$total_disk_size</td><td><b>Remote Available Size</b></td> <td align=center>$available_size</td></tr>" >>"$bckreport"
        
        backup_end_time=$(date +%s)
        l_end_time=$(date +"%T")
        totalTimeTake=`echo $((backup_end_time - backup_start_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'`
        echo "<tr align=center><td colspan='4'><b>Summary</b></td></tr>" >>"$bckreport"
        echo "<tr><td><b>Start Time</b></td> <td align=center>$l_start_time</td><td><b>Previous Backup Size</b></td> <td align=center>$last_day_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>End Time</b></td> <td align=center>$l_end_time</td><td><b>Current Backup Size</b></td> <td align=center>$week_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Duration</b></td> <td align=center>$totalTimeTake</td><td><b>Database Growth</b></td> <td align=center>$growth G</td></tr>" >>"$bckreport"
        echo "</table> </body> </html>" >>"$bckreport"
        /usr/sbin/sendmail -t <"$bckreport"
        echo "$(date) Done backup of databases " >>"$logfile"
        umount "$mount_point"
        rm -rf "$bckreport"
        find /backup/DB_Backup/ -type d -mtime +1 -exec rm -rf {} \;
    elif [ "$day_of_week" -ne 0 ]; then
        cp -r "$target_directory" "$backup_dir"
        daily_size=$(du -sh "$backup_dir$backup_date" | awk -F" " '{print $1}')
        today_size_numeric=$(echo "$daily_size" | sed 's/[^0-9]*//g')
        echo "Daily backup copied to NAS Drive" >>"$logfile"
        daily_to_delete=$(ls -t "$backup_dir" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" | tail -n +9)
        if [ -z "$daily_to_delete" ]; then
            deleted_daily_size="NA"
            deleted_daily_dirs="NA (Fewer Than 5 Copies Are Available)"
            directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
            directory_daily_count=$(find "$backup_dir" -mindepth 1 -type d | wc -l)
            remote_week_size=$(du -sh "$weekly" | awk -F" " '{print $1}')
            remote_daily_size=$(du -sh "$backup_dir" | awk -F" " '{print $1}')
        else
            echo "$(date) Deleting Older than 8 day backup from dailyBackup Directory" >>"$logfile"
            deleted_daily_size=$(du -sh "$weekly$week_to_delete" | awk -F" " '{print $1}')
            deleted_daily_dirs=$daily_to_delete
            rm -rf "$backup_dir$daily_to_delete"
            for daily in $daily_to_delete; do
                rm -rf "$backup_dir$daily"
            done
            directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
            directory_daily_count=$(find "$backup_dir" -mindepth 1 -type d | wc -l)
            remote_week_size=$(du -sh "$weekly" | awk -F" " '{print $1}')
            remote_daily_size=$(du -sh "$backup_dir" | awk -F" " '{print $1}')
        fi
        growth=$((today_size_numeric - last_day_size_numeric))
        disk_usage=$(df -h "$mount_point")
        total_disk_size=$(echo "$disk_usage" | awk 'NR==2 {print $2}')
        available_size=$(echo "$disk_usage" | awk 'NR==2 {print $4}')
        echo "<tr align=center><td colspan='4'><b>Retention Policy</b></td></tr>" >>"$bckreport"
        echo "<tr><td><b>Local Backup Count</b></td> <td align=center>$local_count</td><td><b>Local Backup Size</b></td> <td align=center>$local_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Remote Count(Daily)</b></td> <td align=center>$directory_daily_count</td><td><b>Local Backup Size</b></td> <td align=center>$remote_daily_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Remote Count(Weekly)</b></td> <td align=center>$directory_week_count</td><td><b>Local Backup Size</b></td> <td align=center>$remote_week_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>NAS Disk Size</b></td> <td align=center>$total_disk_size</td><td><b>NAS Available Disk</b></td> <td align=center>$available_size</td></tr>" >>"$bckreport"
        
        backup_end_time=$(date +%s)
        l_end_time=$(date +"%T")
        totalTimeTake=`echo $((backup_end_time - backup_start_time)) | awk '{printf "%d:%02d:%02d", $1 / 3600, ($1 / 60) % 60, $1 % 60}'`
        echo "<tr align=center><td colspan='4'><b>Summary</b></td></tr>" >>"$bckreport"
        echo "<tr><td><b>Start Time</b></td> <td align=center>$l_start_time</td><td><b>Previous Backup Size</b></td> <td align=center>$last_day_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>End Time</b></td> <td align=center>$l_end_time</td><td><b>Current Backup Size</b></td> <td align=center>$daily_size</td></tr>" >>"$bckreport"
        echo "<tr><td><b>Duration</b></td> <td align=center>$totalTimeTake</td><td><b>Database Growth</b></td> <td align=center>$growth G</td></tr>" >>"$bckreport"
        echo "</table> </body> </html>" >>"$bckreport"
        /usr/sbin/sendmail -t <"$bckreport"
        echo "$(date) Done backup of databases " >>"$logfile"
        umount "$mount_point"
        rm -rf "$bckreport"
        find /backup/DB_Backup/ -type d -mtime +1 -exec rm -rf {} \;
    else
echo "From: $host BackupAgent <produtilalerts@ersaltametrics.com>
To: Kundan Singh <kundans@altametrics.com>
Subject: Backup Success: $host($ipaddr) On $backup_date
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
    echo "$(date) Backup Not Found at Local Server($ipaddr) $target_directory" >>"$logfile"
    echo "<tr color='#3333ff'> <td><b>Backup Not Found at Local Server($ipaddr) $target_directory.</b></td><td><span style=\"font-size: xx-larger;\">&#9888;</span>Failed</td></tr>" >>"$bckreport"
    echo "</table> </body> </html>" >>"$bckreport"
    /usr/sbin/sendmail -t <"$bckreport"
    umount "$mount_point"
    rm -rf "$bckreport"
    fi
else
echo "From: $host BackupAgent <produtilalerts@ersaltametrics.com>
To: Kundan Singh <kundans@altametrics.com>
Subject: Backup Success: $host($ipaddr) On $backup_date
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
    echo "<tr color='#3333ff'> <td><b>Mounting the TrueNAS Drive failed.</b></td><td><center><span style=\"font-size: xx-larger;\">&#9888;</span> Failed</center></td></tr>" >>"$bckreport"
    echo "</table> </body> </html>" >>"$bckreport"
    /usr/sbin/sendmail -t <"$bckreport"
    echo "$(date) Mounting the TrueNAS Drive failed." >>"$logfile"
    rm -rf "$bckreport"
fi

exit 0
