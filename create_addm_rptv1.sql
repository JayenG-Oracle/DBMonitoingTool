set serveroutput on size unlimited;
set linesize 166
set pagesize 600
set trimout on
set verify off
DECLARE
   v_dir      VARCHAR2 (256) := '&4/Reports/ADDM';
   v_task     VARCHAR2 (256);  -- Name of the task
   v_pdb   VARCHAR2 (10 ):= '&1';
   v_date  VARCHAR2 (25) := '&2';
   v_all_inst CHAR (1) := UPPER ('&3'); -- All instances (Y/N)
   v_inst     VARCHAR2 (10);   -- Instance number
   v_dbid  v$containers.dbid%TYPE;
   v_dbname  v$containers.name%TYPE;
   v_begin_snap     NUMBER;
   v_start_time     VARCHAR2 (20);
   v_end_time       VARCHAR2 (20);
   v_inst_num       v$instance.instance_number%TYPE := 1; 
   v_report      CLOB;
   v_buffer      VARCHAR2(32767);
   v_offset      NUMBER := 1;
   v_chunk_size  NUMBER := 32767;
   v_file        UTL_FILE.FILE_TYPE;
   V_CHAR_COUNT NUMBER;   -- To check report total lengh
   
BEGIN
  -- get dbid , name for pdb
     select dbid,name
     INTO   v_dbid, v_dbname
     from v$containers where name = UPPER(v_pdb);

  -- get start snapshot id
     SELECT   MIN (snap_id)
     INTO   v_begin_snap
     FROM   DBA_HIST_SNAPSHOT
     WHERE  to_char (END_INTERVAL_TIME, 'YYYY/MM/DD HH24.MI') >= v_date and dbid = v_dbid;

     SELECT   TO_CHAR (BEGIN_INTERVAL_TIME, 'YYYYMMDD_HH24MI')
     INTO   v_start_time
     FROM   DBA_HIST_SNAPSHOT
     WHERE   snap_id = v_begin_snap AND instance_number = v_inst_num  and dbid = v_dbid;

     SELECT   TO_CHAR (END_INTERVAL_TIME, 'HH24MI')
     INTO   v_end_time
     FROM   DBA_HIST_SNAPSHOT
     WHERE   snap_id = v_begin_snap AND instance_number = v_inst_num  and dbid = v_dbid;

--- Create directory in database
execute immediate('create or replace directory awrdir as '''||v_dir||'''');

   IF v_all_inst = 'Y' THEN
      -- Generate individual Instance ADDM Report
    FOR r_instance IN (SELECT instance_number, instance_name FROM gv$instance ORDER BY 1)
     LOOP
        DBMS_OUTPUT.put_line ( CHR(9) || 'ADDM Report Generated For '||v_dbname||'_'||to_CHAR(r_instance.instance_number) ||' From:'|| v_start_time ||' To:'|| v_end_time|| ' at:' || v_dir);  
        v_task := 'ADDM:'|| TO_CHAR(v_dbid) || '_' || to_char(r_instance.instance_number) || '_' ||TO_CHAR(v_begin_snap);
        -- dbms_output.put_line(v_task);     
        select dbms_advisor.get_task_report(task_name) into v_report FROM dba_advisor_tasks WHERE task_name = v_task;
        v_file := UTL_FILE.fopen ('AWRDIR', 'addm_'||v_dbname||'_'||to_CHAR(r_instance.instance_number) ||'_'|| v_start_time ||'_'|| v_end_time|| '.txt', 'W', 32767);

       -- Check Lenght of report 
       -- V_CHAR_COUNT := DBMS_LOB.getlength(v_report);
       -- DBMS_OUTPUT.PUT_LINE('Total report length is :' || V_CHAR_COUNT);

	-- Write CLOB data in chunks
       LOOP
          EXIT WHEN v_offset > DBMS_LOB.getlength(v_report);
          v_buffer := DBMS_LOB.substr(v_report, v_chunk_size, v_offset);
          UTL_FILE.put_raw(v_file, UTL_RAW.cast_to_raw(v_buffer));
          v_offset := v_offset + v_chunk_size;
       END LOOP;
    
	 -- Close file
       UTL_FILE.fclose(v_file);
 
        -- Reset  v_offset for next report in loop
          v_offset := 1;
     END LOOP;
   ELSE
      -- Generate Single ADDM Report include all instance
      v_task :='ADDM:'||TO_CHAR(v_dbid)||'_'||TO_CHAR(v_begin_snap) ;
      v_report := DBMS_ADVISOR.get_task_report (v_task,'TEXT','ALL');
     
      DBMS_OUTPUT.put_line ( CHR(9) || 'ADDM REPORT Generated For '||v_dbname||' ALL Instances From:'|| v_start_time ||' To:'|| v_end_time ||' at:' || v_dir  ); 

      -- Open file for writing
      v_file := UTL_FILE.fopen ('AWRDIR', 'addm_'||v_dbname||'_ALL_INST_'|| v_start_time ||'_'|| v_end_time ||'.txt', 'W', 32767);

      -- Write CLOB data in chunks
       LOOP
          EXIT WHEN v_offset > DBMS_LOB.getlength(v_report);
          v_buffer := DBMS_LOB.substr(v_report, v_chunk_size, v_offset);
          UTL_FILE.put_raw(v_file, UTL_RAW.cast_to_raw(v_buffer));
          v_offset := v_offset + v_chunk_size;
       END LOOP;    

       -- Close file
       UTL_FILE.fclose(v_file);
        -- Reset Offet value 
       v_offset := 1;
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
