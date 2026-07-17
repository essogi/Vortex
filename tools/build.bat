@echo off
rem Runs build.ps1 without PowerShell execution-policy friction.
rem Usage is identical - pass the same arguments, e.g.:
rem   build.bat -SourceZip "...zip" -Axm68k "...axm68k.exe" -Macros "...Macros - More CPUs.asm"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
exit /b %errorlevel%
