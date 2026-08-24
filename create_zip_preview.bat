@echo off
setlocal
echo ===================================================
echo   Building Technicolor Nginx GUI PREVIEW Packages
echo ===================================================
echo.
python "%~dp0scripts\build_release.py" "%~dp0..\gui-dev-build-auto" --channel preview
echo.
if %ERRORLEVEL% EQU 0 (
    echo [OK] Preview build completed successfully!
) else (
    echo [ERROR] Build failed with error code %ERRORLEVEL%.
)
echo.
pause
