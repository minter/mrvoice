@echo off
rem Mr. Voice Database Backup for Windows
rem SVN ID: $Id$
rem
rem You need to set the following variables (most can be found in
rem your C:\MRVOICE.CFG file.
rem The BACKUP_DIR directory must exist - create the directory before
rem you run the script.
rem

set DATABASE=comedysportz
set DB_USER=mrvoice
set DB_PASS=mypassword
set BACKUP_DIR=c:\mrvoice-backup

for /f "tokens=2-4 delims=/ " %%a in ('DATE /T') do set DATE=%%c-%%a-%%b
for /f "tokens=1,2 delims=: " %%a in ('TIME /T') do set TIME=%%a-%%b
set logFile=mrvoice-%DATE%_%TIME%.sql

C:\mysql\bin\mysqldump.exe -u %DB_USER% --password=%DB_PASS% %DATABASE% > %BACKUP_DIR%\%logFile%
@echo on
