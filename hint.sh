databases=$(sudo -u postgres psql -l -t | cut -d'|' -f1 | grep -w -v -e "template0" -e "template1" -e "pg_profile" -e "postgres" | sed -e 's/ //g' -e '/^$/d')
echo "$(date) Starting backup of databases $backup_date" > "$logfile"
for i in $databases; do
    ls_time=$(date +"%T")
    backupfile="$local_backup_dir/$i.$backup_date.sql.gz"
    echo "Dumping $i to $backupfile"
    s_time=$(date +%s)

    # Redirect stderr to a temporary file
    temp_err_file=$(mktemp)
    sudo -u postgres pg_dump -Z1 -Fc "$i" > "$backupfile" 2> "$temp_err_file"
    dump_exit_code=$?
    e_time=$(date +%s)

    # Check the exit code and update counters and messages
    if [ "$dump_exit_code" -eq 0 ]; then
        success_count=$((success_count + 1))
    elif [ "$dump_exit_code" -eq 1 ]; then
        warning_count=$((warning_count + 1))
        warning_messages+="Warning for $i: $(cat "$temp_err_file")"$'\n'
    else
        error_count=$((error_count + 1))
        error_messages+="Error for $i: $(cat "$temp_err_file")"$'\n'
    fi

    # Remove temporary error file
    rm -f "$temp_err_file"
done

# Print summary
echo "Backup summary:"
echo "Success count: $success_count"
echo "Warning count: $warning_count"
echo "Error count: $error_count"

# Print error and warning messages
if [ "$warning_count" -gt 0 ]; then
    echo -e "Warning messages:\n$warning_messages"
fi

if [ "$error_count" -gt 0 ]; then
    echo -e "Error messages:\n$error_messages"
fi