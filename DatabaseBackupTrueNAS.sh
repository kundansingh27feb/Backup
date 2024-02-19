#!/bin/bash
#Script Owner : Kundan Singh
############# Local Backup Parameter ######################

host=`hostname|cut -f1 -d "."`
ipaddr=`hostname -I | awk '{print $1}'`
# Location to place backups and logfile.
backup_date=`date +%Y-%m-%d`
local_backup_dir="/backup/DB_Backup/$backup_date"
logfile="/opt/script/DailyBackup/TrueNAS/DBlog/pgsql_$backup_date.log"
bckreport="/opt/script/DailyBackup/TrueNAS/report.txt"
mkdir -p $local_backup_dir
mkdir -p /opt/script/DailyBackup/TrueNAS/DBlog/
success_count=0
error_count=0
warning_count=0
error_messages=""
warning_messages=""
############# TrueNAS Backup Parameter ######################
mount_point="/backup/RemoteBackup"
type="AEO"
dbtype="Postgres"
backuptype="DailyBackup"
target_directory="$local_backup_dir"
server_address="10.120.11.241"
share="/mnt/data/dbprod"
day_of_week=$(date +%w)
mkdir -p $mount_point
backup_dir="$mount_point/$type/$dbtype/$host/$backuptype/"
jsonreport="/opt/script/DailyBackup/TrueNAS/report.json"
local_start_time=$(date +%s)
local_ss_time=$(date +"%T")
####################### Global Part ######################
echo "From: $host BackupAgent <produtilalerts@ersaltametrics.com>
To: Kundan Singh<kundans@altametrics.com>, DC Team<dcteam@altametrics.com>, DB Team<dba@altametrics.com>
Subject: Backup Success: $host($ipaddr) On $backup_date
Content-Type: text/html
</head> <body>
<table width='80%' align='center' border='0'> <tr bgcolor=#008000 align=center>
<tr align='center'><td><b>Backup Job</b></td>
<td>$host</td>
<td><b>Backup Date</b></td>
<td>$backup_date</td>
</tr> 
<tr>
<td><b>Status:</b></td>
<td>Success</td>
<td><b>Time</b></td>
<td>$(date +"%T")</td>
</tr>
<tr><td colspan="4">Details</td></tr>
<tr><td>Schema Name</td><td>Time Taken</td><td>Backup Size</td><td>Error/Warning</td></tr>" > $bckreport
rm -rf $jsonreport
################ Taking Local Backup #####################
find /backup/DB_Backup/ -type d -mtime +1 -exec rm -rf {} \;
find /opt/script/DailyBackup/TrueNAS/DBlog/ -type f -mtime +30 -exec rm {} \;
echo "[" >> $jsonreport
databases=`sudo -u postgres psql -l -t | cut -d'|' -f1 | grep -w -v -e "template0" -e "template1" -e "pg_profile" -e  "postgres" |sed -e 's/ //g' -e '/^$/d'`
echo "$(date) Starting backup of databases $backup_date " > $logfile
for i in $databases; do
    ls_time=$(date +"%T")
    backupfile=$local_backup_dir/$i.$backup_date.sql.gz
    echo Dumping $i to $backupfile
    s_time=$(date +%s)
    temp_err_file=$(mktemp)
    sudo -u postgres pg_dump -Z1 -Fc "$i" > "$backupfile" 2> "$temp_err_file"
    dump_exit_code=$?
    e_time=$(date +%s)
    echo "$(date) Backup and Vacuum complete on $backup_date for database: $i " >> $logfile
    t_taken=`echo $((e_time-s_time)) | awk '{printf "%d:%02d:%02d", $1/3600, ($1/60)%60, $1%60}'`
    dumpsize=`ls -ltr --block-size=M $backupfile|awk -F" " '{print $5}'`
    dumpsize_json=$(du -b $backupfile | awk -F" " '{print $1}')

    if [ "$dump_exit_code" -eq 1 ]; then
        warning_count=$((warning_count + 1))
        warning_messages+="Warning for $i: $(cat "$temp_err_file")"$'\n'
        echo "<tr align=center><td>$i</td><td>$t_taken</td><td>$dumpsize</td><td>$warning_count, Warning: $warning_messages</td><tr>" >> $bckreport
    elif
        error_count=$((error_count + 1))
        error_messages+="Error for $i: $(cat "$temp_err_file")"$'\n'
        echo "<tr align=center><td>$i</td><td>$t_taken</td><td>$dumpsize</td><td>$error_count, Warning: $error_messages</td><tr>" >> $bckreport
    else
    echo "<tr align=center><td>$i</td><td>$t_taken</td><td>$dumpsize</td><td>Success</td><tr>" >> $bckreport
    le_time=$(date +"%T")
echo "{
   \"Local_DB_Name\": \"$host-$ipaddr\",
   \"Local_Backup_Start_Time\": \"$ls_time\",
   \"Local_Backup_Schema_Name\": \"$i\",
   \"Local_Backup_Schema_Size\": \"$dumpsize_json\",
   \"Local_Backup_End_Time\": \"$le_time\",
   \"Local_Backup_Date\": \"$backup_date\",
   \"Local_Backup_Time_Taken\": \"$t_taken\"
 }," >> $jsonreport
done

local_end_time=$(date +%s)
local_ee_time=$(date +"%T")
totalTime=`echo $((local_end_time-local_start_time)) | awk '{printf "%d:%02d:%02d", $1/3600, ($1/60)%60, $1%60}'`
totalSize=`du -sh $local_backup_dir | awk -F" " '{print $1}'`
echo "$(date) Done backup of databases " >> $logfile
echo "<tr color='#3333ff' align=center> <td><b>Local Backup Total</b></td> <td><b>$totalTime</b></td> <td><b>$totalSize</b></td><td>Warning: $warning_count, Error: $error_count</td></tr>" >>$bckreport
  totalSizenr=`du -b $local_backup_dir | awk -F" " '{print $1}'`
echo "{
  \"Local_DB_Name\": \"$host-$ipaddr\",
  \"Local_DB_start_time\": \"$local_ss_time\",
  \"Local_DB_BackupStatus\": \"1\",
  \"Local_DB_TotalTimeTaken\": \"$totalTime\",
  \"Local_DB_End_Time\": \"$local_ee_time\",
  \"Local_DB_Backup_Date\": \"$backup_date\",
  \"Local_DB_Total_Size\": \"$totalSizenr\",
  \"Local_DB_TotalTimeTaken\": \"$totalTime\"
}," >> $jsonreport
################ Taking Remote Backup #####################



umount $mount_point >> $logfile
mount -t nfs $server_address:$share $mount_point
if [ $? -eq 0 ]; then
	remote_start_time=$(date +%s)
        remote_s_time=$(date +"%T")
  mkdir -p $backup_dir
  echo "$(date) TrueNAS share mounted successfully at $mount_point." >> $logfile

############################################# If Sunday Then The below Code will execute ######################################################
if [[ "$day_of_week" -eq 0 && -n "$target_directory" ]]; then
    echo "$(date) Today is Sunday. Skipping Daily Backup. Taking weekly backup $target_directory to Remote..." >> "$logfile"
    weekly="$mount_point/$type/$dbtype/$host/WeeklyBackup/"
    mkdir -p "$weekly"
    cp -r "$target_directory" "$weekly"
    week_file=$backup_date
    week_size=$(du -sh "$weekly$backup_date" | awk -F" " '{print $1}')
    echo "Weekly backup copied to NAS Drive" >> "$logfile"

    week_to_delete=$(ls -t "$weekly" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" | tail -n +6)

    if [ -z "$week_to_delete" ]; then
        deleted_week_size="NA"
        deleted_week_dirs="NA (Fewer Than 5 Copies Are Available)"
        directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
    else
        echo "$(date) Deleting Older than 5 weeks backup from WeeklyBackup Directory" >> "$logfile"
        deleted_week_size=$(du -sh "$weekly$week_to_delete" | awk -F" " '{print $1}')
        deleted_week_dirs=$week_to_delete
        directory_week_count=$(find "$weekly" -mindepth 1 -type d | wc -l)
        rm -rf "$weekly$week_to_delete"
        for week in $week_to_delete; do
            rm -rf "$weekly$week"
        done
    fi
    echo "<tr bgcolor=#ff99ff align=center><td colspan="3"><b>Remote Weekly Backup Status</b></td></tr>" >>$bckreport
    echo "<tr color='#3333ff'><td colspan="2"><b>Weekly Backup</b></td> <td>$week_file</td></tr>" >>$bckreport
    echo "<tr color='#3333ff'><td colspan="2">Weekly Backup Size</td> <td>$week_size</td></tr>" >>$bckreport
    echo "<tr bgcolor=#ff99ff align=center><td colspan="3"><b>Remote Weekly Backup Retention</b></td></tr>" >>$bckreport
    echo "<tr color='#3333ff'><td colspan="2">Deleted Weekly Backup</td> <td>$deleted_week_dirs</td></tr>" >>$bckreport
    echo "<tr color='#3333ff'><td colspan="2">Deleted Weekly Backup Size</td> <td>$deleted_week_size</td></tr>" >>$bckreport
    echo "<tr color='#3333ff'><td colspan="2">Available Weekly Copies</td> <td>$directory_week_count</td></tr>" >>$bckreport
else
    week_file="NA($target_directory Not Found At Local)"
    week_size="NA"
fi
echo "</table> </body> </html>" >>$bckreport	
all_end_time=$(date +%s)
allTime=`echo $((all_end_time-local_start_time)) | awk '{printf "%d:%02d:%02d", $1/3600, ($1/60)%60, $1%60}'`
echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"1\",
  \"Remote_DB_start_time\": \"$remote_s_time\",
  \"Remote_DB_End_Time\": \"$remote_e_time\",
  \"Remote_DB_TotalTimeTaken\": \"$remotetotalTime\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$totalSize_json\",
  \"Remote_Local_Total_Time\": \"$allTime\"
}
]" >> $jsonreport

  /usr/sbin/sendmail -t  <$bckreport
  echo "$(date) Done backup of databases " >> $logfile
  umount $mount_point  
  rm -rf $bckreport
find /backup/DB_Backup/ -type d -mtime +1 -exec rm -rf {} \;


  else
echo "From: $host BackupAgent <noreply@notify.altametrics.com>
To: Kundan Singh<kundans@altametrics.com>, DC Team<dcteam@altametrics.com>, DB Team<dba@altametrics.com>
Subject:Backup Failed: $host($ipaddr) on $backup_date To TrueNAS
Content-Type: text/html
</head>
<body>
<table width='80%' align='center' border='1'> <tr bgcolor=#ff99ff align=center>
<td><b>Description</b></td>
<td><b>Backup Status</b></td></tr>" > $bckreport
        echo "$(date) Backup Not Found at Local Srver($ipaddr) $target_directory"  >> $logfile
        echo "<tr color='#3333ff'> <td><b>Backup Not Found at Local Srver($ipaddr) $target_directory.</b></td><td><span style=\"font-size: xx-larger;\">&#9888;</span>Failed</td></tr>" >>$bckreport
        echo "</table> </body> </html>" >> $bckreport
        /usr/sbin/sendmail -t  <$bckreport
        umount $mount_point
	    rm -rf $bckreport
echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"0\",
  \"Remote_DB_start_time\": \"$remote_s_time\",
  \"Remote_DB_End_Time\": \"$remote_e_time\",
  \"Remote_DB_TotalTimeTaken\": \"$remotetotalTime\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$totalSize_json\",
  \"Remote_Local_Total_Time\": \"$allTime\"
}
]" >> $jsonreport
    fi
  
else
echo "From: $host BackupAgent <noreply@notify.altametrics.com>
To: Kundan Singh<kundans@altametrics.com>, DC Team<dcteam@altametrics.com>, DB Team<dba@altametrics.com>
Subject:Backup Failed: $host($ipaddr) on $backup_date To TrueNAS
Content-Type: text/html
</head>
<body>
<table width='80%' align='center' border='1'> <tr bgcolor=#ff99ff align=center>
<td><b>Description</b></td>
<td><b>Backup Status</b></td></tr>" > $bckreport
  echo "<tr color='#3333ff'> <td><b>Mounting the TrueNAS Drive failed.</b></td><td><center><span style=\"font-size: xx-larger;\">&#9888;</span> Failed</center></td></tr>" >>$bckreport
  echo "</table> </body> </html>" >> $bckreport
echo "{
  \"Remote_DB_Name\": \"$host-$ipaddr\",
  \"Remote_DB_BackupStatus\": \"0\",
  \"Remote_DB_start_time\": \"$remote_s_time\",
  \"Remote_DB_End_Time\": \"$remote_e_time\",
  \"Remote_DB_TotalTimeTaken\": \"$remotetotalTime\",
  \"Remote_DB_Backup_Date\": \"$backup_date\",
  \"Remote_DB_Total_Size\": \"$totalSize_json\",
  \"Remote_Local_Total_Time\": \"$allTime\"
}
]" >> $jsonreport
  /usr/sbin/sendmail -t  <$bckreport
  umount $mount_point
  rm -rf $bckreport
fi