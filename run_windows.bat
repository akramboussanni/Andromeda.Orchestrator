@echo off
setlocal

:: Move to the directory where the batch file is located
cd /d "%~dp0"

echo Starting Andromeda Orchestrator...
if not exist "venv\Scripts\python.exe" (
    echo [ERROR] Virtual environment not found. Please run setup_windows.bat first.
    pause
    exit /b 1
)

:: Run the orchestrator explicitly using the virtual environment
venv\Scripts\uvicorn.exe main:app --host 0.0.0.0 --port 9000

pause
