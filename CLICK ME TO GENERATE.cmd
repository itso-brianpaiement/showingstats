@echo off
setlocal

cd /d "%~dp0"
title Showing System Member Count Generator

echo ==========================================
echo   Showing System Member Count Generator
echo ==========================================
echo.

if not exist "keys.txt" (
  echo ERROR: keys.txt was not found in this folder.
  if exist "keys.template.txt" (
    echo A template is available: keys.template.txt
    echo Copy it to keys.txt and fill in your values.
  )
  echo.
  if /i not "%NO_PAUSE%"=="1" pause
  exit /b 1
)

echo Running data pull and report generation...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File ".\run_member_counts.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" (
  echo Generation failed. Exit code: %EXIT_CODE%
  echo.
  if /i not "%NO_PAUSE%"=="1" pause
  exit /b %EXIT_CODE%
)

echo Generation complete.
echo The files are in the output folder.
echo.
if /i not "%NO_PAUSE%"=="1" pause
exit /b 0
