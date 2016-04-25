-- *** CLEANUP / SETUP ***

-- Set theme in Sublime to: Mac Classic (restore to Monokai)
-- Set theme in Terminal to: Basic (restore to Homebrew)
-- Ask for feedback!!!
-- Setup Demo App and Demo Code
-- Enlarge text
-- VBoxManage guestproperty set "fcapex421" "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold" 1000
-- Launch Mosepose
-- Launch Demo APEX
-- Launch Final APEX
-- Reset DEMO pkg

-- TODO export final and vanilla apps
-- TODO put this all in a PPT like Tom Kyte does

-- CLOSE unnecssary apps

-- SETUP
-- - Open Chocolat (and files in it)
-- - SQL Dev Text Size
-- - iTerm2 Text Size

select sysdate from dual;


sqlcl giffy/giffy@localhost:11521/xe 
  set serveroutput on
;

begin
  delete from logger_apps;

  update logger_prefs
  set pref_value = 'FALSE'
  where pref_name = 'PROTECT_ADMIN_PROCS';


  update logger_prefs
  set pref_value = 'FALSE'
  where pref_name = 'LOGGER_DEBUG';

  logger_demo_cleanup;

  commit;
end;
/

exec logger_configure;

select sysdate from dual;
;

-- Build
cd /Users/giffy/Documents/GitHub/Logger---A-PL-SQL-Logging-Utility/build
./build.sh 3.0.0
cd /Users/giffy/Documents/GitHub/Logger---A-PL-SQL-Logging-Utility/releases/3.0.0




-- *** Install ***
-- Show where to download
cd /Users/giffy/Documents/GitHub/Logger/releases/3.1.1

sqlcl giffy/giffy@localhost:11521/xe

set serveroutput on
@logger_install.sql




create or replace procedure logger_demo_cleanup
as
begin
  logger.purge_all;
  logger.set_level('DEBUG');

  delete  from logger_logs;
  commit;

  update logger_prefs
  set pref_value = 'FALSE'
  where pref_name = 'PROTECT_ADMIN_PROCS';

  update logger_prefs
  set pref_value = 'NONE'
  where 1=1
    and pref_name like 'PLUGIN_FN%';

  commit;
end logger_demo_cleanup;
/

exec logger_demo_cleanup;







-- *** BASIC DEMO ***
exec logger.log('Hello world!');

select logger_level, text, time_stamp
from logger_logs
order by id;



-- *** LEVELS ***
begin
  logger_demo_cleanup;

  logger.log_error('Error');
  logger.log_warning('Warning');
  logger.log_information('Information');
  logger.log('debug');
end;
/

select logger_level, text, time_stamp
from logger_logs
order by id
;










-- Only log Warnings
begin
  logger_demo_cleanup;
  logger.set_level('WARNING');

  logger.log_error('Error');              -- LOGGED
  logger.log_warning('Warning');          -- LOGGED
  logger.log_information('Information');  -- NOT LOGGED
  logger.log('debug');                    -- NOT LOGGED
end;
/


select logger_level, text, time_stamp
from logger_logs
order by id
;









-- All Logger fields
select *
from logger_logs;














-- Scope
begin
  logger_demo_cleanup;

  logger.log('No Scope');
  logger.log('Scope included', 'my_scope');

end;
/

-- Explain why use scope

select logger_level, text, time_stamp, scope
from logger_logs
where 1=1
--  and scope = 'my_scope'
order by id
;







-- *** WHEN IS IT SAVED? ***
-- When is content saved to the logger_logs table?
begin
  logger_demo_cleanup;

  logger.log('Before rollback');
  rollback;
  logger.log('After rollback');
end;
/

select logger_level, text, time_stamp
from logger_logs
order by id
;







-- *** ADVANCED FUNCTIONS ***




-- *** SET LEVEL ***
-- Demoed this before but will highlight for good measure

begin
  logger_demo_cleanup;
  logger.set_level('ERROR');

  logger.log_error('Error');
  logger.log_warning('Warning');
  logger.log_information('Information');
  logger.log('debug');
end;
/


select logger_level, text, time_stamp
from logger_logs
order by id
;






/*
- #1 Feature request for 2.0.0 Client specific logging
  - Discuss how we looked at this
*/
-- Client Identifier
select sys_context('userenv','client_identifier')
from dual;

exec dbms_session.set_identifier('Martin COUG');

select sys_context('userenv','client_identifier')
from dual;

exec dbms_session.clear_identifier;




-- Simple procedure
create or replace procedure logger_test_levels(p_scope in logger_logs.scope%type)
as
begin
  logger.log_error('Error', p_scope);
  logger.log_warning('Warning', p_scope);
  logger.log_information('Information', p_scope);
  logger.log('debug', p_scope);
end logger_test_levels;
/


-- Production setup
begin
  logger_demo_cleanup;
  dbms_session.clear_identifier;
  logger.set_level('ERROR');
end;
/

-- SQL Developer
exec logger_test_levels(p_scope => 'sqldev');

select logger_level, text, time_stamp, scope
from logger_logs
order by id
;




-- IN TERMINAL
clear screen
exec dbms_session.set_identifier('sqlplus');

exec logger.set_level('DEBUG', 'sqlplus');

exec logger_test_levels(p_scope => 'sqlplus');


select logger_level, text, time_stamp, scope
from logger_logs
order by id
;


-- Back in SQL Dev (just to prove it's still in Error mode)
exec logger_test_levels(p_scope => 'sqldev');

select logger_level, text, time_stamp, scope
from logger_logs
order by id
;

-- In SQL Plus
exec logger.status;
-- Highlight the client specific options

exec logger.unset_client_level_all;

-- In SQL*Plus
exec logger_test_levels(p_scope => 'sqlplus (no client id logger config)');

select logger_level, text, time_stamp, scope
from logger_logs
order by id
;









-- *** FUNCTIONAL DEMOS ***




-- *** PRODUCTION LARGE BATCH SCRIPTS ***

-- Highligh enable/disable during live batch jobs.

create or replace procedure run_long_batch(
  p_client_id in varchar2,
  p_iterations in pls_integer)
as
  l_params logger.tab_param;
  l_scope logger_logs.scope%type := 'run_long_batch';
begin
  logger.append_param(l_params, 'p_client_id', p_client_id);
  logger.append_param(l_params, 'p_iterations', p_iterations);
  logger.log('START', l_scope, null, l_params);


  dbms_session.set_identifier(p_client_id);

  for i in 1..p_iterations loop
    logger.log('i: ' || i, l_scope);
    dbms_lock.sleep(1);
  end loop;

  logger.log('END');

end run_long_batch;
/


-- Setup
begin
  logger_demo_cleanup;
  logger.set_level('ERROR'); -- Simulates Production
  logger.unset_client_level_all;
end;
/



-- In SQL Plus
begin
  run_long_batch(p_client_id => 'sqlplus', p_iterations => 50);
end;
/


-- In SQL Dev
exec logger.set_level('DEBUG', 'sqlplus');

exec logger.unset_client_level('sqlplus');

exec logger.set_level('DEBUG', 'sqlplus');

exec logger.unset_client_level('sqlplus');

select logger_level, line_no, text, time_stamp, scope
from logger_logs
order by id
;










-- *** ONLY LOG I NECESSARY ***


create or replace procedure logger_test_loops
as
  l_num_loops pls_integer := 1000;
begin
  logger_demo_cleanup;

  -- **** HIGHLIGHT THiS ***
  logger.set_level('ERROR');
  -- ...

  logger.log('Starting to loop over array');

  -- Simulating array
  for i in 1..l_num_loops loop
    logger.log('Row: ' || i);
  end loop;

  -- ...
end logger_test_loops;
/

exec logger_test_loops;

select logger_level, text, time_stamp, scope
from logger_logs
order by id
;


-- Don't loop if we don't have to.
create or replace procedure logger_test_loops
as
  l_num_loops pls_integer := 1000;
begin

  -- ...

  logger.log('Starting to loop over array');

  -- Simulating array
  if logger.ok_to_log(p_level => 'DEBUG') then
    for i in 1..l_num_loops loop
      logger.log('Row: ' || i);
    end loop;
  end if;

  -- ...
end logger_test_loops;
/

begin
  logger_demo_cleanup;
  logger.set_level('ERROR');
  logger_test_loops;
end;
/

select logger_level, text, time_stamp, scope
from logger_logs
order by id
;









-- *** LOG_PARAMS ***

create or replace procedure logger_test_params(
  p_number in number,
  p_boolean in boolean,
  p_date in date)
as
  l_scope logger_logs.scope%type := lower($$plsql_unit);
begin
  logger_demo_cleanup;

  -- Notice the different syntax etc
  logger.log('START', l_scope);
  logger.log('p_number: ' || to_char(p_number), l_scope);
  logger.log('p_boolean  - ' || case when p_boolean then 'TRUE' else 'False' end, l_scope);
  logger.log('p_date ' || to_char(p_date, 'DD-MON-YY'), l_scope);

  -- ...

  logger.log('END');
end logger_test_params;
/


exec logger_test_params(1, false, sysdate);

select logger_level, text, time_stamp, scope
from logger_logs
order by id
;







create or replace procedure logger_test_params(
  p_number in number,
  p_boolean in boolean,
  p_date in date)
as
  l_scope logger_logs.scope%type := lower($$plsql_unit);

  l_params logger.tab_param;
begin
  logger_demo_cleanup;

  logger.append_param(l_params, 'p_number', p_number);
  logger.append_param(l_params, 'p_boolean', p_boolean);
  logger.append_param(l_params, 'p_date', p_date);
  logger.log('Hi', l_scope, null, l_params);

  logger.log('END');
end logger_test_params;
/

exec logger_test_params(1, false, sysdate);

select logger_level, text, time_stamp, scope, extra
from logger_logs
order by id
;













-- **** PLUGINS **** (Not Available Yet)


create or replace procedure logger_plugin_demo(p_logger_logs in logger.rec_logger_logs) as
begin
  dbms_output.put_line('Logger Plugin. ID: ' || p_logger_logs.id);
end;
/

begin
  logger_demo_cleanup;

  update logger_prefs
  set pref_value = 'logger_plugin_demo'
  where 1=1
    and pref_name = 'PLUGIN_FN_LOG';

  commit;
end;
/


-- MUST do this in order for change to take affect
-- Still work in progress so may not be required
exec logger_configure;


set serveroutput on
exec logger.log('test w. custom function');


select id, logger_level, text, time_stamp
from logger_logs
order by id
;






-- Different views to help you out.

select *
from logger_logs_5_min;

select *
from logger_logs_60_min;

-- *** TODO ***

-- TIMER?


-- APEX
begin
  logger_demo_cleanup;
  logger.set_level('ERROR');
  delete from logger_apps;
  logger.unset_client_level_all;
  commit;
end;
/











-- *** APEX ERROR HANDLING and LOGGER ***

-- Show the page 1 process


-- Set it up like prod
begin
  logger_demo_cleanup;
  logger.set_level('ERROR');
end;
/

pkg_logger_demo_apex.f_apex_error_handler
;

-- *** ERROR MESSAGE ***


-- TODO: ERROR_MESSAGES
-- No error message
--      l_return.message := 'An unexpected error has occurred. Please contact the system administrator';
--      l_return.message := 'Oops, something went wrong.
--        Not to worry, we''ve logged this issue and are working on it.
--        If you want to follow up on this issue with our support team
--        please contact support@clarifit.com and with reference# ' || l_ref_num;
--      logger.log_error('Unhandled Exception', 'error: {type: apex, refNum: ' || l_ref_num || '}');





-- *** AUTO SET LEVEL MESSAGE ***
begin
  logger_demo_cleanup;
  logger.set_level('ERROR');
end;
/

-- Set this session into debug mode from now on to see what's going on (just for one hour)
      logger.set_level(
        p_level => 'DEBUG',
        p_client_id => sys_context('userenv','client_identifier'),
        p_include_call_stack => 'TRUE',
        p_client_id_expire_hours => 1);

-- View level configs in APEX
select *
from logger_prefs_by_client_id;


update logger_prefs
set pref_value = 'FALSE'
where pref_name = 'PROTECT_ADMIN_PROCS';

commit;







-- APPLICATION SPECIFIC
-- Show initialization code there (and have a custom table that says which applications should always have this on)

drop table logger_apps;

create table logger_apps(
  application_id number not null,
  logger_level varchar2(30) not null,
  constraint logger_apps_pk primary key (application_id)
);

begin
  logger_demo_cleanup;
  logger.set_level('ERROR');
  logger.unset_client_level_all;
end;
/

-- Set VPD

-- pkg_logger_demo_apex.set_logger_level_by_app(p_application_id => :APP_ID);
pkg_logger_demo_apex.set_logger_level_by_app(p_application_id => :APP_ID);

select *
from logger_apps;







-- *** TODO ***
-- *** TODO ***


-- TODO too much?

-- *** LOG_USERENV ***

begin
  logger_demo_cleanup;
  logger.log_userenv();
  logger.log_userenv('ALL'); -- -- ALL, NLS, USER, INSTANCE
end;
/

select logger_level, text, extra
from logger_logs
order by id
;





/*
CURRENT_SCHEMA                : GIFFY
SESSION_USER                  : GIFFY
OS_USER                       : giffy
IP_ADDRESS                    : 10.0.2.2
HOST                          : Martins-MacBook-Air.local
TERMINAL                      : unknown
AUTHENTICATED_IDENTITY        : GIFFY
AUTHENTICATION_METHOD         : PASSWORD
IDENTIFICATION_TYPE           : LOCAL
ISDBA                         : FALSE
*/


/*
NLS_CALENDAR                  : GREGORIAN
NLS_CURRENCY                  : $
NLS_DATE_FORMAT               : DD-MON-RR HH24:MI:SS
NLS_DATE_LANGUAGE             : AMERICAN
NLS_SORT                      : BINARY
NLS_TERRITORY                 : AMERICA
LANG                          : US
LANGUAGE                      : AMERICAN_AMERICA.AL32UTF8
CURRENT_SCHEMA                : GIFFY
SESSION_USER                  : GIFFY
OS_USER                       : giffy
IP_ADDRESS                    : 10.0.2.2
HOST                          : Martins-MacBook-Air.local
TERMINAL                      : unknown
AUTHENTICATED_IDENTITY        : GIFFY
AUTHENTICATION_METHOD         : PASSWORD
IDENTIFICATION_TYPE           : LOCAL
ISDBA                         : FALSE
DB_NAME                       : XE
DB_UNIQUE_NAME                : XE
INSTANCE                      : 1
INSTANCE_NAME                 : XE
SERVER_HOST                   : localhost
SERVICE_NAME                  : SYS$USERS
CURRENT_SCHEMAID              : 50
FG_JOB_ID                     : 0
GLOBAL_CONTEXT_MEMORY         : 1192
MODULE                        : SQL Developer
NETWORK_PROTOCOL              : tcp
SESSION_USERID                : 50
SESSIONID                     : 460099
SID                           : 32
*/
