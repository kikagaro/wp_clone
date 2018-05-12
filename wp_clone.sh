#!/bin/bash

#script used to clone Wordpress Sites:
version="1.1.0"
valid_version_format="^[0-9]+\.[0-9]+\.[0-9]+$"

#Start time for when Script was first ran:
starttime=$(date)

#Varibles for source and target directory of the clone:
wpsource=${1}
wptarget=${2}

#Checking if source and target variables were giveni, prompt if not:
if [[ -z ${1} || -z ${2} ]]
then
  echo "Source and/or Target directory not provided. Please provide them now."
  echo -e "Source Directory:"
  read wpsource
  echo -e "Target Directory:"
  read wptarget
fi

if [[ ! -z ${1} || ! -z ${2} ]]
then
  echo -e "Are the following Source and Target directories correct? [y/n]"
  echo -e "Source:\n ${wpsource}\nTarget:\n ${wptarget}\n"
  read sourcetarget
  while [[ ${sourcetarget} != @(y|Y|yes|Yes|YES|n|N|no|No|NO) ]]
  do
    echo -e "Please provide one of the following answers:\nY, y, Yes, yes, N, n, No, no"
    read sourcetarget
  done
  if [[ ${sourcetarget} =~ ^(n|N|no|No|NO)$ ]]
  then
    echo -e "Exiting Script"
    exit 1
  fi
fi

#Other Variables and temp directory for clone:
date=$(date +'%Y%m%d')
wpconfig=${wpsource}/wp-config.php
newwpconfig=${wptarget}/wp-config.php

directory=/home/temp/wpclone.${date}
log=${directory}/wpclone_log
rsynclog=${directory}/rsync_log
sqldumpdir=${directory}/sqldump
backupwpconfig=${directory}/wp-config.php

#Diskspace Check:
echo -e "Checking diskusage on source and diskspace on target."

#Source:
echo -e "\nSource Usage:"
sfsu=$(du -h --max-depth=0 ${wpsource} | tail -1 | awk '{print $1}')
echo -e "Files:\n${sfsu}	${wpsource}"
sdcdbn=$(grep -e ^"define...\?DB\_NAME" ${wpconfig}|cut -d\' -f4)
sdbu=$(du -h --max-depth=0 /var/lib/mysql/${sdcdbn} | tail -1 | awk '{print $1}')
echo -e "Database:\n${sdbu}	${sdcdbn}"

#Target:
echo -e "\nTarget Space:"
targetdir=$(echo ${wptarget}| sed 's/\// /g')
count="0"
total="1"
for each in ${targetdir}
  do
  count=$(echo "${count}+1"| bc)
done

df -h ${wptarget} 2> /dev/null
dfc=$?

while [[ ${dfc} = "1" ]]
do
  while [[ ${total} != ${count} ]]
  do
    dir=$(echo $ntardir| awk -v var=${total} '{print "/"$var}')
    ndir=$(echo "${ndir}${dir}")
    total=$(echo "${total}+1"| bc)
  done
  df -h ${ndir}
  dfc=$?
done

echo -e "Press Enter to continue."
read waiting

#Script updating:
filehost="https://git.liquidweb.com"
echo -e "Local script version: ${version}"
filepath="/pwortinger/wordpressclonescript/raw/master/wp_clone.sh"
if host ${filehost}
then
  server_version=$(curl -s ${filehost}${filepath} |grep ^version= | sed -e 's/^version="\([0-9.]*\)"/\1/')
  echo -e "Detected server version: ${server_version}"
  if [ ! $version = `echo -e "${version}\n${server_version}" | sort -rV | head -n1` ]
  then
    echo -e "Local version: ${version} is less than server version: ${server_version}, downloading new version to /root/wpclone.sh and executing."
    wget -q -O /root/wpclone.sh ${filehost}${filepath}
    sleep 1
    exec bash /root/wpclone.sh ${wpsource} ${wptarget}
  else
    echo ${version} is equal or greater than server ${server_version}
  fi
else
  echo -e "Couldn't resolve host ${filehost} to check for updates."
fi

#Check if backup/directory exist, if not create it:
  if [[ ! -d ${directory} ]]
  then
    mkdir -p ${directory}
  fi
  if [[ ! -a ${log} ]]
  then
    touch ${log}
  fi
  if [[ ! -a ${rsynclog} ]]
  then
    touch ${rsynclog}
  fi
  if [[ ! -a ${sqldumpdir} ]]
  then
    mkdir -p ${sqldumpdir}
  fi

#Main Script function:
function main {

#User and Case information:
  echo -e "Admin running this script:"
  read billing
  echo -e ${billing} >> ${log}
  echo -e "Case number for the Wordpress Clone:"
  read sfcase
  echo -e ${sfcase} >> ${log}

#Initial Logging for Clone:
  echo -e "Varibles:" >> ${log}
  echo -e "\nAdmin: ${billing}" >> ${log}
  echo -e "Case Number: ${sfcase}" >> ${log}
  echo -e "Date: ${date}" >> ${log}
  echo -e "Source: ${wpsource}" >> ${log}
  echo -e "Target: ${wptarget}" >> ${log}
  echo -e "Temp Directory: ${directory}" >> ${log}
  echo -e "Clone log: ${log}" >> ${log}

#Check to proceed:
  echo -e "\nPress Enter to proceed or quit out now."
  read waiting

#Cpanel User Variables:
  sourceuser=$(echo ${wpsource} |cut -d/ -f3)
  targetuser=$(echo ${wptarget} |cut -d/ -f3)

#Target Checks:

#Checking if Target user Exist and offering to create it:
  if [[ ${sourceuser} != ${targetuser} ]]
  then
    ls /var/cpanel/users/ | grep "^${targetuser}$"
    cpuc=$?
    if [[ ${cpuc} = "0" ]]
    then
      echo -e "Target cPanel Account exist.\n"
    else
      echo -e "Target cPanel Account does not exist."
      echo -e "Do you wish to create it? [y/n]"
      read createaccnt
      echo -e "${createaccnt}" >> ${log}
      while [[ ${createaccnt} != @(y|Y|yes|Yes|YES|n|N|no|No|NO) ]]
      do
        echo -e "Please provide one of the following answers:\nY, y, Yes, yes, N, n, No, no"
        read createaccnt
        echo -e "${createaccnt}" >> ${log}
      done
      if [[ ${createaccnt} =~ ^(y|Y|yes|Yes)$ ]]
      then
        echo -e "Please provide a domain for the new account."
        read domain
        echo -e "${domain}" >> ${log}
        echo -e "Password will be randomly generated.\n"
        echo -e "Is this infomration correct? [y/n]"
        echo -e "Target Username:\n${targetuser}\nTarget Domain:\n${domain}\n"
        read createaccnt
        echo -e ${createaccnt} >> ${log}
        while [[ ${createaccnt} != @(y|Y|yes|Yes|YES|n|N|no|No|NO) ]]
        do
          echo -e "Please provide one of the following answers:\nY, y, Yes, yes, N, n, No, no"
          read createaccnt
          echo -e "${createaccnt}" >> ${log}
        done
        if [[ ${createaccnt} =~ ^(y|Y|yes|Yes)$ ]]
        then
          cppass=$(date +%s | sha256sum | base64 | head -c 32)
          echo -e "#####"
          whmapi1 createacct username=${targetuser} domain=${domain} password=${cppass}| tail -3
          echo -e "#####"
          echo -e "If this did not complete successfully then quit out and try again."
          echo -e "\nPress Enter to continue."
          read waiting
        else
          echo -e "Not creating user, exiting script."
          exit 3
        fi
#Checking if Account exist again:
        ls /var/cpanel/users/ | grep "^${targetuser}$"
        cpuc=$?
        if [[ ${cpuc} = 0 ]]
        then
          echo -e "User Created"
        else
          echo -e "User was not created, exiting"
          exit 4
        fi
      fi
    fi
  fi

#Checking for the Target directory:
  echo -e "\nChecking if target directory exist:"
  if [[ ! -d ${wptarget} ]]
  then
    echo -e "\nThe target directory does not exist. Do you want to create it? [y/n]"
    read createdocroot
    echo -e "${createdocroot}" >> ${log}
    while [[ ${createdocroot} != @(y|Y|yes|Yes|n|N|no|No) ]]
    do
      echo -e "Please provide one of the following answers:\nY, y, Yes, yes, N, n, No, no"
      read createdocroot
      echo -e "${createdocroot}" >> ${log}
    done
      if [[ $createdocroot =~ ^(y|Y|yes|Yes)$ ]]
      then
        mkdir -p ${wptarget}
        echo -e "\n${wptarget} created."
        chown ${targetuser}. ${wptarget}
      else
        echo "Target directory not created, exiting script"
        exit 5 
      fi
  else
    echo -e "\nTarget directory exist"
  fi

#Checking if the Target Directory already has data:
  datatest=$(ls -1 ${wptarget} |grep -v -e ^"./\|../"$ |grep -v "cgi-bin")
  if [[ -n ${datatest} ]]
  then
    echo -e "\nData exist at the target directory, remove or move data then run again\nExiting script\n"
    exit 6
  fi

#Checking if wp-config.php exist in source path:
  if [[ ! -f ${wpconfig} ]]
  then
    echo -e "\nThe wpconfig does not exist in source path\n\nEnding script"
    exit 7
  else
    echo -e "\npath to wp-config.php:\n${wpconfig}" >> ${log}
    cp -a ${wpconfig} ${backupwpconfig}
  fi

#Rsync of data from source to target:
  targetdir=$(basename ${wptarget})
  echo -e "\nRsyncing content from source to target\n\nSource: ${wpsource}\nTarget: ${wptarget}\nRsync Log: ${rsynclog}" |tee -a ${rsynclog}
  rsync -avPH --exclude "${targetdir}" ${wpsource}/ ${wptarget}/ >> ${rsynclog}
  echo -e "\nRsync is complete" |tee -a ${rsynclog}

#If user is different offering to correct permissions:
  if [[ ${sourceuser} = ${targetuser} ]]
  then
    echo "Users match, Ownerships do not need to be udpated."
  else
    echo "Users do not match, do you want to run a fix perm? [y/n]"
    read fixperm
    echo -e "${fixperm}" >> ${log}
    while [[ ${fixperm} != @(y|Y|yes|Yes|n|N|no|No) ]]
    do
      echo -e "Please provide one of the following answers:\nY, y, Yes, yes, N, n, No, no"
      read fixperm
      echo -e "${fixperm}" >> ${log}
    done
    if [[ ${fixperm} =~ ^(y|Y|yes|Yes)$ ]]
    then
      targethomedir=$(egrep ^${targetuser}: /etc/passwd | cut -d: -f6)
      echo "Setting ownership for user ${targetuser}"
      chown -R ${targetuser}. ${targethomedir}
      chmod 711 ${targethomedir}
      chown ${targetuser}:nobody ${targethomedir}/public_html ${targethomedir}/.htpasswds
      chown ${targetuser}:mail ${targethomedir}/etc ${targethomedir}/etc/*/shadow ${targethomedir}/etc/*/passwd
      echo "Setting permissions for user ${targetuser}"
      find ${targethomedir} -type f ! -path "*/mail/*" -exec chmod 644 {} \;
      find ${targethomedir} -type d ! -path "*/mail/*" -exec chmod 755 {} \;
      chmod 750 ${targethomedir}/public_html
      find ${targethomedir} -type d -name "cgi-bin" -exec chmod 755 {} \;
      find ${targethomedir} -type f \( -name "*.pl" -o -name "*.perl" -o -name "*.cgi" \) -exec chmod 755 {} \;
      echo -e "Perms have been corrected"
    else
      echo -e "Perms have not been corrected"
    fi
  fi

#Checking for define crap in target wpconfig
  dehome=$(grep -e ^"define('WP_HOME'" ${newwpconfig})
  dehomec=$?
  desiur=$(grep -e ^"define('WP_SITEURL'" ${newwpconfig})
  desiurc=$?
  echo -e ""
  if [[ ${dehomec} = 0 ]]
  then
    echo -e 'Commenting out WP_HOME in target wpconfig'
    sed -i "s|$dehome|#${dehome}|g" ${newwpconfig}
  fi
  if [[ ${desiurc} = 0 ]]
  then
    echo -e 'Commenting out WP_SITEURL in target wpconfig'
    sed -i "s|${desiur}|#${desiur}|g" ${newwpconfig}
  fi
  echo -e ""

#Gathering DB info from target location:
  dbname=$(grep -e ^"define...\?DB\_NAME" ${newwpconfig}|cut -d\' -f4)
  dbuser=$(grep -e ^"define...\?DB\_USER" ${newwpconfig}|cut -d\' -f4)
  dbpass=$(grep -e ^"define...\?DB\_PASSWORD" ${newwpconfig}|cut -d\' -f4)
  dbprefix=$(grep -e ^"\$table\_prefix" ${newwpconfig}|cut -d\' -f2)
  echo -e "\nDB_Name: ${dbname}\nDB_User: ${dbuser}\nDB_pass: ${dbpass}\nDB_Prefix: ${dbprefix}"

#Creating dump of source DB:
  echo -e "\nCreating Dump of source Databases: ${dbname}"
  mkdir -p ${sqldumpdir}
  mysqldump ${dbname} > ${sqldumpdir}/${dbname}.sql
  if [[ -f ${sqldumpdir}/${dbname}.sql ]]
  then
    echo -e "\nMySQL Dump created: ${sqldumpdir}/${dbname}.sql"
  else
    echo -e "\nMySQL Dump not created"
  fi

#Create new database and upload source dump:
  dbnameprefix=$(echo ${dbname} |cut -d_ -f2)
  if [[ ${sourceuser} = ${targetuser} ]]
  then
    echo -e "\nSince this is the same cPanel user, please enter a new Database Name\nExmaple: USER_DBNAME\nNote: Database name must be 16 characters or less."
    read newdb
    echo -e "${newdb}" >> ${log}
    echo -e "Creating ${newdb}"
    mysqladmin create ${newdb}
    echo -e "created ${newdb}\nUploading source database to it"
    mysql ${newdb} < ${sqldumpdir}/${dbname}.sql
    echo -e "Done"
    echo -e "${newdb}" >> ${directory}/newdb.txt
  else
#checking if Target DB Exist:
    mysql -e "show databases\G"| grep "^Database"| awk '{print $2}'| grep "^${targetuser:0:8}_${dbnameprefix:0:7}$"
    dbcheck=$?
    if [[ $? = "0" ]]
    then 
      echo -e "Creating the database ${targetuser:0:8}_${dbnameprefix:0:7}"
      mysqladmin create ${targetuser:0:8}_${dbnameprefix:0:7}
      echo -e "Created ${targetuser:0:8}_${dbnameprefix:0:7}\nUploading source database to it"
      mysql ${targetuser:0:8}_${dbnameprefix:0:7} < ${sqldumpdir}/${dbname}.sql
      echo -e "Done"
      echo -e "${targetuser:0:8}_${dbnameprefix:0:7}" > ${directory}/newdb.txt
    else
      echo -e "\nTarget Database exist. please enter a new Database Name\nExmaple: USER_DBNAME\nNote: Database name must be 16 characters or less."
      read newdb
      echo -e "${newdb}" >> ${log}
      echo -e "Creating ${newdb}"
      mysqladmin create ${newdb}
      echo -e "created ${newdb}\nUploading source database to it"
      mysql ${newdb} < ${sqldumpdir}/${dbname}.sql
      echo -e "Done"
      echo -e "${newdb}" >> ${directory}/newdb.txt
    fi
  fi

#Creating new database user:
  dbuserprefix=$(echo ${dbuser} |cut -d_ -f2)
  if [[ ${sourceuser} = ${targetuser} ]]
  then
    echo -e "\nSince this is the cPanel same user, please enter a new Database Username\nExmaple: USER_USERNAME\nNote: Database username must be 16 characters or less."
    read newdbuser
    echo -e "${newdbuser}" >> ${log}
    echo -e "Creating ${newdbuser}"
    mysql -e "CREATE USER '${newdbuser}'@'localhost' IDENTIFIED BY '${dbpass}';"
    echo -e "created ${newdbuser}"
    echo -e "${newdbuser}" >> ${directory}/newdbuser.txt
  else
#Checking if Target User Exist:
    mysql -e "select user from mysql.user\G"| grep "^user"| awk '{print $2}'| grep "^${targetuser:0:8}_${dbuserprefix:0:7}$"
    mucheck=$?
    if [[ ${mucheck} = "0" ]]
    then
      echo -e "\nTarget Database User exist. please enter a new Database Username\nExmaple: USER_USERNAME\nNote: Database username must be 16 characters or less."
      read newdbuser
      echo -e "${newdbuser}" >> ${log}
      mysql -e "CREATE USER '${newdbuser}'@'localhost' IDENTIFIED BY '${dbpass}';"
      echo -e "created ${newdbuser}"
      echo -e "${newdbuser}" >> ${directory}/newdbuser.txt
    else
      echo -e "Creating the Database User ${targetuser:0:8}_${dbuserprefix:0:7}"
      mysql -e "CREATE USER '${targetuser:0:8}_${dbuserprefix:0:7}'@'localhost' IDENTIFIED BY '${dbpass}';"
      echo -e "Created ${targetuser:0:8}_${dbuserprefix:0:7}"
      echo -e "${targetuser:0:8}_${dbuserprefix:0:7}" > ${directory}/newdbuser.txt
    fi
  fi

#Applying database grants:
  newdbname=$(cat ${directory}/newdb.txt)
  newdbuser=$(cat ${directory}/newdbuser.txt)
  newdbpass=${dbpass}
  newdbprefix=${dbprefix}
  echo -e "\nApplying grants to new database with the following information:\nDatabase: ${newdbname}\nDatabase User: ${newdbuser}\nUser Pass: ${newdbpass}"
  mysql -e "GRANT ALL ON ${newdbname}.* TO '${newdbuser}'@'localhost' IDENTIFIED BY '${newdbpass}';"

#Database and user mapping for WHM/cPanel:
  echo -e "Mapping the following Database and User to the cPanel account ${targetuser}:"
  echo -e "Database: ${newdbname}"
  echo -e "Database User: ${newdbuser}"
  /usr/local/cpanel/bin/dbmaptool ${targetuser} --type mysql --dbs "${newdbname}" --dbusers "${newdbuser}"

#Checking SiteURL and Home:
  echo -e "\nChecking original SiteURL and Home"
  mysql -e "SELECT option_name,option_value FROM ${newdbname}.${newdbprefix}options WHERE option_name='siteurl' OR option_name='home';"
  mysql -e "SELECT option_name,option_value FROM ${newdbname}.${newdbprefix}options WHERE option_name='siteurl' OR option_name='home';" > ${directory}/orgsiteurlhome.txt

#Updating Siteurl and Home:
  echo -e "\nDo you want to update the SiteURL and Home. (Recommened for site clones) [y/n]"
  read urlupdate
  echo -e "${urlupdate}" >> ${log}
  while [[ ${urlupdate} != @(y|Y|yes|Yes|n|N|no|No) ]]
  do
    echo -e "Please provide one of the following answers:\nY, y, Yes, yes, N, n, No, no"
    read urlupdate
    echo -e "${urlupdate}" >> ${log}
  done
  if [[ ${urlupdate} =~ ^(y|Y|yes|Yes)$ ]]
  then
    echo -e "Please provide full URL\nExample: http://domain.com or https://domain.com"
    read newurl
    echo -e "${newurl}" >> ${log}
    mysql -e "UPDATE ${newdbname}.${newdbprefix}options SET option_value='${newurl}' WHERE option_name='siteurl';"
    mysql -e "UPDATE ${newdbname}.${newdbprefix}options SET option_value='${newurl}' WHERE option_name='home';"
    echo -e "\nNew SiteURL and Home:"
    mysql -e "SELECT option_name,option_value FROM ${newdbname}.${newdbprefix}options WHERE option_name='siteurl' OR option_name='home';"
    mysql -e "SELECT option_name,option_value FROM ${newdbname}.${newdbprefix}options WHERE option_name='siteurl' OR option_name='home';" > ${directory}/newsiteurlhome.txt
  else
    echo -e "SiteURL and Home not updated." |tee -a ${directory}/newsiteurlhome.txt  
  fi

#Updating the wp-config.php with new information:
  echo -e "\nUpdating the wp-config.php"
  echo -e "\nOld Values:\nDB_Name: ${dbname}\nDB_User: ${dbuser}"
  echo -e "\nReplacing values"
  sed -i "s/define('DB_NAME',\\s\\+'${dbname}');/define('DB_NAME', '${newdbname}');/g" ${newwpconfig}
  sed -i "s/define('DB_USER',\\s\\+'${dbuser}');/define('DB_USER', '${newdbuser}');/g" ${newwpconfig}

  echo -e "\nNew Vaules:"
  echo -n "DB_Name: "; grep -e ^"define...\?DB\_NAME" ${newwpconfig} |cut -d\' -f4
  echo -n "DB_User: "; grep -e ^"define...\?DB\_USER" ${newwpconfig} |cut -d\' -f4

#Clone complete
  endtime=$(date)

  echo -e "\n\n##########\nClone completed\n##########\n\nNotes for ticket:"
  echo -e "\nScript Version: ${version}"
  echo -e "\nLogging and backups at:\n${directory}/"
  echo -e "\nAdmin: ${billing}"
  echo -e "Case Number: ${sfcase}"
  echo -e "\nStart Time: ${starttime}"
  echo -e "End Time: ${endtime}"
  echo -e "\nSource User: ${sourceuser}"
  echo -e "Target User: ${targetuser}"
  if [[ ${createaccnt} =~ ^(y|Y|yes|Yes)$ ]]
  then
    echo -e "cPanel Account was created for the clone."
  fi
  echo -e "\nSource Directory: ${wpsource}"
  echo -e "Target Directory: ${wptarget}"
  echo -e "\nSource WP-Config: ${wpconfig}"
  echo -e "Target WP-Config: ${newwpconfig}"
  echo -e "\nSource DB info:\n  DB_Name: ${dbname}\n  DB_User: ${dbuser}\n  DB_Pass: ${dbpass}\n  DB_Prefix: ${dbprefix}"
  echo -e "Target DB info:\n  DB_Name: ${newdbname}\n  DB_User: ${newdbuser}\n  DB_Pass: ${newdbpass}\n  DB_Prefix: ${newdbprefix}"
  echo -e "\nSource SiteURL and HOME:";cat ${directory}/orgsiteurlhome.txt
  echo -e "\nTarget SiteURL and HOME:";cat ${directory}/newsiteurlhome.txt

#Closing main function:
}

#Calling script

main |tee -a ${log}

exit 2
