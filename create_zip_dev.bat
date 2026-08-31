@echo off
setlocal
echo ===================================================
echo   Building Technicolor Nginx GUI Dev Packages
echo ===================================================
echo.

where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Python is not found in PATH. Please install Python 3.
    pause
    exit /b 1
)

python "%~dp0scripts\build_release.py" "%~dp0..\gui-dev-build-auto" --channel dev %*
echo.
if %ERRORLEVEL% EQU 0 (
    echo [OK] Dev build completed successfully!
) else (
    echo [ERROR] Dev build failed with error code %ERRORLEVEL%.
)
echo.
pause