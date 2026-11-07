@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Coffee Shift Windows developer launcher: first import the raw ZIP assets.
rem Usage: double-click after setting GODOT_EXE, or drag the Godot .exe here.
rem This is a development project, not a packaged standalone game.
pushd "%~dp0"
if errorlevel 1 (
    echo [ERROR] Cannot access the Coffee Shift project folder.
    pause
    exit /b 1
)
if not exist "project.godot" (
    echo [ERROR] project.godot is missing. Extract the complete ZIP first.
    goto :failed
)
set "GODOT_BIN="
if not "%~1"=="" set "GODOT_BIN=%~1"
if not defined GODOT_BIN if defined GODOT_EXE set "GODOT_BIN=%GODOT_EXE%"
if not defined GODOT_BIN (
    for %%F in ("%~dp0Godot_v4.3-stable_win64.exe" "%~dp0Godot_v4.4-stable_win64.exe" "%~dp0Godot_v4.5-stable_win64.exe") do (
        if not defined GODOT_BIN if exist "%%~fF" set "GODOT_BIN=%%~fF"
    )
)
if not defined GODOT_BIN (
    for %%N in (godot.exe godot4.exe Godot_v4.3-stable_win64.exe) do (
        if not defined GODOT_BIN (
            where /q "%%N"
            if not errorlevel 1 set "GODOT_BIN=%%N"
        )
    )
)
if not defined GODOT_BIN (
    echo [ERROR] Godot executable not found.
    echo Drag Godot 4.3+ .exe onto this .bat, or set GODOT_EXE to its full path.
    goto :failed
)
echo [1/2] Importing 3D models, fonts and other resources from the ZIP...
"%GODOT_BIN%" --headless --path "." --editor --import --quit
if errorlevel 1 (
    echo [ERROR] Godot import failed. Open project.godot in the editor to inspect errors.
    goto :failed
)
echo [2/2] Starting Coffee Shift...
"%GODOT_BIN%" --path "."
set "RESULT=%errorlevel%"
popd
exit /b %RESULT%

:failed
popd
pause
exit /b 1
