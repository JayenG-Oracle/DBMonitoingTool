set serveroutput on size unlimited;
set linesize 166
set pagesize 600
set trimout on
set verify off
DECLARE
   v_dir      VARCHAR2 (256) := '&8/Reports/AWR_DIFF';
   v_type   VARCHAR2(24) := UPPER ('&6'); -- html or text 
   v_file     UTL_FILE.FILE_TYPE;
   v_pdb          VARCHAR2 (10) := '&1';
   v_inst_num1    NUMBER := '&2';
   v_inst_num2    NUMBER := '&3';
   v_date1        VARCHAR2 (25) := '&4';
   v_date2        VARCHAR2 (25) := '&5'; 
   v_incr         NUMBER := '&7' ;
   v_db_unique    v$database.db_unique_name%TYPE;
   v_dbid         v$containers.dbid%TYPE;
   v_dbname       v$containers.name%TYPE;
   v_bsnap1       NUMBER;
   v_esnap1       NUMBER;
   v_bsnap2       NUMBER;
   v_esnap2       NUMBER;
   v_start_time_1 VARCHAR2 (25);
   v_start_time_2 VARCHAR2 (25);
   v_end_time_1   VARCHAR2 (25);
   v_end_time_2   VARCHAR2 (25);

BEGIN
  -- get DB Unique Name
     SELECT  db_unique_name INTO v_db_unique  FROM   v$database;
  -- get dbid , name for pdb
     select dbid,name INTO   v_dbid, v_dbname from v$containers where name = UPPER(v_pdb);
  -- get start snapshot id for first date 
     SELECT   MIN (snap_id) INTO v_bsnap1 FROM CDB_HIST_SNAPSHOT WHERE  to_char (END_INTERVAL_TIME, 'YYYY/MM/DD HH24.MI') >= v_date1 and dbid = v_dbid;
  -- End snap id begin snap + incr value
     v_esnap1 := v_bsnap1 + v_incr;
  -- get start snapshot id from second date 
     SELECT   MIN (snap_id) INTO v_bsnap2 FROM CDB_HIST_SNAPSHOT WHERE  to_char (END_INTERVAL_TIME, 'YYYY/MM/DD HH24.MI') >= v_date2 and dbid = v_dbid;
  -- End snap id begin snap + incr value
     v_esnap2 := v_bsnap2 + v_incr;

    SELECT TO_CHAR (END_INTERVAL_TIME, 'YYMMDD_HH24') INTO v_start_time_1 FROM CDB_HIST_SNAPSHOT WHERE snap_id = v_bsnap1 AND instance_number = v_inst_num1 and dbid = v_dbid;
    SELECT TO_CHAR (END_INTERVAL_TIME, 'HH24') INTO v_end_time_1 FROM CDB_HIST_SNAPSHOT WHERE snap_id = v_esnap1 AND instance_number = v_inst_num1 and dbid = v_dbid;
    SELECT TO_CHAR (END_INTERVAL_TIME, 'YYMMDD_HH24') INTO v_start_time_2 FROM CDB_HIST_SNAPSHOT WHERE snap_id = v_bsnap2 AND instance_number = v_inst_num2 and dbid = v_dbid;
    SELECT TO_CHAR (END_INTERVAL_TIME, 'HH24') INTO v_end_time_2 FROM CDB_HIST_SNAPSHOT WHERE snap_id = v_esnap2 AND instance_number = v_inst_num2 and dbid = v_dbid;
   
-- DBMS_OUTPUT.put_line ( v_dbid || ',' ||v_inst_num1 || ',' ||v_bsnap1 || ',' || v_esnap1|| ',' || v_inst_num2 || ',' || v_bsnap2 || ',' || v_esnap2 );

--- Create directory 
execute immediate('create or replace directory awrdir as '''||v_dir||'''');
IF v_type = 'HTML' THEN
      DBMS_OUTPUT.put_line ( CHR(9) || 'AWR DIFF HTML Report Generated For:' ||v_dbname|| '_' ||v_inst_num1||'_'||v_start_time_1||'_'||v_end_time_1||'_' ||v_inst_num2||'_'||v_start_time_2||'_'||v_end_time_2|| ' at:'||v_dir );
      v_file :=  UTL_FILE.fopen ( 'AWRDIR','awrdiff_'||v_dbname|| '_' ||v_inst_num1||'_'||v_start_time_1||'_'||v_end_time_2||'_'||v_inst_num2||'_'||v_start_time_2||'_'||v_end_time_2|| '.html','w',32767 );
       FOR c_report
      IN (SELECT   output
            FROM   TABLE ( DBMS_WORKLOAD_REPOSITORY.AWR_DIFF_REPORT_HTML (v_dbid,v_inst_num1,v_bsnap1,v_esnap1,v_dbid,v_inst_num2,v_bsnap2,v_esnap2)))
      LOOP
         UTL_FILE.PUT_LINE (v_file, c_report.output);
      END LOOP;
      UTL_FILE.fclose (v_file);
 
  ELSE
    DBMS_OUTPUT.put_line ( CHR(9)|| 'AWR DIFF Text Report Generated For:' ||v_dbname|| '_' ||v_inst_num1||'_'||v_start_time_1||'_'||v_end_time_1||'_' ||v_inst_num2||'_'||v_start_time_2||'_'||v_end_time_2|| ' at:'||v_dir );
     v_file :=  UTL_FILE.fopen ( 'AWRDIR','awrdiff_'||v_dbname|| '_' ||v_inst_num1||'_'||v_start_time_1||'_'||v_end_time_2||'_'||v_inst_num2||'_'||v_start_time_2||'_'||v_end_time_2||'.txt','w',32767 );
       FOR c_report
       IN (SELECT   output
            FROM   TABLE ( DBMS_WORKLOAD_REPOSITORY.AWR_DIFF_REPORT_TEXT (v_dbid,v_inst_num1,v_bsnap1,v_esnap1,v_dbid,v_inst_num2,v_bsnap2,v_esnap2)))
       LOOP
         UTL_FILE.PUT_LINE (v_file, c_report.output);
       END LOOP;
      UTL_FILE.fclose (v_file);
END IF;
EXCEPTION
   WHEN OTHERS
   THEN
      DBMS_OUTPUT.PUT_LINE (SQLERRM);
      IF UTL_FILE.is_open (v_file)
      THEN
         UTL_FILE.fclose (v_file);
      END IF;

      BEGIN
      EXECUTE IMMEDIATE ('drop directory AWRDIR');
      EXCEPTION
         WHEN OTHERS
         THEN
            NULL;
      END;
END;
/
exit;
