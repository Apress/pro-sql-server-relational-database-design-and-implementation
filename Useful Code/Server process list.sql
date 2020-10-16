select  des.session_id, des.login_name, des.login_time, des.program_name,
           des.original_login_name, des.nt_user_name,
		des.cpu_time, 
		des.total_scheduled_time, des.total_elapsed_time,
		       case des.transaction_isolation_level
            when 0 then 'Unspecified' when 1 then 'ReadUncomitted'
            when 2 then 'ReadCommitted' when 3 then 'Repeatable'
            when 4 then 'Serializable' when 5 then 'Snapshot'
      end as transaction_isolation_level,
	  des.last_request_start_time, des.reads, des.writes, des.logical_reads,

	   der.session_id, der.blocking_session_id, der.wait_type, der.wait_time,
       der.start_time, DATEDIFF(second,der.start_time,GETDATE())/60.0 AS executeTime_Minutes,
	   der.percent_complete,
       der.status as requestStatus, 
       cast(db_name(der.database_id) as varchar(30)) as databaseName,
       der.command as commandType,
       der.percent_complete,
	   char(13) + char(10) + '-------Current Command-----------' + char(13) + char(10) + 
	   case when der.statement_end_offset = -1 then '--see objectText--'
						 else SUBSTRING(execText.text, der.statement_start_offset/2, 
											  (der.statement_end_offset - der.statement_start_offset)/2) 
				   end + char(13) + char(10) + '------Full Object------------' AS currentExecutingCommand,
       execText.text as objectText,
	   execPlan.query_plan

from sys.dm_exec_sessions des --returns information about each user and internal system session on a SQL Server 
							  --instance including session settings, security, and cumulative CPU, memory, and I/O usage
        left outer join sys.dm_exec_requests as der			  --The sys.dm_exec_requests DMV shows us what is currently running
            on der.session_id = des.session_id		  --on the SQL Server instance, its impact on memory, CPU, disk, and cache.
        outer apply sys.dm_exec_sql_text(der.sql_handle) as execText
		outer APPLY sys.dm_exec_query_plan (der.sql_handle) AS execPlan
where --des.session_id <> @@spid and --eliminate the current connection
      des.session_id > 40

select  der.session_id, der.blocking_session_id, der.wait_type, der.wait_time,
        der.start_time, DATEDIFF(second,der.start_time,GETDATE())/60.0 AS executeTime_Minutes,
		percent_complete,
        der.status as requestStatus, 
        des.login_name, 
        cast(db_name(der.database_id) as varchar(30)) as databaseName,
        des.program_name,
        der.command as commandType,
        der.percent_complete,
        case des.transaction_isolation_level
            when 0 then 'Unspecified' when 1 then 'ReadUncomitted'
            when 2 then 'ReadCommitted' when 3 then 'Repeatable'
            when 4 then 'Serializable' when 5 then 'Snapshot'
        end as transaction_isolation_level,
		char(13) + char(10) + '-------Current Command-----------' + char(13) + char(10) + 
		case when der.statement_end_offset = -1 then '--see objectText--'
						 else SUBSTRING(execText.text, der.statement_start_offset/2, 
											  (der.statement_end_offset - der.statement_start_offset)/2) 
        end + char(13) + char(10) + '------Full Object------------' AS currentExecutingCommand,
        execText.text as objectText,
		
	   execPlan.query_plan
from sys.dm_exec_sessions des --returns information about each user and internal system session on a SQL Server 
							  --instance including session settings, security, and cumulative CPU, memory, and I/O usage
        join sys.dm_exec_requests as der			  --The sys.dm_exec_requests DMV shows us what is currently running
            on der.session_id = des.session_id		  --on the SQL Server instance, its impact on memory, CPU, disk, and cache.
        outer apply sys.dm_exec_sql_text(der.sql_handle) as execText
		
		outer APPLY sys.dm_exec_query_plan (der.plan_handle) AS execPlan
where --des.session_id <> @@spid and --eliminate the current connection
      des.session_id > 40


