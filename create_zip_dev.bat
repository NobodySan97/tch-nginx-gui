@echo off
setlocal
echo ===================================================
echo   Building Technicolor Nginx GUI Dev Packages
echo ===================================================
echo.
python "%~dp0scripts\build_release.py" "%~dp0..\gui-dev-build-auto"
echo.
if %ERRORLEVEL% EQU 0 (
    echo [OK] Dev build completed successfully!
) else (
    echo [ERROR] Dev build failed with error code %ERRORLEVEL%.
)
echo.
pause