/* ---------------------------------------------------------------------------
Original script by http://damir-vadas.blogspot.in/2009/11/automated-awr-reports-in-oracle-10g11g.html
 Filename: create_awr_report_for_database.sql
 Purpose : In directory defined with v_dir, create awr reports for two snapshots, so scheduled it in crontab to run  AWR every
 Remarks : Run as privileged user
#  If No report generated in report folder (v_dir) create directory manually once before running the script.
 --------------------------------------------------------------------------- */
set serveroutput on
set linesize 166
set pagesize 600
set trimout on
set verify off
DECLARE
   CURSOR c_instance
   IS
        SELECT   instance_number, instance_name
          FROM   gv$instance
      ORDER BY   1;

   c_dir CONSTANT   VARCHAR2 (256) := '&4/Reports';
   v_dir            VARCHAR2 (256) := '&4/Reports/AWR_GLOBAL';
   v_type   VARCHAR2(24) := UPPER ('&5'); -- html or text 
   v_pdb            VARCHAR2 (10 ):= '&1';
   v_date           VARCHAR2 (25) := '&2';
   v_incr           NUMBER := &3;
   v_db_unique      v$database.db_unique_name%TYPE;
   v_dbid           v$containers.dbid%TYPE;
   v_dbname         v$containers.name%TYPE;
   v_inst_num       v$instance.instance_number%TYPE := 1;
   v_begin_snap     NUMBER;
   v_end_snap       NUMBER;
   v_start_time     VARCHAR2 (20);
   v_end_time       VARCHAR2 (20);
   v_options        NUMBER := 8;        -- 0=no options, 8=enable addm feature
   v_file           UTL_FILE.file_type;
   v_file_name      VARCHAR (50);

BEGIN
  -- get DB Unique Name
     SELECT  db_unique_name
     INTO v_db_unique
     FROM   v$database;

  -- get dbid , name for pdb
     select dbid,name
     INTO   v_dbid, v_dbname
     from v$containers where name = UPPER(v_pdb);

  -- get start snapshot id
     SELECT   MIN (snap_id)
     INTO   v_begin_snap
     FROM   CDB_HIST_SNAPSHOT
     WHERE  to_char (END_INTERVAL_TIME, 'YYYY/MM/DD HH24.MI') >= v_date and dbid = v_dbid;

  -- End snap id begin snap + incr value
   v_end_snap := v_begin_snap + v_incr;

     SELECT   TO_CHAR (END_INTERVAL_TIME, 'YYMMDD_HH24MI')
     INTO   v_start_time
     FROM   CDB_HIST_SNAPSHOT
     WHERE   snap_id = v_begin_snap AND instance_number = v_inst_num  and dbid = v_dbid;

     SELECT   TO_CHAR (END_INTERVAL_TIME, 'HH24MI')
     INTO   v_end_time
     FROM   CDB_HIST_SNAPSHOT
     WHERE   snap_id = v_end_snap AND instance_number = v_inst_num  and dbid = v_dbid;

 -- Display all variables
 -- DBMS_OUTPUT.put_line ('v_db_unique ' || v_db_unique);
 -- DBMS_OUTPUT.put_line ('v_dbid ' || v_dbid);
 -- DBMS_OUTPUT.put_line ('v_dbname ' || v_dbname);
 -- DBMS_OUTPUT.put_line ('v_date ' || v_date);
 -- DBMS_OUTPUT.put_line ('begin snap_id ' || v_begin_snap);
 -- DBMS_OUTPUT.put_line ('end snap_id ' || v_end_snap);
 -- DBMS_OUTPUT.put_line ('v_start_time ' || v_start_time);
 -- DBMS_OUTPUT.put_line ('v_end_time ' || v_end_time);

   -- Thanx to Yu Denis Sun - we must have directory defined as v_dir value!
execute immediate('create or replace directory awrdir as '''||v_dir||'''');
IF v_type = 'HTML' THEN
   -- let's go to real work...write awrs to files...
   DBMS_OUTPUT.put_line ( CHR(9) || 'Global RAC AWR HTML Report Generated For:' || v_db_unique || ' From:' || v_start_time || ' To:' || v_end_time ||' at:' || v_dir);
   v_file := UTL_FILE.fopen ('AWRDIR','awr_global_rac_'|| v_db_unique|| '_'|| v_dbname|| '_'|| v_start_time|| '_'|| v_end_time|| '.html','w',32767);
      FOR c_report
      IN (SELECT output FROM   TABLE(DBMS_WORKLOAD_REPOSITORY.awr_global_report_html( v_dbid,'', v_begin_snap,v_end_snap, v_options)))
      LOOP
         UTL_FILE.PUT_LINE (v_file, c_report.output);
      END LOOP;
   UTL_FILE.fclose (v_file);
 ELSE
   DBMS_OUTPUT.put_line ( CHR(9) || 'Global RAC AWR Text Report Generated For:' || v_db_unique || ' From:' || v_start_time || ' To:' || v_end_time ||' at:' || v_dir);
   v_file := UTL_FILE.fopen ('AWRDIR','awr_global_rac_'|| v_db_unique|| '_'|| v_dbname|| '_'|| v_start_time|| '_'|| v_end_time|| '.txt','w',32767);
      FOR c_report
      IN (SELECT output FROM   TABLE(DBMS_WORKLOAD_REPOSITORY.awr_global_report_text( v_dbid,'', v_begin_snap,v_end_snap, v_options)))
      LOOP
         UTL_FILE.PUT_LINE (v_file, c_report.output);
      END LOOP;
   UTL_FILE.fclose (v_file);
END IF;

EXECUTE IMMEDIATE ('drop directory AWRDIR');
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

