set serveroutput on size unlimited;
set linesize 166
set pagesize 600
set trimout on
set verify off
DECLARE

   CURSOR c_instance
   IS SELECT instance_number, instance_name FROM  gv$instance ORDER BY   1;

   v_dir    VARCHAR2 (256) := '&6/Reports/ASH';
   v_type   VARCHAR2(24) := UPPER ('&5'); -- html or text
   v_option VARCHAR2(4) := UPPER ('&4'); -- ASH Global or ASH  
   v_file     UTL_FILE.FILE_TYPE;
   v_pdb          VARCHAR2 (10) := '&1';
   v_date1        VARCHAR2 (25) := '&2';
   v_date2        VARCHAR2 (25) := '&3';
   v_db_unique    v$database.db_unique_name%TYPE;
   v_dbid         number;
   v_dbname       v$containers.name%TYPE;
   v_start_time_1 VARCHAR2 (25);
   v_start_time_2 VARCHAR2 (25);

BEGIN
  -- get DB Unique Name
     SELECT  db_unique_name INTO v_db_unique  FROM   v$database;
  -- get dbid , name for pdb
     select dbid,name INTO  v_dbid, v_dbname from v$containers where name = UPPER('cdb$root');
   
  --  DBMS_OUTPUT.put_line ( v_dbid || ',' ||v_pdb || ',' ||v_inst_num1 ||   ',' || v_date1 || ',' || v_date2 ||','||v_dir  );
  SELECT TO_CHAR(TO_DATE(v_date1, 'YYYY/MM/DD HH24.MI'), 'YYMMDD_HH24MI') INTO v_start_time_1 FROM dual;
  SELECT TO_CHAR(TO_DATE(v_date2, 'YYYY/MM/DD HH24.MI'), 'HH24MI') INTO v_start_time_2 FROM dual;
--- Create directory
execute immediate('create or replace directory awrdir as '''||v_dir||'''');

IF v_option = 'N' THEN
     IF v_type = 'HTML' THEN 
       FOR v_instance IN c_instance
       LOOP
          DBMS_OUTPUT.put_line ( CHR(9) || 'ASH HTML Report Generated For Instance:' || v_pdb ||' From:' ||v_start_time_1 || ' To:'|| v_start_time_2|| ' at:'||v_dir );
          v_file := UTL_FILE.fopen ('AWRDIR','ashrpt_inst_' || v_instance.instance_number ||'_'|| v_pdb||'_' ||v_start_time_1 || '_'|| v_start_time_2||'.html', 'w', 32767 );
          FOR c_report
          IN (SELECT output FROM TABLE(dbms_workload_repository.ash_report_html(l_dbid => v_dbid, l_inst_num => v_instance.instance_number,l_btime => v_date1,l_etime => v_date2,l_container =>v_pdb)))
          LOOP
             UTL_FILE.PUT_LINE (v_file, c_report.output);
          END LOOP;
          UTL_FILE.fclose (v_file);
        END LOOP;
      ELSE
        FOR v_instance IN c_instance
        LOOP     
          DBMS_OUTPUT.put_line ( CHR(9) || 'ASH text Report Generated For:' || v_pdb ||'_' ||v_start_time_1 || '_'|| v_start_time_2|| ' at:'||v_dir );
          v_file := UTL_FILE.fopen ('AWRDIR','ashrpt_inst_' || v_instance.instance_number ||'_'|| v_pdb||'_' ||v_start_time_1 || '_'|| v_start_time_2||'.txt', 'w', 32767 );
          FOR c_report
          IN (SELECT output FROM TABLE(dbms_workload_repository.ash_report_text(l_dbid => v_dbid, l_inst_num => v_instance.instance_number,l_btime => v_date1,l_etime => v_date2,l_container =>v_pdb)))
          LOOP
             UTL_FILE.PUT_LINE (v_file, c_report.output);
          END LOOP;
          UTL_FILE.fclose (v_file);
        END LOOP;
    END IF;
  ELSE
   IF v_type = 'HTML' THEN 
    DBMS_OUTPUT.put_line ( CHR(9) || 'ASH HTML Global Report Generated For:' || v_pdb ||' From:' ||v_start_time_1 || ' To:'|| v_start_time_2|| ' at:'||v_dir );
    v_file := UTL_FILE.fopen ('AWRDIR','ashrpt_global_'|| v_pdb||'_' ||v_start_time_1 || '_'|| v_start_time_2||'.html', 'w', 32767 );
    FOR c_report
     IN (SELECT output FROM TABLE(dbms_workload_repository.ash_global_report_html(l_dbid => v_dbid, l_inst_num => '',l_btime => v_date1,l_etime => v_date2,l_container =>v_pdb)))
       LOOP
        UTL_FILE.PUT_LINE (v_file, c_report.output);
        END LOOP;
       UTL_FILE.fclose (v_file);

      ELSE     
          DBMS_OUTPUT.put_line ( CHR(9) || 'ASH Text Gloabl Report Generated For Instance:' || v_pdb ||'_' ||v_start_time_1 || '_'|| v_start_time_2|| ' at:'||v_dir );
          v_file := UTL_FILE.fopen ('AWRDIR','ashrpt_global_' || v_pdb||'_' ||v_start_time_1 || '_'|| v_start_time_2||'.txt', 'w', 32767 );
          FOR c_report
          IN (SELECT output FROM TABLE(dbms_workload_repository.ash_global_report_text(l_dbid => v_dbid, l_inst_num => '',l_btime => v_date1,l_etime => v_date2,l_container =>v_pdb)))
          LOOP
             UTL_FILE.PUT_LINE (v_file, c_report.output);
          END LOOP;
          UTL_FILE.fclose (v_file);  
  END IF;
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
