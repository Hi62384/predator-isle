@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\maintenance\open_project.ps1"
if errorlevel 1 pause
