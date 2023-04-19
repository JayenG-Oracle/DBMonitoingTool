#!/bin/bash
#
#    NAME                                              			#
#      DBMonPdbs.sh                                    			#
#                                                      			#
#    DESCRIPTION  :                                    			#
#       This shell script provides details at PDB level			#
#    Pluggable Database (PDB Level)                    			#
#	 Check PDB Status and Uptime                  			#
#	 Check PDB Tablespace                         			#
#	 Check Scheduler Job  status                  			#
#	 Scheduler Job Errors last 3 Days             			#
#	 Check Current Active Sesssions               			#
#	 Check Current wait events                    			#
#
# Author:   Jayendra Ghoghari                      		      ###
# Created:  31-03-2023  version V1                     		      ###

get_CurSess_status()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear
sqlplus -s / as sysdba <<EOF
SET FEEDBACK OFF
set colsep |
set line 300 pages 1000
set head on
col INST_ID form 99999 trunc
col sid form 999999 trunc
col serial# form 999999 trunc
col username form a15 trunc
col osuser form a8
col machine form a20 trunc head "Client|Machine"
col program form a25 trunc head "Client|Program"
col login form a11
col blocking_session for 999999 head "Blocking|Session"
Col BLOCKING_INSTANCE for 99 head "Blocking|Inst"
col "last call" form 9999999 trunc head "Last Active|In Mins"
col status form a6 trunc
col EVENT form a32 trunc
break on inst_id skip 1
alter session set container=$ORACLE_PDB_SID;
prompt 
prompt ******************** $ORACLE_PDB_SID:Instance wise Current Active Sessions ********************
select systimestamp from dual;
select INST_ID, substr(username,1,15) username,sid,serial# ,SQL_ID,EVENT,status, to_char(logon_time,'ddMon hh24:mi') login,substr(program||module,1,35) program,
substr(machine,1,25) machine,substr(osuser,1,10) osuser,blocking_session,BLOCKING_INSTANCE,round(last_call_et/60,2) "last call" 
from gv\$session where status='ACTIVE' and wait_class !='Idle'
and username is not null
order by 1
/
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}


get_CurWait_status()
{
rep=""
while [ "$rep" != "q" ]
do
sqlplus -s / as  sysdba <<EOF 
set colsep |
set line 300 pages 1000
SET FEEDBACK OFF
col event form a45
col wait_class form a15
col no_of_sessions form 999999
col avg_wait_time form 999999
col wait_time form 999999
break on inst_id skip 1
alter session set container=$ORACLE_PDB_SID;
prompt
prompt ******************** $ORACLE_PDB_SID: Instance wise Wait State ********************
select inst_id,event, wait_class, sum(SECONDS_IN_WAIT), sum(WAIT_TIME), count(1) no_of_sessions from gv\$session_wait where wait_class <> 'Idle'
group by inst_id,event, wait_class
order by 1;
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_tbs_stat()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
SET FEEDBACK OFF;
set colsep |
set linesize 150 pages 100 trimspool on numwidth 14
col name for a25
col "Allocated Size (MB)" for a19 
col "Used Size (MB)" for a15 
col "Free Space (MB)"  for a15 
col "Allocated Used %"  for a17 
col "MAX Size (MB)"  for a15 head "Max Extend (MB)" 
col "Used % (including Autoextend)" for a15 head "Used %|With Autoextend" 
col tbs_files for 9999 head "No Of|Datafiles" 
alter session set container=$ORACLE_PDB_SID;
prompt ******************** $ORACLE_PDB_SID:Tablespace Utilization  ********************
SELECT
/* PERMANENT*/
    d.tablespace_name         "Name",
    to_char(nvl(a.bytes / 1024 / 1024, 0),'99,999,999.99') "Allocated Size (MB)",
    to_char(nvl(a.bytes - nvl(f.bytes, 0),0) / 1024 / 1024 ,'99,999,999.99') "Used Size (MB)",
    to_char(nvl(f.bytes / 1024 / 1024, 0),'99,999,999.99') "Free Space (MB)",
    TO_CHAR(NVL((a.bytes - NVL(f.bytes, 0)) / a.bytes * 100, 0), '999.00') "Allocated Used %",
    to_char(nvl(a.maxbytes / 1024 / 1024, 0),'99,999,999.99') "MAX Size (MB)",
    to_char(nvl((a.bytes - nvl(f.bytes, 0)) / a.maxbytes * 100,0),'990.99') "Used % (including Autoextend)",
    cnt.tbs_files
FROM
    sys.dba_tablespaces d,
    ( SELECT tablespace_name, SUM(bytes) bytes, SUM(decode(autoextensible, 'YES', maxbytes, bytes)) maxbytes
        FROM dba_data_files
        GROUP BY tablespace_name
    )  a,
    ( SELECT tablespace_name, SUM(bytes) bytes
        FROM  dba_free_space
        GROUP BY tablespace_name
    )  f,
    (SELECT tablespace_name, COUNT(*) tbs_files
     FROM dba_data_files GROUP BY tablespace_name) cnt
WHERE
        d.tablespace_name = a.tablespace_name (+)
    AND d.tablespace_name = f.tablespace_name (+)
   and  a. tablespace_name= cnt.tablespace_name
    AND NOT ( d.extent_management LIKE 'LOCAL'
              AND d.contents LIKE 'TEMPORARY' )
UNION ALL
/* TEMPORARY*/
SELECT
    a.tablespace_name "Name",
    to_char(nvl(d.mb_total  , 0), '99,999,990.99') "Allocated Size (MB)",
    to_char(nvl(SUM(a.used_blocks ),0) / 1024 / 1024 , '99,999,999.99') "Used (MB)",
    to_char(nvl(d.mb_total - nvl(SUM(a.used_blocks ), 0),0) / 1024 / 1024 ,'99,999,999.99') "Free Space (MB)",
    to_char(nvl((SUM(a.used_blocks  ) / 1024  ) / d.mb_total * 100, 0), '999.99') "Allocated Used %",
    to_char(nvl(m.maxbytes / 1024 / 1024 , 0), '99,999,999.99') "MAX Size (MB)",
    to_char(nvl((SUM(a.used_blocks ) / 1024 ) / m.maxbytes * 100, 0), '999.99') "Used % (including Autoextend)",
    tbs_files
FROM v\$sort_segment a,
    (  select tablespace_name, sum(bytes)/ 1024 / 1024 mb_total from dba_temp_files group by tablespace_name
    )d,
    ( SELECT tablespace_name, SUM(decode(autoextensible, 'YES', maxbytes, bytes))  maxbytes , COUNT(*) tbs_files
        FROM dba_temp_files
        GROUP BY tablespace_name
    )m
WHERE  a.tablespace_name = d.tablespace_name  AND d.tablespace_name = m.tablespace_name
GROUP BY a.tablespace_name, d.mb_total,  m.maxbytes,tbs_files
ORDER BY 7 DESC
/
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_pdb_status()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
SET FEEDBACK OFF
set colsep |
alter session set container=$ORACLE_PDB_SID;
prompt
prompt ******************** PDB Status and Uptime ********************
set colsep |
set line 300 pages 1000
COL CON_ID     FOR 999
COL NAME       FOR A20
COL OPEN_MODE  FOR A20
COL OPEN_TIME  FOR A25
COL RESTRICTED FOR A10
SELECT CON_ID,NAME, OPEN_MODE,RESTRICTED, TO_CHAR(OPEN_TIME, 'DD-MON-YYYY HH24:MI') OPEN_TIME
FROM gv\$containers
order by CON_ID;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_scheduler_job_status()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
SET FEEDBACK OFF
set colsep |
set linesize 300 pages 1000 trimspool on numwidth 14
col SCHEMA_NAME format a20
col JOB_NAME format a38
Col START_DATE  format a10 trunc
col LAST_START_DATE  format a15 
col NEXT_RUN_DATE format a15 
col LAST_RUN_DURATION format a28
col SCHEDULE format a35
col JOB_TYPE format a17
col State format a10
set FEEDBACK OFF;
alter session set container=$ORACLE_PDB_SID;
prompt 
prompt ******************** $ORACLE_PDB_SID:Scheduler Job status ********************
select owner as schema_name,
       job_name,
           state,
    -- start_date,
       to_char(last_start_date,'DD-MON-YY HH24:MI') last_start_date,
       LAST_RUN_DURATION,
       to_char(next_run_date,'DD-MON-YY HH24:MI') next_run_date,
       case when job_type is null then 'PROGRAM'
            else job_type end as job_type,
       case when repeat_interval is null then schedule_name
            else repeat_interval end as schedule
from sys.all_scheduler_jobs
where LAST_START_DATE is not null  and state not in ('DISABLED','SUCCEEDED')
order by last_start_date;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_scheduler_job_error()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
SET FEEDBACK OFF
alter session set container=$ORACLE_PDB_SID;
prompt
prompt ******************** $ORACLE_PDB_SID:Failed Scheduler Jobs in Last 3 Days ********************
set line 300 pages 1000
set colsep |
col job_name for a40
col status for a15
col RUN_DURATION for a15
col error# for 99999
col ADDITIONAL_INFO for a80
select job_name,status, to_char(log_date,'DD-MON-YY HH24:MI') as "START",RUN_DURATION,error#,ADDITIONAL_INFO
from dba_scheduler_job_run_details
where log_date > sysdate-3
and status = 'FAILED'
order by log_date;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_invalid_Obj()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF
prompt ********************  $ORACLE_PDB_SID:Invalid Objects Count ********************
set colsep |
SET FEEDBACK OFF
SET VERIFY OFF
SET LINES 300 PAGES 1000
COL OWNER FOR A25
COL OBJECT_NAME FOR A40
COL OBJECT_TYPE FOR A20
BREAK ON REPORT
COMPUTE SUM LABEL "Total: " OF INVALID_COUNT ON REPORT
set lines 300 pages 1000
col owner for a25
col OBJECT_NAME for a40
col OBJECT_TYPE for a20
alter session set container=$ORACLE_PDB_SID;
select owner,OBJECT_TYPE,count(*) INVALID_COUNT from dba_objects where status='INVALID' group by owner,OBJECT_TYPE order by owner,OBJECT_TYPE;
prompt
prompt ********************  $ORACLE_PDB_SID:Invalid Object Details ********************
select OWNER,OBJECT_NAME,OBJECT_TYPE,STATUS from dba_objects where STATUS='INVALID' order by owner,OBJECT_TYPE;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}


tput clear
sqlplus -s / as sysdba <<EOFi
SET FEEDBACK OFF;
SET VERIFY OFF;
prompt ********************List of PDBs ********************
show pdbs
EOFi
echo -e "\n"
echo -n "Enter your PDB name: "
read pdb1
export ORACLE_PDB_SID=$pdb1

while true; do
    clear
    echo -e "\t The selected PDB is $ORACLE_PDB_SID                   "
    echo -e "\n"
    echo -e "\t############### Pluggable DB Detail ###################"
    echo -e "\t(1) Check PDB Status and Uptime                        "
    echo -e "\t(2) Check PDB Tablespace                               "
    echo -e "\t(3) Check Scheduler Job  status                        "
    echo -e "\t(4) Scheduler Job Errors last 3 Days                   "
    echo -e "\t(5) Check Current Active Sesssions                     "
    echo -e "\t(6) Check Current wait events                          "
    echo -e "\t(7) Check Invalid Objects                              "
    echo -e "\t(0) Back to previous Menu                              "
    echo -e "\n"
    echo -e "\tEnter your choice (q to quit): \c                      "

    read option
        if [ "$option" = "q" -o "$option" = "Q" ]
        then
            echo -e "Quitting...."
            tput clear
          exit
        fi
    
    case $option in
        1) tput clear; get_pdb_status ;;
        2) tput clear; get_tbs_stat ;;
        3) tput clear; get_scheduler_job_status ;;
        4) tput clear; get_scheduler_job_error ;;
        5) tput clear; get_CurSess_status ;;
        6) tput clear; get_CurWait_status ;;
        7) tput clear; get_invalid_Obj ;;
        0) echo "Exiting $ORACLE_PDB_SID pdb ..." ; export ORACLE_PDB_SID= ; exit 0 ;;
        *) echo "Invalid option. Please try again." ; read -n1 -r -p "Press any key to continue..." key ;;
    esac
done

