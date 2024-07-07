[Link to the article](https://dev.to/charlesgobina/automating-linux-user-and-group-creation-using-a-bash-script-2jmj)

Sysadmins often find themselves caught in an endless loop of user management. With each new hire, they're tasked with the tedious chore of setting up yet another account. The process can quickly become monotonous, so I devised a bash script to automate the user creation process by simply providing a file with the user data as an argument to the script.

Let's begin by creating the name of the script and making it executable
`$ touch create_user.sh && chmod u+x create_user.sh`

With that out of the way, we can proceed to writing the script. Remember! Each bash script begins with `#!/bin/bash` which should be at the top of the file (the first line). It tells our shell to use bash as the interpreter for this script.

### ⚠️ Note
- We assume that the content format of the file passed as an argument looks like the example below.

```
user1; group1,group2,group3
user2; group1
user3; group3,group2
```

### Variable Declaration
Let's go on to define some variables
```
logfile="/var/log/user_management.log"
passwordfile="/var/secure/user_passwords.csv"
filename=$1
```
`logfile` holds the path to the file where we'll be storing our logs (No logs no SysAdmin 😅
`passwordfile` holds the path to the file where we'll be storing the user-password pair
`filename` holds the content of the first argument passed to our script at the level of the terminal. In our case, it is going to be a file containing different users and their respective groups. We'll be reading the contents of this file to create the different users

### Verify that our argument is passed to the script

```
if [ $# -eq 0 ]; then
    echo "Please provide a filename as an argument $(date)" | tee -a $logfile
    exit 1
fi
```
The code snippet above checks if the number of command-line arguments passed to the script is equal to 0. The `$#` variable represents the number of command-line arguments. If it is equal to 0, it means no arguments where passed, and the script exits.

Once an argument (the file) is passed to our script at the level of the terminal, the script then proceeds to do the following;

- Reads the file line by line.
- Extracts the users and groups.
- Generates a random hashed password and creates the user.
- Modify the created user to include their respective groups.

I. **Read file line by line**
```
while IFS= read -r line; do
    ...
done < "$filename"
```
- The code snippet reads the next line from the input file and assigns it to the `line` variable.
- `IFS=` sets the Internal Field Separator (IFS) to nothing, which ensures leading and trailing whitespace characters are preserved in each line.
- The `-r` flag ensures every `\` in the input file is treated literally.

II. **Extracts the users and groups**

```
user=$(echo "$line" | cut -d';' -f1)
groups=$(echo "$line" | cut -d';' -f2)
```
- The code snippet above uses the `cut` command and the `-d` flag to set a delimiter for appropriately extracting a user and a group. The extracted user is stored in the **user** variable while the group(s) are store in the **group** variable

III. **Generate a random hashed password and create the user**

```
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

```
- This code snippet begins by checking if the user we are about to create already exists. If the user exists, we'll get the error _The user [user] already exists_ together with the date today (for better debugging in case  something happens). This error is also written in our log file thanks to `tee -a $logfile`.
- If the user does not exist, the script generates a random fixed hashed password for that user using `openssl rand -base64 12` then stores it in the password variable.
- The password variable is then used in assigning that password to the user once that user is created using the `-p` flag in the `useradd` command
- The `sudo useradd -m "$user" -p $password` creates a user using the `user` variable that was earlier extracted in step II. The `-m` flag created a _home directory_ for that user in `/home` and at the same time, that user is being assigned to a group with the same name as the user's name. 
- Once the operation is successful, the action is logged into our log file using `echo "User $user has been created successfully $(date)" | tee -a $logfile` 

IV. **Modify the created user to include their respective groups**

```
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

```
- This is the last step, where we modify the created user to include all the groups associated with that user. From the **note** above, we can see that some users belong to more than one group, so we have to make sure that is enforced.
- The snippet begins by turning the `group` into an array for easy manipulation.
- `IFS=','` sets the Internal Field Separator (IFS) to a comma. This tells the read command to split the input string into elements based on the comma separator.
- `read` reads input into variables.
- `r` prevents backslashes from being interpreted as escape characters. This ensures that backslashes are treated as literal characters.
- `a group_array` reads the input into an array named group_array.
- `<<< "$groups"` is a here-string that provides the value of the variable $groups as input to the read command. $groups is expected to be a string containing group names separated by commas.
- `for group in "${group_array[@]}"; do:`is a loop that iterates over each element in the `group_array` array.`${group_array[@]}` expands to all elements in the group_array, allowing the for loop to iterate over each group name.
- The individual groups in the array, are then created using the `sudo groupadd "$group"` command. Of course we don't want to create a group that exists already, so `getent group "$group"` checks if the group we are currently looping through exists already. If the group does not exist, it is created, and again the action is logged into our log file
- After creating the different groups, now comes the time to assign these groups to their respective users, so we use the `sudo usermod -a -G "$group" "$user"` command to perform the modification.
- The `-a` flag stands for append and it is used to add the user to the supplementary group(s) specified by the `-G` option without removing them from other groups they may already be members of.
- The `-G` flag accepts the group or groups we want to add, in our case the group(s) are stored in the `$group` variable.
- After this operation is performed, the action is logged in our log file.

You can find the entire source code to this script here. The script was task given by HNG Internship for stage one DevOps participants. HNG Internship is a fast-paced bootcamp for learning digital skills. Signing up is [free](https://hng.tech/internship). If you're looking for something more extra, then consider signing up for [premium](https://hng.tech/premium).
