@echo off
setlocal enabledelayedexpansion

REM SheIn Connect - Version Bumper & Git Release Automation Script
REM Usage:
REM   bump.cmd [patch|minor|major|build] ["optional commit message"]
REM Examples:
REM   bump.cmd
REM   bump.cmd patch
REM   bump.cmd minor "feat: added new payment features"
REM   bump.cmd major "release: version 2.0.0"

set BUMP_TYPE=%~1
if "%BUMP_TYPE%"=="" set BUMP_TYPE=patch

set COMMIT_MSG=%~2

echo.
echo ===========================================================
echo  Starting SheIn Connect Version Bump and Git Release
echo ===========================================================
echo.

if "%COMMIT_MSG%"=="" (
    dart run tool/bump_version.dart %BUMP_TYPE%
) else (
    dart run tool/bump_version.dart %BUMP_TYPE% "%COMMIT_MSG%"
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Version bump script failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Script finished successfully!
echo.
