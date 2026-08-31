@echo off
setlocal
echo ===================================================
echo   Building Technicolor Nginx GUI Release Packages
echo ===================================================
echo.

where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Python is not found in PATH. Please install Python 3.
    pause
    exit /b 1
)

python "%~dp0scripts\build_release.py" "%~dp0..\gui-dev-build-auto" --channel stable %*
echo.
if %ERRORLEVEL% EQU 0 (
    echo [OK] Build completed successfully!
) else (
    echo [ERROR] Build failed with error code %ERRORLEVEL%.
)
echo.
pause