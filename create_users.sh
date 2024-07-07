#!/bin/bash

logfile="/var/log/user_management.log"
passwordfile="/var/secure/user_passwords.csv"
filename=$1

# create and make password file and log file writable, readable and executable by user
sudo touch $logfile && sudo chmod 777 $logfile 
sudo mkdir -p /var/secure
sudo touch $passwordfile && sudo chmod 777 $passwordfile

# Check if a file is provided as an argument
if [ $# -eq 0 ]; then
    echo "Please provide a filename as an argument $(date)" | tee -a $logfile
    exit 1
fi

# Read the file line by line
while IFS= read -r line; do
    # Extract user (everything before the semicolon)
    user=$(echo "$line" | cut -d';' -f1)
    
    # Extract groups (everything after the semicolon)
    groups=$(echo "$line" | cut -d';' -f2)
  
    # check if the user already exists before creating them
    if id "$user" &>/dev/null; then
        echo "The user $user already exists $(date)" | tee -a $logfile
    else
        # Create user
        password=$(openssl rand -base64 12)
        sudo useradd -m "$user" -p $password
        # echo "$user:$password" | sudo chpasswd
        echo "$user:$password" >> $passwordfile
        # user has been created successfully
        echo "User $user has been created successfully $(date)" | tee -a $logfile

        # split the groups separated by comma and add them to an array
        IFS=',' read -r -a group_array <<< "$groups"

        for group in "${group_array[@]}"; do
            # remove leading and trailing whitespaces
            group=$(echo "$group" | xargs)
            # check if the group exists before adding the user to it
            if ! getent group "$group" &>/dev/null; then
                echo "Creating group $group $(date)" | tee -a $logfile
                sudo groupadd "$group"
            fi
            echo "Modifying user $user to add them to group $group $(date)" | tee -a $logfile
            sudo usermod -a -G "$group" "$user"
            echo "User modifcation complete, successfully added to group $group $(date)" | tee -a $logfile
        done
    fi
done < "$filename"