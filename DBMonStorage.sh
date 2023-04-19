#!/bin/bash
#
#    NAME																  #
#      DBMonStorage.sh                                                    #
#                                                                         #
#    DESCRIPTION  :                                                       #
#       This shell script provides details about storage                  #
#      Storage Overview                                                   #
#	 Host Mount point Utilization 		                          #
#	 ASM Space Utilization                  	                  #
#	 Database Storage Structure                     	          #
#	 Tablespace Utilization                                 	  #
#
# Author:   Jayendra Ghoghari					        ### 
# Created:  31-03-2023  version V1 					###

MC=`uname -a|awk '{print $2}'|tr 'a-z' 'A-Z'`
MENU_NAME=${MENU_NAME:-"DBA Menu - $MC"}  

get_db_files()
{
rep=""
while [ "$rep" != "q" ]
do
sqlplus -s / as sysdba <<EOF
set pagesize 500
set linesize 500
set feedback off
Prompt
prompt ******************** Control Files Location ********************
col name  format a60 heading "Control Files"
select name from v\$controlfile
/

Prompt
prompt ******************** Redo Log File Location ********************
col group# format 999
col MEMBER format a60 heading "Redo Log File Name"
col STATUS  format a10
COL archived format a10
col SizeMB format 99999 HEAD 'Size In MB'
break on Grp
select  l.thread#,l.group#, f.member member,l.archived,l.status,bytes/1024/1024 SizeMB
    from v\$log l join v\$logfile f
    on l.group#=f.group#
    order by l.thread#,l.group#
/
Prompt
prompt ******************** Data File Location ********************
col con_id for 99999
col Tspace    format a22
col status    format a10  heading Status
col Id        format 9999
col SizeMB     format 999999999 HEAD 'Size In MB'
col name      format a110 heading "Data Files"
col Autoextend format a12  
break on report skip 1
compute sum label "Total: " of SizeMB on report
select f.con_id,F.file_id Id,F.tablespace_name Tspace,
       F.file_name name,
       F.status ,
       AUTOEXTENSIBLE Autoextend,
       F.bytes/(1024*1024)SizeMB 
from   sys.cdb_data_files F
union all
select tf.con_id, TF.file_id Id,TF.tablespace_name Tspace,
       TF.file_name name,
       TF.status ,
       TF.AUTOEXTENSIBLE Autoextend,
       TF.bytes/(1024*1024)SizeMB
from   sys.cdb_temp_files TF
order by 1,3;
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}

get_tbs_status()
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

get_ASM_Status()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
sqlplus -s / as  sysdba <<EOF
SET LINESIZE  145
SET PAGESIZE  9999
SET VERIFY    off
SET FEEDBACK OFF;
COLUMN group_name             FORMAT a20                                         HEAD 'Disk Group|Name'
COLUMN sector_size            FORMAT 99,999                                        HEAD 'Sector|Size'
COLUMN block_size             FORMAT 99,999                        HEAD 'Block|Size'
COLUMN allocation_unit_size   FORMAT 999,999,999                      HEAD 'Allocation|Unit Size'
COLUMN state                  FORMAT a11                                   HEAD 'State'
COLUMN type                   FORMAT a6                                      HEAD 'Type'
COLUMN total_mb               FORMAT 999,999,999,999    HEAD 'Total Size (MB)'
COLUMN used_mb                FORMAT 999,999,999                            HEAD 'Used Size (MB)'
COLUMN free_mb                FORMAT 999,999,999                              HEAD 'Free Size (MB)'
COLUMN pct_used               FORMAT 999,99                        HEAD 'Pct. Used'
break on report on disk_group_name skip 1
compute sum label "Grand Total: " of total_mb used_mb free_mb on report
prompt ******************** ASM details ********************
SELECT
    name                                     group_name
  , sector_size                              sector_size
  , block_size                               block_size
  , allocation_unit_size                     allocation_unit_size
  , state                                    state
  , type                                     type
  , total_mb                                 total_mb
  , (total_mb - free_mb)                     used_mb
  , free_mb                                  free_mb
  , ROUND((1- (free_mb / total_mb))*100, 2)  pct_used
FROM     v\$asm_diskgroup
ORDER BY     name;
prompt
EOF
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}
 
get_host_file_system()
{
rep=""
while [ "$rep" != "q" ]
do
tput clear;
echo -e "\t ********************$(hostname) File system Utilization ********************"
echo -e "\n" 
df -h | sed 's/^/\t/'
echo -e "\n"
ALERT=80
df -h | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 " " $6}' | while read -r output;
do
  usep=$(echo "$output" | awk '{ print $1}' | cut -d'%' -f1 )
  partition=$(echo "$output" | awk '{ print $3 }' )
  if [ $usep -ge $ALERT ]; then
  echo -e "\tFile system Utilization above 80%"
  echo -e "\tMount point :\"$partition is ($usep%) utilized\" on $(hostname) as on $(date)" 
  echo -e "\n"
  fi
done
echo -e " Press Enter to refresh ("q" to return to main menu): \c"
read rep
done
}


###The choice loop
while [ 1 ]        
do
 tput clear
 echo -e "\n"
        echo -e "\t"
        echo -e "\t#######################################################"
        echo -e "\t\t\tStorage Menu\t"
        echo -e "\t#######################################################"
        echo -e "\t"
	echo -e "\t(1) Host Mount point Utilization                       "
	echo -e "\t(2) ASM Space Utilization                              "
	echo -e "\t(3) Database Storage Structure                         "
        echo -e "\t(4) Tablespace Utilization                             "
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
                1) tput clear; get_host_file_system ;;
                2) tput clear; get_ASM_Status ;;
                3) tput clear; get_db_files ;;
                4) tput clear; get_tbs_status ;;
        esac
done                               

