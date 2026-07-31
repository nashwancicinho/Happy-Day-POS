@echo off
echo ===================================================
echo Building Happy Day POS Windows Setup Executable
echo ===================================================

echo [1/3] Fetching Flutter dependencies...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo Error fetching packages. Exiting.
    pause
    exit /b %ERRORLEVEL%
)

echo [2/3] Building Flutter Windows Release binaries...
call flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo Error during Flutter build. Make sure Visual Studio with C++ tools is installed.
    pause
    exit /b %ERRORLEVEL%
)

echo [3/3] Compiling Inno Setup script to generate HappyDayPOS_Setup.exe...
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\setup_script.iss
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    "C:\Program Files\Inno Setup 6\ISCC.exe" installer\setup_script.iss
) else (
    echo [WARNING] Inno Setup compiler (ISCC.exe) was not found in standard paths.
    echo Please install Inno Setup 6 from https://jrsoftware.org/isdl.php
    echo and compile installer\setup_script.iss manually.
    pause
    exit /b 1
)

echo ===================================================
echo SUCCESS! Setup file generated in: installer\output\HappyDayPOS_Setup.exe
echo ===================================================
pause
