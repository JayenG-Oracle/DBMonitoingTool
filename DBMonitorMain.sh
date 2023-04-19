#!/bin/bash
#    NAME																  #
#      DBMonitorMain.sh                                                   #
#                                                                         #
#    DESCRIPTION  :                                                       #
#       This shell script provides menu driven SQL scripts to             #
#       monitoring day to day DBA activity.                               #
#       It will simplify the way you manage your database (12c & Above).  #
#                                                                         #
# How To Use:                                                             #
# ***********                                                             #
# 1- set envrionment variable ORACLE_UNQNAME                              #
# 2- sh DBMonitorMain.sh                                                  #
#                                                                         #
# FEATURES:                                                               #
# ********                                                                #
#   1- Host Overview                                                      #
#       > Host details                                                    #
#       > CPU , Memory & File system  details		                      #
#   2- Storage Overview                                                   #
#		> Host Mount point Utilization                                    #
#		> ASM Space Utilization                                           #
#		> Database Storage Structure                                      #
#		> Tablespace Utilization                                          #
#   3- Database Overview (CDB Level)                                      #
#		> Check Database Overview                                         #
#		> Check Backup Status                                             #
#		> Check Standby Sync Status                                       #
#		> Check CDB Tablespace                                            #
#		> Check Archive generation per hour                               #
#		> Check Database Flashback Status                                 #
#		> Check Database Registry Status			                      #
#   4- Connect Pluggable Database (PDB Level)                             #
#		> Check PDB Status and Uptime                                     #
#		> Check PDB Tablespace                                            #
#		> Check Scheduler Job  status                                     #
#		> Scheduler Job Errors last 3 Days                                #
#		> Check Current Active Sesssions                                  #
#		> Check Current wait events                                       #
#   5- Database Performance Hub                                           #
#		> Check Active sessions                                           #
#		> Check Blocking session                                          #
#		> Check Temp usage                                                #
#		> Check Undo Usage                                                #
#		> Check DBA Registry status                                       #
#		> Invalid objects count                                           #
#		> Top CPU consuming sessions                                      #
#		> Top High Elapsed Time Queries                                   #
#		> Monitor parallel queries                                        #
#		> Check Underscore parameter                                      #
#		> View Xplain Plan for sql_id                                     #
#		> View SQL Execution Plan History (planc)                         #
#		> Generate AWR/ADDM/ASH Reports                                   #
#																		###
# Author:   Jayendra Ghoghari											### 
# Created:  31-03-2023  version V1 										###

get_host_status()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
echo -e "\t ********************  Host details ********************"
# Get the hostname ,IP address ,operating system,CPU, Memory 
hostname=$(hostname)
ip_address=$(hostname -i)
os=$(uname -o)
kernel=$(uname -r)
memory=$(free -h)
cpu_count=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
# Get the number of threads per core
threads=$(lscpu | grep "^Thread(s) per core" | awk '{print $4}')
# Get the disk usage information
disk=$(df -h)
# Get server uptime
uptime_output=$(uptime | cut -d ',' -f 1)

# Print the host information
echo -e "\t Hostname: $hostname"
echo -e "\n"
echo -e "\t Server uptime: $uptime_output"
echo -e "\n"
echo -e "\t IP Address: $ip_address"
echo -e "\n"
echo -e "\t Operating System: $os Kernel Release: $kernel"
echo -e "\n"
echo -e "\t CPU Thread Details"
echo -e "\t ------------------"
echo -e "\t Number of CPUs: $cpu_count"
#echo -e "\t Threads per core: $threads"
echo -e "\n"
echo -e "\t Server Memory:"
echo -e "$memory" | sed 's/^/\t/'
echo -e "\n"
echo -e "\tDisk Usage:"
echo "$disk" | sed 's/^/\t/'
echo -e "\n"
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

while true; do
    clear
	echo -e "\n\t################# Set Envirnment #################\n"
	#. oraset $ORACLE_UNQNAME > /dev/null
        . oraset -m 
       if [ $db = "Cancel" ]
        then
            echo -e "Quitting..."
            tput clear
          exit 0
        fi

MC=`uname -a|awk '{print $2}'|tr 'a-z' 'A-Z'`
MENU_NAME=${MENU_NAME:-"DB Host Name is $MC"} 

 while true; do
    clear
    echo -e "\t$MENU_NAME\t"
    echo -e "\n"
    echo -e "\tEnvronment set to DB: $ORACLE_UNQNAME & SID: $ORACLE_SID \n"
    echo -e "\t################# DBA Monitoting Menu #################"
    echo -e "\t(1) Host Overview                                      "
    echo -e "\t(2) Storage Overview                                   "
    echo -e "\t(3) Database Overview (CDB Level)                      "
    echo -e "\t(4) Connect Pluggable Database (PDB Level)             "
    echo -e "\t(5) Database Performance Hub                           "
    echo -e "\n"
    echo -e "\tEnter your choice (q to quit): \c                      "
    echo -e "\n"
    echo -e "\t#######################################################"
    tput cup 13 40     
    read option
        if [ "$option" = "q" -o "$option" = "Q" ]
        then
            echo -e "Quitting..."
            tput clear
          exit 0 
        fi 
    case $option in
        1) tput clear; get_host_status ;;
        2) tput clear; sh DBMonStorage.sh ;;
        3) tput clear; sh DBMonCdb.sh ;; 
        4) tput clear; sh DBMonPdbs.sh ;;
        5) tput clear; sh DBMonPerf.sh ;;	
        *) echo "Invalid option. Please try again."
            read -n1 -r -p "Press any key to continue..." key
            ;;
    esac
 done
done
