#!/bin/bash
#
#    NAME                                                                  
#      DBReports.sh                                                       #
#                                                                         #
#    DESCRIPTION  :                                                       #
#       This shell script provides details at DB Perf Reports             #
#     DB Perfomrance Report                                               #
#		 Generate AWR Report                                      #
#		 Generate AWR Global RAC Report                           #
#		 Generate ADDM report                                     #
#		 Generate AWR Comparae Report                             #
#		 Generate AWR Global RAC Compare Report                   #
#		 Generate ASH Report                                      #
#		 Generate SQL Report                                      #
#
# Author:   Jayendra Ghoghari                                           ###
# Created:  31-03-2023  version V1                                      ###

get_awrrpt()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
echo -e "\t################# Generate AWR Report #################"
echo -e "\n\tConnected to DB $ORACLE_UNQNAME " 
./oraset $ORACLE_UNQNAME > /dev/null

echo -e "\n\t*** List of PDBs ***"
sqlplus -s / as sysdba <<EOFi
SET FEEDBACK OFF;
SET VERIFY OFF;
set colsep |
col NAME for a15
col OPEN_MODE for a12
col RESTRICTED for a10
select CON_ID,NAME,OPEN_MODE,RESTRICTED  from v\$CONTAINERS;
PROMPT
PROMPT 		*** AWR Snapshot Setting ***
col snap_interval for a24
col retention for a24
select CON_ID,snap_interval, retention from cdb_hist_wr_control where con_id is not null order by 1
/
EOFi

echo -e "\n\tEnter pdb_name:\c "
read pdb_name

echo -e "\tEnter AWR Report Begin time (YYYY/MM/DD HH24.MI):\c "
read begin_snap_time

echo -e "\tEnter Interval value to Analyse no of AWR snapshots (default 1): \c"
read interval
interval=${interval:=1}

echo -e "\tEnter value for Report Type HTML/TEXT (default HTML):\c "
read rtype
rtype=${rtype:='HTML'}

cur_dir=$(pwd)

echo -e "\n\t*** For RAC database AWR generated for all Instances ***"
echo -e "\t*** AWR Report Generation for:${pdb_name} is in progress... ***"

sqlplus -s / as  sysdba <<EOF 
SET FEEDBACK OFF;
ALTER SESSION SET NLS_LANGUAGE = 'AMERICAN';
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY/MM/DD HH24.MI';
alter session set container =$pdb_name;
@./create_awr_rptv1.sql ${pdb_name} "${begin_snap_time}" $interval ${cur_dir} ${rtype}
/
EOF
echo -e "\n"
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_gawrrpt()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
echo -e "\t################# Genrate Gloabal RAC Report #################"
echo -e "\tConnected to DB $ORACLE_UNQNAME "
./oraset $ORACLE_UNQNAME > /dev/null

echo -e "\n\t*** List of PDBs ***"
sqlplus -s / as sysdba <<EOFi
SET FEEDBACK OFF;
SET VERIFY OFF;
set colsep |
col NAME for a15
col OPEN_MODE for a12
col RESTRICTED for a10
select CON_ID,NAME,OPEN_MODE,RESTRICTED  from v\$CONTAINERS;
PROMPT
PROMPT          *** AWR Snapshot Setting ***
col snap_interval for a24
col retention for a24
select CON_ID,snap_interval, retention from cdb_hist_wr_control where con_id is not null order by 1
/
EOFi

echo -e "\n\tEnter pdb_name:\c "
read pdb_name

echo -e "\tEnter AWR Report Begin time (YYYY/MM/DD HH24.MI):\c "
read begin_snap_time

echo -e "\tEnter Interval value to Analyse no of AWR snapshots (default 1): \c"
read interval
interval=${interval:=1}

cur_dir=$(pwd)

echo -e "\tEnter value for Report Type HTML/TEXT (default HTML):\c "
read rtype
rtype=${rtype:='HTML'}

echo -e "\n\t*** AWR Global RAC Report Generation for:$ORACLE_UNQNAME is in progress... ***"

sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF;
ALTER SESSION SET NLS_LANGUAGE = 'AMERICAN';
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY/MM/DD HH24.MI';
alter session set container =$pdb_name;
@./create_global_awr_rptv1.sql ${pdb_name} "${begin_snap_time}" $interval ${cur_dir} ${rtype}
/
EOF
echo -e "\n"
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_addmrpt()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
echo -e "\t################# ADDM Report Generate from Auto Advisor task #################"
echo -e "\n\tConnected to DB $ORACLE_UNQNAME "
./oraset $ORACLE_UNQNAME > /dev/null

echo -e "\n\t*** List of PDBs ***"
sqlplus -s / as sysdba <<EOFi
SET FEEDBACK OFF;
SET VERIFY OFF;
set colsep |
col NAME for a15
col OPEN_MODE for a12
col RESTRICTED for a10
select CON_ID,NAME,OPEN_MODE,RESTRICTED  from v\$CONTAINERS
/
PROMPT
EOFi

echo -e "\n\tEnter pdb_name:\c "
read pdb_name

echo -e "\tEnter ADDM Report Time (YYYY/MM/DD HH24.MI):\c "
read begin_time

echo -e "\tEnter 'Y' for Indvidual Instance Report or Enter 'N' for Single Report for All Instance (default Y) : \c"
read instance
instance=${instance:=Y}

cur_dir=$(pwd)

echo -e "\n\t*** ADDM Report Generation is in progress... ***"
sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF;
ALTER SESSION SET NLS_LANGUAGE = 'AMERICAN';
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY/MM/DD HH24.MI';
alter session set container =$pdb_name;
@./create_addm_rptv1.sql ${pdb_name} "${begin_time}" $instance ${cur_dir}
/
EOF
echo -e "\n"
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_awrdiff()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
echo -e "\t################# AWR Compare report #################"
echo -e "\n\tConnected to DB $ORACLE_UNQNAME "
./oraset $ORACLE_UNQNAME > /dev/null

echo -e "\n\t*** List of PDBs ***"
sqlplus -s / as sysdba <<EOFi
SET FEEDBACK OFF;
SET VERIFY OFF;
set colsep |
col NAME for a15
col OPEN_MODE for a12
col RESTRICTED for a10
select CON_ID,NAME,OPEN_MODE,RESTRICTED  from v\$CONTAINERS;
PROMPT
PROMPT          *** AWR Snapshot Setting ***
col snap_interval for a24
col retention for a24
select CON_ID,snap_interval, retention from cdb_hist_wr_control where con_id is not null order by 1
/
EOFi

echo -e "\n\tEnter pdb_name:\c "
read pdb_name

echo -e "\tEnter First Instance No (default 1): \c"
read Inst_1
Inst_1=${Inst_1:=1}

echo -e "\tEnter First Instance Snapshot Begin Time (YYYY/MM/DD HH24.MI):\c "
read begin_snap1

echo -e "\tEnter Interval value to Analyse no of snapshots from begin time (default 1): \c"
read interval
interval=${interval:=1}

echo -e "\tPress Enter to compare same instance or Enter another Instance number : \c"
read Inst_2
Inst_2=${Inst_2:= $Inst_1}

echo -e "\tEnter Second Instnace Snapshot Begin time (YYYY/MM/DD HH24.MI):\c "
read begin_snap2

echo -e "\tEnter value for Report Type HTML/TEXT (default HTML):\c "
read rtype
rtype=${rtype:='HTML'}

cur_dir=$(pwd)
 
echo -e "\t*** AWR DIFF Report Generation for:${pdb_name} is in progress... ***"

sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF;
ALTER SESSION SET NLS_LANGUAGE = 'AMERICAN';
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY/MM/DD HH24.MI';
alter session set container =$pdb_name;
@./create_awr_diffv1.sql ${pdb_name} $Inst_1 $Inst_2 "${begin_snap1}" "${begin_snap2}" ${rtype} $interval ${cur_dir}
/
EOF
echo -e "\n"
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_gawrdiff()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
echo -e "\t################# Global RAC AWR Compare Report #################"
echo -e "\n\tConnected to DB $ORACLE_UNQNAME "
./oraset $ORACLE_UNQNAME > /dev/null

echo -e "\n\t*** List of PDBs ***"
sqlplus -s / as sysdba <<EOFi
SET FEEDBACK OFF;
SET VERIFY OFF;
set colsep |
col NAME for a15
col OPEN_MODE for a12
col RESTRICTED for a10
select CON_ID,NAME,OPEN_MODE,RESTRICTED  from v\$CONTAINERS;
PROMPT
PROMPT          *** AWR Snapshot Setting ***
col snap_interval for a24
col retention for a24
select CON_ID,snap_interval, retention from cdb_hist_wr_control where con_id is not null order by 1
/
EOFi

echo -e "\n\tEnter pdb_name:\c "
read pdb_name

echo -e "\t1st List of Instances:Press Enter for All or Type Specific Instance no.(eg. 1,2): \c"
read Inst_1
Inst_1=${Inst_1:=}

echo -e "\tEnter First List Instances Snapshot Begin time (YYYY/MM/DD HH24.MI):\c "
read begin_snap1

echo -e "\tEnter Interval value to Analyse no of AWR snapshots from Begin time (default 1): \c"
read interval
interval=${interval:=1}

echo -e "\t2nd List of Instances:Press Enter for All or Type Specific Instance no.(eg. 1,2): \c"
read Inst_2
Inst_2=${Inst_2:=}

echo -e "\tEnter Second List Instances Snapshot Begin time (YYYY/MM/DD HH24.MI):\c "
read begin_snap2

echo -e "\tEnter value for Report Type HTML/TEXT (default HTML):\c "
read rtype
rtype=${rtype:='HTML'}

cur_dir=$(pwd)

echo -e "\t*** Gloabl RAC AWR DIFF Report Generation for:${pdb_name} is in progress... ***"

sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF;
ALTER SESSION SET NLS_LANGUAGE = 'AMERICAN';
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY/MM/DD HH24.MI';
alter session set container =$pdb_name;
@./create_global_awr_diffv1.sql ${pdb_name} "${Inst_1}" "${Inst_2}" "${begin_snap1}" "${begin_snap2}" ${rtype} $interval ${cur_dir}
/
EOF
echo -e "\n"
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}




get_ash()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
echo -e "\t################# ASH Report #################"
echo -e "\n\tConnected to DB $ORACLE_UNQNAME "
./oraset $ORACLE_UNQNAME > /dev/null

echo -e "\n\t*** List of PDBs ***"
sqlplus -s / as sysdba <<EOFi
SET FEEDBACK OFF;
SET VERIFY OFF;
set colsep |
col NAME for a15
col OPEN_MODE for a12
col RESTRICTED for a10
select CON_ID,NAME,OPEN_MODE,RESTRICTED  from v\$CONTAINERS
/
EOFi

echo -e "\n\tPress Enter or Provide specific pdb_name:\c "
read pdb_name
pdb_name=${pdb_name:=}

echo -e "\tEnter Value for Begin time (YYYY/MM/DD HH24.MI):\c "
read begin_snap

echo -e "\tEnter Value for End time (YYYY/MM/DD HH24.MI):\c "
read end_snap

echo -e "\tDo you want create Global ASH (default N) : \c"
read option
option_1=${option:=N}

echo -e "\tCreate Report in 'html' or 'text' (default html) : \c"
read rtype
rtype=${rtype:=HTML}

cur_dir=$(pwd)

echo -e "\t*** ASH Report Generation for:${pdb_name} is in progress... ***"

sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF;
column dbid new_value v_dbid;
ALTER SESSION SET NLS_LANGUAGE = 'AMERICAN';
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY/MM/DD HH24.MI';
@./crearte_ash_rptv1.sql "${pdb_name}" "${begin_snap}" "${end_snap}" ${option} $rtype ${cur_dir}
/
EOF
echo -e "\n"
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_awrsqlrpt()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
echo -e "\t################# Generate AWR SQL Report #################"
echo -e "\n\tConnected to DB $ORACLE_UNQNAME "
./oraset $ORACLE_UNQNAME > /dev/null

echo -e "\n\t*** List of PDBs ***"
sqlplus -s / as sysdba <<EOFi
SET FEEDBACK OFF;
SET VERIFY OFF;
set colsep |
col NAME for a15
col OPEN_MODE for a12
col RESTRICTED for a10
select CON_ID,NAME,OPEN_MODE,RESTRICTED  from v\$CONTAINERS
/
EOFi

echo -e "\n\tEnter pdb_name:\c "
read pdb_name

echo -e "\tEnter AWR Report Begin time (YYYY/MM/DD HH24.MI):\c "
read begin_snap_time

echo -e "\tEnter SQLID for Report:\c "
read sql_id

echo -e "\tEnter value for Report Type HTML/TEXT (default HTML):\c "
read rtype
rtype=${rtype:='HTML'}

cur_dir=$(pwd)

echo -e "\n\t*** For RAC database report generated from all Instances ***"
echo -e "\t*** SQL Report Generation for:${sql_id} is in progress... ***"

sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF;
ALTER SESSION SET NLS_LANGUAGE = 'AMERICAN';
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY/MM/DD HH24.MI';
alter session set container =$pdb_name;
@./create_awrsql_rptv1.sql ${pdb_name} "${begin_snap_time}" ${sql_id} ${cur_dir} ${rtype}
/
EOF
echo -e "\n"
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

while true; do
    clear
    echo -e "\n"
    echo -e "\tConnected to DB $ORACLE_UNQNAME & SID is $ORACLE_SID \t"
    echo -e "\t"
    echo -e "\t#######################################################"
    echo -e "\t(1) Generate AWR Report                                "
    echo -e "\t(2) Generate AWR Global RAC Report                     "
    echo -e "\t(3) Generate ADDM report                               "
    echo -e "\t(4) Generate AWR Comparae Report                       "
    echo -e "\t(5) Generate AWR Global RAC Compare Report             "
    echo -e "\t(6) Generate ASH Report                                "
    echo -e "\t(7) Generate SQL Report                                "
    echo -e "\n"
    echo -e "\tEnter your choice (q to quit): \c                      "
    echo -e "\n"
    echo -e "\t#######################################################"
tput cup 14 40     
    read option
        if [ "$option" = "q" -o "$option" = "Q" ]
        then
            echo -e "Quitting..."
            tput clear
          exit 0 
        fi 
    case $option in
        1) tput clear; get_awrrpt ;;
        2) tput clear; get_gawrrpt ;;
        3) tput clear; get_addmrpt ;; 
        4) tput clear; get_awrdiff ;;
        5) tput clear; get_gawrdiff ;;
        6) tput clear; get_ash ;;	
        7) tput clear; get_awrsqlrpt ;;
        *) echo "Invalid option. Please try again."
            read -n1 -r -p "Press any key to continue..." key
            ;;
    esac
done

