This repository contains a set of shell scripts that provide menu-driven SQL scripts for monitoring daily DBA activities on Oracle databases version 12c and above, including multitenant databases.

Before using the scripts for the first time, create a "Reports" directory in the DBMonitoringTool directory and the following sub-directories inside the Reports directory for database reports: ADDM, ASH, AWR, AWR_GLOBAL, AWR_DIFF, AWR_DIFF_GLOBAL, and SQLRPT. Please note that the directory names are case sensitive.

To use the scripts, run the following command:
sh DBMonitorMain.sh

Features include:

1- Host Overview                             
	+ Host details                           
	+ CPU , Memory & File system  details	
2- Storage Overview                          
    + Host Mount point Utilization           
    + ASM Space Utilization                  
    + Database Storage Structure             
    + Tablespace Utilization                 
3- Database Overview (CDB Level)             
    + Check Database Overview                
    + Check Backup Status                    
    + Check Standby Sync Status              
    + Check CDB Tablespace                   
    + Check Archive generation per hour      
    + Check Database Flashback Status        
    + Check Database Registry Status		
4- Connect Pluggable Database (PDB Level)    
    + Check PDB Status and Uptime            
    + Check PDB Tablespace                   
    + Check Scheduler Job  status            
    + Scheduler Job Errors last 3 Days       
    + Check Current Active Sesssions         
    + Check Current wait events              
5- Database Performance Hub                  
    + Check Active sessions                  
    + Check Blocking session                 
    + Check Temp usage                       
    + Check Undo Usage                       
    + Check DBA Registry status              
    + Invalid objects count                  
    + Top CPU consuming sessions             
    + Top High Elapsed Time Queries          
    + Monitor parallel queries               
    + Check Underscore parameter             
    + View Xplain Plan for sql_id            
    + View SQL Execution Plan History (planc)
    + Generate AWR/ADDM/ASH Reports 
               




