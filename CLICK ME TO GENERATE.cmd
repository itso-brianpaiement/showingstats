@echo off
setlocal

cd /d "%~dp0"
title Showing System Member Count Generator

echo ==========================================
echo   Showing System Member Count Generator
echo ==========================================
echo.

whoami /groups | find "S-1-5-32-544" >nul
if not "%ERRORLEVEL%"=="0" (
  echo Please right-click this file and choose "Run as administrator".
  echo Then click YES on the Windows popup.
  echo.
  if /i not "%NO_PAUSE%"=="1" pause
  exit /b 1
)

set "KEY_FILE=keys"
if not exist "keys" (
  if exist "keys.txt" (
    set "KEY_FILE=keys.txt"
  ) else (
    echo ERROR: keys file not found.
    echo.
    echo Expected file name: keys
    echo.
    echo Open the file named "keys", enter your Bridge API values, and save it.
    echo.
    if /i not "%NO_PAUSE%"=="1" pause
    exit /b 1
  )
)

if "%KEY_FILE%"=="keys" (
  findstr /C:"YOUR_ENDPOINT_URL" "keys" >nul
  if not errorlevel 1 (
    if exist "keys.txt" (
      set "KEY_FILE=keys.txt"
      echo Detected placeholder values in keys. Using keys.txt instead.
      echo.
    )
  )
)

if "%KEY_FILE%"=="keys.txt" (
  echo Using keys.txt legacy format.
  echo.
)

if not "%KEY_FILE%"=="keys.txt" (
  echo Using keys file.
  echo.
)

if not exist "%KEY_FILE%" (
  echo ERROR: Unable to find keys file.
  echo.
  if /i not "%NO_PAUSE%"=="1" pause
  exit /b 1
)

echo Running data pull and report generation...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File ".\run_member_counts.ps1" -KeysFile ".\%KEY_FILE%"
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
