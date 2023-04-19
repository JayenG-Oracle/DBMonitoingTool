#!/bin/bash
#
#    NAME                                              			#
#      DBMonPdbs.sh                                    			#
#                                                      			#
#    DESCRIPTION  :                                    			#
#       This shell script used for creating DB perf reports		#
#    Database Performance Hub                           		#
#	   Check Active sessions                            		#
#	   Check Blocking session                           		#
#	   Check Temp usage                                 		#
#	   Check Undo Usage                                 		#
#	   Check DBA Registry status                        		#
#	   Invalid objects count                            		#
#	   Top CPU consuming sessions                       		#
#	   Top High Elapsed Time Queries                    		#
#	   Monitor parallel queries                         		#
#	   Check Underscore parameter                       		#
#	   View Xplain Plan for sql_id                      		#
#	   View SQL Execution Plan History (planc)          		#
#	   Generate AWR/ADDM/ASH Reports                    		#
#                                                       		#
# Author:   Jayendra Ghoghari					      ###
# Created:  31-03-2023  version V1 				      ###

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

get_TopCPU()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
 prompt ******************** $ORACLE_PDB_SID:Instance wise Top 15 CPU Consuming Query ********************
SET FEEDBACK OFF
set colsep |
set lines 300 pages 1000
col program form a35 heading "Program"
col cpu_usage_sec form 999999  trunc head "CPU|In_Second"
col ACTIVE_IN_MINS for 99999 trunc head "Active|In_Mins"
col MODULE for a25
col OSUSER for a10
col USERNAME for a15
col SPID for a6 heading "OS PID"
col SID for 99999
col SERIAL# for 999999
col SQL_ID for a15
col MACHINE for a25
col INST_ID for 99
col LOGON_TIME for a14
break on INST_ID skip 1
alter session set container=$ORACLE_PDB_SID;
SELECT INST_ID, SPID, SID, SERIAL#, SQL_ID, USERNAME, PROGRAM, MODULE, OSUSER, MACHINE, STATUS, CPU_USAGE_SEC, ACTIVE_IN_MINS,LOGON_TIME
FROM (
  SELECT inst_id, spid, SID, serial#, SQL_ID, username,
         SUBSTR(program, 1, 35) AS program,
         SUBSTR(module, 1, 25) AS module,
         osuser, SUBSTR(MACHINE, 1, 25) AS machine, status,
         cpu_usage_sec, ROUND(last_call_et/60, 2) AS active_in_mins,LOGON_TIME,
         ROW_NUMBER() OVER (PARTITION BY inst_id ORDER BY cpu_usage_sec DESC) AS rank
  FROM (
    SELECT ss.inst_id, p.spid, se.SID, ss.serial#, ss.SQL_ID, ss.username,
           ss.program, ss.module, ss.osuser, ss.MACHINE, ss.status,
           se.VALUE/100 AS cpu_usage_sec, SS.last_call_et,TO_CHAR(SS.LOGON_TIME,'DD-MON HH24:MI') AS LOGON_TIME
    FROM gv\$session ss, gv\$sesstat se, gv\$statname sn, gv\$process p, gv\$instance v_instance
    WHERE se.STATISTIC# = sn.STATISTIC#
      AND NAME LIKE '%CPU used by this session%'
      AND se.SID = ss.SID
      AND ss.username != 'SYS'
      AND ss.status = 'ACTIVE'
      AND ss.username IS NOT NULL
      and ss.paddr=p.addr and se.value > 0
and ss.inst_id=v_instance.instance_number 
order by cpu_usage_sec desc )
) WHERE rank < 16;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_block_Sess()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
 prompt ******************** $ORACLE_PDB_SID:Blocking Sessions ********************
Set FEEDBACK OFF
set colsep |
set lines 300 pages 1000
col SID for 99999
col SERIAL# for 999999
col INST_ID for 99
col MODULE for a25
col USERNAME for a18
col seconds_in_wait for 999999
col STATUS for a15
col LOGON_TIME for a15
break on INST_ID skip 1
alter session set container=$ORACLE_PDB_SID;
SELECT s.inst_id,  s.sid,s.serial#,s.USERNAME , s.blocking_session, s.seconds_in_wait,s.STATUS,  s.MODULE ,TO_CHAR(S.LOGON_TIME,'DDMON HH24:MI') AS LOGON_TIME  
FROM gv\$session s
WHERE blocking_session IS NOT NULL;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_temp_use()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
 prompt ******************** $ORACLE_PDB_SID:Temp usage ********************
Set FEEDBACK OFF
set colsep |
set lines 300 pages 1000
col CON_ID for 999
col tablespace for a15
col TEMP_TOTAL_MB format 999999999.99 head "TOTAL SIZE|IN MB" 
col TEMP_USED_MB format 999999999.99 head "USED SIZE|IN MB"
col TEMP_FREE_MB format 999999999.99 head "FREE SIZE|IN MB"
alter session set container=$ORACLE_PDB_SID;
select CON_ID,a.tablespace_name tablespace,
d.TEMP_TOTAL_MB,
sum (a.used_blocks * d.block_size) / 1024 / 1024 TEMP_USED_MB,
d.TEMP_TOTAL_MB - sum (a.used_blocks * d.block_size) / 1024 / 1024 TEMP_FREE_MB
from gv\$sort_segment a,
(select b.name, c.block_size, sum (c.bytes) / 1024 / 1024 TEMP_TOTAL_MB
from v\$tablespace b, v\$tempfile c
where b.ts#= c.ts#
group by b.name, c.block_size) d
where a.tablespace_name = d.name
group by CON_ID,a.tablespace_name, d.TEMP_TOTAL_MB order by 1;
prompt
prompt ******************** Active Temp usage sessions ********************
col INST_ID for 999
col SID for 999999
col SERIAL# for 999999
col TEMP_SIZE for a10
col USERNAME for a18
col PROGRAM for a35
col STATUS for a10
col SQL_ID for a15
col LOGON_TIME for a15
break on INST_ID skip 1
SELECT a.inst_id,a.sid, a.serial# ,b.tablespace,ROUND(((b.blocks*p.value)/1024/1024),2)||'M' AS temp_size,
NVL(a.username, '(oracle)') AS username,a.program,a.status,a.sql_id,TO_CHAR(a.LOGON_TIME,'DDMON HH24:MI') AS LOGON_TIME
FROM gv\$session a,gv\$sort_usage b,gv\$parameter p
WHERE p.name = 'db_block_size'
AND a.saddr = b.session_addr
AND a.inst_id=b.inst_id
AND a.inst_id=p.inst_id
AND STATUS ='ACTIVE'
ORDER BY INST_ID,temp_size desc
/
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_undo_use()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF 
 prompt ******************** $ORACLE_PDB_SID: UNDO Usage ********************
Set FEEDBACK OFF
set colsep |
set lines 300 pages 1000
col TABLESPACE_NAME for a30
col SIZEMB format 999999999.99 head "TOTAL SIZE|IN MB" 
col USAGEMB format 999999999.99 head "USED SIZE|IN MB"
col FREEMB format 999999999.99 head "FREE SIZE|IN MB"
alter session set container=$ORACLE_PDB_SID;
select a.tablespace_name, SIZEMB, USAGEMB, (SIZEMB - USAGEMB) FREEMB
from (select sum(bytes) / 1024 / 1024 SIZEMB, b.tablespace_name
from dba_data_files a, dba_tablespaces b
where a.tablespace_name = b.tablespace_name
and b.contents = 'UNDO'
group by b.tablespace_name) a,
(select c.tablespace_name, sum(bytes) / 1024 / 1024 USAGEMB
from DBA_UNDO_EXTENTS c
where status <> 'EXPIRED'
group by c.tablespace_name) b
where a.tablespace_name = b.tablespace_name;
prompt
prompt ******************** Sessions Generating Undo ********************
col INST_ID for 999
col SID for 999999
col SERIAL# for 999999
col USERNAME for a15
col PROGRAM for a35
col STATUS for a10
col SQL_ID for a15
col LOGON_TIME for a15
col USED_UNDO_RECORD for 99999999
col USED_UNDO_BLOCKS for 99999999
break on INST_ID skip 1
select a.inst_id,a.sid, a.serial#, a.username, a.program,a.status,
a.sql_id, b.used_urec used_undo_record, b.used_ublk used_undo_blocks,
TO_CHAR(a.LOGON_TIME,'DDMON HH24:MI') AS LOGON_TIME
from gv\$session a, gv\$transaction b
where a.saddr=b.ses_addr order by 1;
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
prompt ******************** $ORACLE_PDB_SID:DB Registry Component status ********************
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

get_high_elapse()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF
set colsep |
set lines 300 pages 1000
col INST for 99
col SID for 999999
col USERNAME for a16
col SERIAL# for 999999
col command for a13
col EVENT for a32 TRUNC
col LAST_CALL_ET for 9999 head "Active|In_Mins"
col LOGON_TIME for a11
COl USED_UREC for 999999  head  "UNDO|RECORDS"
COL ELAPSED_TIME for 99999999 head "ELAPSE|TIME_Sec"
col ELA_PER_EXEC format 9999999 head "ELAPASE|PER_EXEC"
col sqltext for a32 trunc head 'SQLTEXT'
col executions for 999999 head "No|Exec"
break on INST skip 1
alter session set container=$ORACLE_PDB_SID;
prompt
prompt ******************** $ORACLE_PDB_SID:Top 20 High Elapsed Time Queries  ********************
select * from (
select s.inst_id INST, s.sid, s.serial#, s.status, s.username, to_char(logon_time, 'DDMON hh24:mi') logon_time, sql.sql_id
, sql.executions, s.last_call_et/60 LAST_CALL_ET , t.USED_UREC
, round(sql.elapsed_time/1000000,2) elapsed_time
, round(sql.elapsed_time/1000000/decode(sql.executions,0,1,sql.executions),2) ela_per_exec
,decode(s.command,
     0,'No Command',
     1,'Create Table',
     2,'Insert',
     3,'Select',
     6,'Update',
     7,'Delete',
     9,'Create Index',
     15,'Alter Table',
     21,'Create View',
     23,'Validate Index',
     35,'Alter Database',
     39,'Create Tablespace',
     41,'Drop Tablespace',
     40,'Alter Tablespace',
     53,'Drop User',
     62,'Analyze Table',
     63,'Analyze Index',
     s.command||': Other') command
--, s.machine
, s.event,
SUBSTR(sql_fulltext,1,75) sqltext
from gv\$session s
inner join gv\$sql sql
on s.sql_id=sql.sql_id
left outer join gv\$transaction t
on s.saddr = t.ses_addr
where
1=1
and s.inst_id = sql.inst_id
and s.sql_child_number = sql.child_number
and s.username not in ('SYS','SYSRAC','PUBLIC','GGADMIN','DBSNMP')
order by INST,ela_per_exec desc
) WHERE ROWNUM <= 20;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_px_sql()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF
set colsep |
set lines 300 pages 1000
col INST_ID for 999
col SID for 999999
col SERIAL# for 999999
col SPID for a6
col QC_SID for a8  
col USERNAME for a18
col PROGRAM for a35
col QC/SLAVE for a8 head "QC|SLAVE"
col SQL_ID for a15
col LOGON_TIME for a12
col Slave_Set for a5 head "SLAVE|Set"
col MODULE for a25
col req_degree for 999 head "Requested|DOP"
col degree for 999 head "Actual|DOP"
break on INST_ID skip 1
alter session set container=$ORACLE_PDB_SID;
prompt
prompt ******************** $ORACLE_PDB_SID:Current Parallel Querries ********************
SELECT
  s.inst_id,
  s.sid SID,
  DECODE(px.qcinst_id, NULL, TO_CHAR(s.sid), px.qcsid) QC_SID,s.serial#,p.spid,
  DECODE(px.qcinst_id,NULL,s.username,' - '||LOWER(SUBSTR(s.program,LENGTH(s.program)-4,4))) USERNAME,
  DECODE(px.qcinst_id,NULL,'QC','(Slave)') "QC/Slave",
  TO_CHAR(px.server_set) Slave_Set,
  px.req_degree,
  px.degree,
  /* s.sql_exec_start,substr(s.MACHINE,1,25) "MACHINE", */
   s.sql_id,  substr(s.program,1,35) "program",
substr(s.module,1,25) "MODULE",
TO_CHAR(S.LOGON_TIME,'DDMON HH24:MI') AS LOGON_TIME,s.last_call_et
FROM
  gv\$px_session px,
  gv\$session s,
  gv\$process p
WHERE
  px.sid = s.sid (+)
  AND px.serial# = s.serial#
  AND px.inst_id = s.inst_id
  AND p.inst_id = s.inst_id
  AND p.addr = s.paddr
ORDER BY  QC_SID,Slave_Set desc;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_undparam()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
echo -e "\n\t################# Connected to DB $ORACLE_UNQNAME #################\n"
echo -e "\n\tEnter the underscore parameter name: \c"
read u_param

sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF
set colsep |
set lines 300
col "Parameter" for a30
col "Session Value" for a25
col "Instance Value" for a25
alter session set container=$ORACLE_PDB_SID;
prompt
prompt ******************** $ORACLE_PDB_SID:Undersore Parameter ********************
SELECT a.ksppinm "Parameter", b.KSPPSTDF "Default Value",
       b.ksppstvl "Session Value", 
       c.ksppstvl "Instance Value",
       decode(bitand(a.ksppiflg/256,1),1,'TRUE','FALSE') IS_SESSION_MODIFIABLE,
       decode(bitand(a.ksppiflg/65536,3),1,'IMMEDIATE',2,'DEFERRED',3,'IMMEDIATE','FALSE') IS_SYSTEM_MODIFIABLE
FROM   x\$ksppi a,
       x\$ksppcv b,
       x\$ksppsv c
WHERE  a.indx = b.indx
AND    a.indx = c.indx
AND    a.ksppinm LIKE '/${u_param}' escape '/';
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_xplan()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear
echo -e "\n\t################# Connected to $ORACLE_PDB_SID #################\n"
echo -e "\n\tEnter the sql id: \c"
read v_sqlid
sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF
set colsep |
set lines 300 pages 1000
alter session set container=$ORACLE_PDB_SID;
prompt
prompt ******************** Explain Plan for Sql_id: $v_sqlid ********************
SELECT *
FROM TABLE(
  CASE
    WHEN (SELECT COUNT(*) FROM gv\$sql WHERE sql_id = '${v_sqlid}') > 0
    THEN 
    DBMS_XPLAN.DISPLAY_CURSOR('${v_sqlid}', NULL, 'ALL')
    ELSE DBMS_XPLAN.DISPLAY_AWR('${v_sqlid}', NULL, NULL, 'ALL')
  END
);
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_planc()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear
echo -e "\n\t################# Connected to $ORACLE_PDB_SID #################\n"
echo -e "\n\tEnter the sql id: \c"
read v_sqlid
 
sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF
set colsep |
set lines 300 pages 1000
col execs for 999,999,999 
col avg_etime for 999,999.999 
col avg_lio for 999,999,999.9 
col begin_interval_time for a30 
col node for 99999 
alter session set container=$ORACLE_PDB_SID;
prompt
prompt ******************** $ORACLE_PDB_SID:Sql $v_sqlid Execution History (Planc) ********************
select ss.snap_id, ss.instance_number node, begin_interval_time, sql_id, plan_hash_value, 
nvl(executions_delta,0) execs, s.rows_processed_delta rowdelta,
(elapsed_time_delta/decode(nvl(executions_delta,0),0,1,executions_delta))/1000000 avg_etime, 
(buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta)) avg_lio 
from DBA_HIST_SQLSTAT S, DBA_HIST_SNAPSHOT SS 
where sql_id = nvl('${v_sqlid}','XXXXXXXXX') 
and ss.snap_id = S.snap_id 
and ss.instance_number = S.instance_number 
and executions_delta > 0 
order by 1, 2, 3 
/
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_tablestat()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear
echo -e "\n\t################# Check Table Statistics #################\n"
echo -e "\n\tEnter Table Name : \c"
read v_tname

sqlplus -s / as  sysdba <<EOF
SET FEEDBACK OFF
set colsep |
set lines 300 pages 1000
col LAST_ANALYZED for a16
col OWNER for a22 
col TABLE_NAME for a22
col PARTITION_NAME for a15 
col PARTITION_POSITION for 9999 
col OBJECT_TYPE for a12
col NUM_ROWS for 999999999 
col SAMPLE_SIZE for 999999999 
col GLOBAL_STATS for a12
col STALE_STATS for a12
alter session set container=$ORACLE_PDB_SID;
prompt
prompt ******************** $v_tname Statistics Details ********************
select to_char(LAST_ANALYZED,'DDMONYYYY HH24:MI') LAST_ANALYZED, OWNER, TABLE_NAME, PARTITION_NAME,PARTITION_POSITION,OBJECT_TYPE,NUM_ROWS,SAMPLE_SIZE, GLOBAL_STATS,STALE_STATS
from dba_tab_statistics where table_name in ('${v_tname}') order by 5,1 asc
/
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

echo -n "Enter your PDB name: "
read pdb1
export ORACLE_PDB_SID=$pdb1

while true; do
    clear
    echo -e "\t######### $ORACLE_PDB_SID:DB Perf Monitor Menu ########"
    echo -e "\n"
    echo -e "\t(1)  Check Active sessions                             "
    echo -e "\t(2)  Check Blocking session                            "
    echo -e "\t(3)  Check Temp usage                                  "
    echo -e "\t(4)  Check Undo Usage                                  "
    echo -e "\t(5)  Check DBA Registry status                         "
    echo -e "\t(6)  Invalid objects count                             "
    echo -e "\t(7)  Top CPU consuming sessions                        "
    echo -e "\t(8)  Top High Elapsed Time Queries                     "
    echo -e "\t(9)  Monitor parallel queries                          "
    echo -e "\t(10) Check Underscore parameter                        "
    echo -e "\t(11) View Xplain Plan for sql_id                       "
    echo -e "\t(12) View SQL Execution Plan History (planc)           "
    echo -e "\t(13) Check Table Statistics                            "
    echo -e "\t(14) Generate AWR/ADDM/ASH Reports                     "
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
        1) tput clear; get_CurSess_status ;;
        2) tput clear; get_block_Sess ;;
        3) tput clear; get_temp_use ;;
        4) tput clear; get_undo_use ;;
        5) tput clear; get_dbreg_Status ;;
        6) tput clear; get_invalid_Obj ;;
        7) tput clear; get_TopCPU ;;
        8) tput clear; get_high_elapse;;
        9) tput clear; get_px_sql ;;
        10) tput clear; get_undparam ;;
        11) tput clear; get_xplan ;;
        12) tput clear; get_planc ;;
        13) tput clear; get_tablestat ;;
        14) tput clear; sh DBReports.sh ;;
        0) echo "Exiting $ORACLE_PDB_SID pdb ..." ; export ORACLE_PDB_SID= ; exit 0 ;;
        *) echo "Invalid option. Please try again." ; read -n1 -r -p "Press any key to continue..." key ;;
    esac
done

