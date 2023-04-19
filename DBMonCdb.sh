#!/bin/bash
#
#    NAME                                                                  
#      DBMonCdb.sh                                                        #
#                                                                         #
#    DESCRIPTION  :                                                       #
#       This shell script provides details at Container level             #
#      Database Overview (CDB Level)                                      #
#	  Check Database Overview                               	  #
#	  Check Backup Status                                    	  #
#	  Check Standby Sync Status                              	  #
#	  Check CDB Tablespace                                  	  #
#	  Check Archive generation per hour             	          #
#	  Check Database Flashback Status       	                  #
#	  Check Database Registry Status				  #
#         Check Invalid Object Status                                     #
#
# Author:   Jayendra Ghoghari    	                                ###
# Created:  31-03-2023  version V1                                      ###

get_dbstatus()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
CLEAR BREAKS
CLEAR COLUMNS
set colsep |
set lines 200 pages 200
SET FEEDBACK OFF
prompt ******************** DB details ********************
col HOST_NAME for a35
select INSTANCE_NAME,HOST_NAME,to_char(STARTUP_TIME,'YYYY-MM-DD HH24:MI:SS') STARTUP_TIME,open_mode, LOGINS,LOG_MODE,STATUS,DATABASE_ROLE,controlfile_type 
from gv\$instance,v\$database ORDER BY 1;
prompt
prompt ******************** PDB details ********************
col name for a12
col open_time for a33
col CON_ID for 99
col INST_ID for 99
break on name on dbid skip 1
select dbid,name,con_id,inst_id,open_mode,open_time from gv\$containers order by 3,4;
EOF
echo -e "\n"
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_backup_Status()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
set colsep |
set lines 220
set pages 1000
SET FEEDBACK OFF
col cf for 9,999
col df for 9,999
col elapsed_seconds heading "ELAPSED|SECONDS"
col i0 for 9,999
col i1 for 9,999
col l for 9,999
col output_mbytes for 99999999999 heading "OUTPUT|MBYTES"
col session_recid for 999999 heading "SESSION|RECID"
col session_stamp for 99999999999 heading "SESSION|STAMP"
col status for a10 trunc
col time_taken_display for a10 heading "TIME|TAKEN"
col output_instance for 9999 heading "OUT|INST"
prompt ******************** Last 7 Days DB Backup status  ********************
select j.input_type BACKUP_TYPE,
decode(to_char(j.start_time, 'd'), 1, 'Sunday', 2, 'Monday',
3, 'Tuesday', 4, 'Wednesday',
5, 'Thursday', 6, 'Friday',
7, 'Saturday') dow,
to_char(j.start_time, 'yyyy-mm-dd hh24:mi:ss') start_time,
to_char(j.end_time, 'yyyy-mm-dd hh24:mi:ss') end_time,
--,j.elapsed_seconds,
j.time_taken_display, j.status,
(j.output_bytes/1024/1024) output_mbytes
--x.cf, x.df, x.i0, x.i1, x.l,
--ro.inst_id output_instance
from v\$RMAN_BACKUP_JOB_DETAILS j
left outer join (select
d.session_recid, d.session_stamp,
sum(case when d.controlfile_included = 'YES' then d.pieces else 0 end) CF,
sum(case when d.controlfile_included = 'NO'
and d.backup_type||d.incremental_level = 'D' then d.pieces else 0 end) DF,
sum(case when d.backup_type||d.incremental_level = 'D0' then d.pieces else 0 end) I0,
sum(case when d.backup_type||d.incremental_level = 'I1' then d.pieces else 0 end) I1,
sum(case when d.backup_type = 'L' then d.pieces else 0 end) L
from
v\$BACKUP_SET_DETAILS d
join v\$BACKUP_SET s on s.set_stamp = d.set_stamp and s.set_count = d.set_count
where s.input_file_scan_only = 'NO'
group by d.session_recid, d.session_stamp) x
on x.session_recid = j.session_recid and x.session_stamp = j.session_stamp
left outer join (select o.session_recid, o.session_stamp, min(inst_id) inst_id
from gv\$RMAN_OUTPUT o
group by o.session_recid, o.session_stamp)
ro on ro.session_recid = j.session_recid and ro.session_stamp = j.session_stamp
where j.start_time > trunc(sysdate)-7
and j.input_type <> 'ARCHIVELOG'
order by j.start_time;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_standby_status()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
SET FEEDBACK OFF;
set colsep |
set line 150 pages 300
COL HOSTNAME FOR A25
COL APPLIED_TIME FOR A15
compute SUM of LOG_GAP on report
prompt ******************** Standby Database Sync Status ********************
SELECT  DISTINCT GVD.INST_ID,
(SELECT UPPER(SUBSTR(HOST_NAME,1,(DECODE(INSTR(HOST_NAME,'.'),0,LENGTH(HOST_NAME), (INSTR(HOST_NAME,'.')-1))))) FROM GV\$INSTANCE WHERE INST_ID=GVI.INST_ID) HOSTNAME,
GVD.NAME "DATABASE",
(SELECT MAX(SEQUENCE#) FROM V\$ARCHIVED_LOG WHERE ARCHIVED='YES' AND DEST_ID=1 AND THREAD# = GVI.THREAD#) LOG_ARCHIVED,
(SELECT MAX(SEQUENCE#) FROM V\$ARCHIVED_LOG WHERE DEST_ID=2 AND APPLIED='YES' AND THREAD# = GVI.THREAD#) LOG_APPLIED,
(SELECT MAX(SEQUENCE#) FROM V\$ARCHIVED_LOG WHERE ARCHIVED='YES' AND DEST_ID=1 AND THREAD# = GVI.THREAD#)-(SELECT MAX(SEQUENCE#) FROM V\$ARCHIVED_LOG WHERE DEST_ID=2 AND APPLIED='YES' AND THREAD# = GVI.THREAD#) LOG_GAP,
(SELECT TO_CHAR(MAX(COMPLETION_TIME),'DD-MON/HH24:MI') FROM V\$ARCHIVED_LOG WHERE DEST_ID=2 AND APPLIED='YES') APPLIED_TIME
FROM GV\$DATABASE GVD, GV\$INSTANCE GVI, V\$ARCHIVED_LOG GVA
WHERE GVI.THREAD#=GVA.THREAD#
AND GVI.INST_ID=GVD.INST_ID
ORDER BY GVD.INST_ID;
prompt
EOF
echo -e " Press Enter to Refresh ("q" to return to main menu): \c"
read rep
done
}

get_tbs_Status()
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
prompt ******************** Tablespace Utilization ********************
show CON_NAME;
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

get_arch_per_hr()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF
CLEAR BREAKS
CLEAR COLUMNS
set colsep |
set lines 200 pages 200
SET FEEDBACK OFF
prompt ******************** Last 7 Days Archive Generation ********************
set linesize 200 pagesize 1000
col inst_id for 999
col day format a3
col total format 9999
col h0 format 999
col h1 format 999
col h2 format 999
col h3 format 999
col h4 format 999
col h4 format 999
col h5 format 999
col h6 format 999
col h7 format 999
col h8 format 999
col h9 format 999
col h10 format 999
col h11 format 999
col h12 format 999
col h13 format 999
col h14 format 999
col h15 format 999
col h16 format 999
col h17 format 999
col h18 format 999
col h19 format 999
col h20 format 999
col h21 format 999
col h22 format 999
col h23 format 999
col h24 format 999
break on  day Skip 1 
SELECT TO_CHAR (first_time, 'Dy') "Day", TRUNC (first_time) "Date", inst_id, 
    COUNT (1) "Total",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '00', 1, 0)) "h0",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '01', 1, 0)) "h1",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '02', 1, 0)) "h2",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '03', 1, 0)) "h3",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '04', 1, 0)) "h4",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '05', 1, 0)) "h5",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '06', 1, 0)) "h6",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '07', 1, 0)) "h7",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '08', 1, 0)) "h8",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '09', 1, 0)) "h9",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '10', 1, 0)) "h10",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '11', 1, 0)) "h11",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '12', 1, 0)) "h12",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '13', 1, 0)) "h13",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '14', 1, 0)) "h14",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '15', 1, 0)) "h15",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '16', 1, 0)) "h16",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '17', 1, 0)) "h17",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '18', 1, 0)) "h18",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '19', 1, 0)) "h19",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '20', 1, 0)) "h20",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '21', 1, 0)) "h21",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '22', 1, 0)) "h22",
    SUM (DECODE (TO_CHAR (first_time, 'hh24'), '23', 1, 0)) "h23",
    ROUND (COUNT (1) / 24, 2) "Avg"
   FROM gv\$log_history
   WHERE thread# = inst_id
   AND first_time >= SYSDATE - 7
   GROUP BY TRUNC (first_time), inst_id, TO_CHAR (first_time, 'Dy')
   ORDER BY 2,3
/
prompt
EOF
echo -e "\n"
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_Flbk_Status()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF;
set colsep |
set linesize 300 pages 100 trimspool on numwidth 14
set sqlblanklines on
prompt 
prompt ******************** FRA details ********************
COL name for a15
select name
,      round(space_limit / 1024 / 1024) size_mb
,      round(space_used  / 1024 / 1024) used_mb
,      decode(nvl(space_used,0),0,0,round((space_used/space_limit) * 100)) pct_used
from v\$recovery_file_dest
order by name
/
prompt
prompt ******************** Usage of Space in Flash Recovery Area ********************   
select File_TYPE,PERCENT_SPACE_USED,PERCENT_SPACE_RECLAIMABLE,NUMBER_OF_FILES from v\$flash_recovery_area_usage
/
prompt 
prompt ******************** Flashback Space for Current Workload ********************

col FLASHBACK_SIZE for 999999999999999999999 head "Current size (in bytes)"
col ESTIMATED_FLASHBACK_SIZE for 999999999999999999999 head "Estimated Size (in bytes)"
col db_unique_name for a15
col OLDEST_FLASHBACK_TIME for a25 
select
	d.inst_id,
	d.db_unique_name,
	d.flashback_on,
	retention_target,
	to_char(oldest_flashback_time, 'DD-MON-YYYY HH24:MI:SS') "OLDEST_FLASHBACK_TIME",
	flashback_size,
	estimated_flashback_size 
from 	gv\$database d left join gv\$flashback_database_log fdl on d.inst_id=fdl.inst_id
order by inst_id
/
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_dbreg_Status()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF;
set colsep |
set linesize 300 pages 100 trimspool on numwidth 14
prompt 
prompt ******************** dba_registry status ********************
col STATUS for a12
col COMP_NAME for a40
col COMP_ID for a10
col VERSION for a15
col MODIFIED for a20
select COMP_ID,COMP_NAME,VERSION,STATUS,MODIFIED from dba_registry
/
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
prompt ******************** Invalid Objects ********************
Set FEEDBACK OFF
set colsep |
set lines 300 pages 1000
col owner for a20
col OBJECT_NAME for a35
col OBJECT_TYPE for a25
select count(*) INVALID_COUNT,owner,OBJECT_TYPE from dba_objects where status='INVALID' group by owner,OBJECT_TYPE order by owner;
prompt
select OWNER,OBJECT_NAME,OBJECT_TYPE,STATUS from dba_objects where STATUS='INVALID' order by OWNER;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}


while true; do
    clear
    echo -e "\n"
    echo -e "\tConnected to DB $ORACLE_UNQNAME & SID is $ORACLE_SID \t"
    echo -e "\n"
    echo -e "\t############### DB Container Details ##################"
    echo -e "\t(1) Check Database Overview                            "
    echo -e "\t(2) Check Backup Status                                "
    echo -e "\t(3) Check Standby Sync Status                          "
    echo -e "\t(4) Check CDB Tablespace                               "
    echo -e "\t(5) Check Archive generation per hour                  "
    echo -e "\t(6) Check Database Flashback Status                    "
    echo -e "\t(7) Check Database Registry Status                     "
    echo -e "\t(8) Check Invalid Objects status                       "
    echo -e "\n"
    echo -e "\tEnter your choice (q to quit): \c                      "
    echo -e "\n"
    echo -e "\t#######################################################"
tput cup 16 40     
    read option
        if [ "$option" = "q" -o "$option" = "Q" ]
        then
            echo -e "Quitting..."
            tput clear
          exit 0 
        fi 
    case $option in
        1) tput clear; get_dbstatus ;;
        2) tput clear; get_backup_Status ;;
        3) tput clear; get_standby_status ;; 
        4) tput clear; get_tbs_Status ;;
        5) tput clear; get_arch_per_hr ;;
        6) tput clear; get_Flbk_Status ;;	
        7) tput clear; get_dbreg_Status ;;
	8) tput clear; get_invalid_Obj ;;
        *) echo "Invalid option. Please try again."
            read -n1 -r -p "Press any key to continue..." key
            ;;
    esac
done

