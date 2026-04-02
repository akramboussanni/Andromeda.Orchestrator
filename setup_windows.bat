@echo off
setlocal EnableDelayedExpansion

echo ===================================================
echo Andromeda Orchestrator - Windows Environment Setup
echo ===================================================

:: Ensure dependencies
where curl >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] curl is required but not found. Windows 10 build 17063+ or Windows 11 required.
    exit /b 1
)
where tar >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] tar is required but not found. Windows 10 build 17063+ or Windows 11 required.
    exit /b 1
)

:: Directories and Vars
set BASE_DIR=%~dp0
set DATA_DIR=%BASE_DIR%data
set STEAMCMD_DIR=%DATA_DIR%\steamcmd
set GAME_DIR=%DATA_DIR%\game
set MODS_DIR=%GAME_DIR%\Mods

set STEAMCMD_URL=https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip
set MELONLOADER_URL=https://github.com/LavaGang/MelonLoader/releases/latest/download/MelonLoader.x64.zip

:: Defaults
if not defined EOB_APP_ID set EOB_APP_ID=999860
if not defined EOB_EXE_RELATIVE_PATH set EOB_EXE_RELATIVE_PATH=enemy-on-board.exe
if not defined ANDROMEDA_MOD_URL set ANDROMEDA_MOD_URL=https://github.com/akramboussanni/Andromeda.Mod/releases/latest/download/Andromeda.Mod.dll

mkdir "%DATA_DIR%" 2>nul
mkdir "%STEAMCMD_DIR%" 2>nul
mkdir "%GAME_DIR%" 2>nul
mkdir "%MODS_DIR%" 2>nul

:: 1. SteamCMD
if not exist "%STEAMCMD_DIR%\steamcmd.exe" (
    echo [1/4] Downloading and extracting SteamCMD...
    curl -fsSL "%STEAMCMD_URL%" -o "%DATA_DIR%\steamcmd.zip"
    tar -xf "%DATA_DIR%\steamcmd.zip" -C "%STEAMCMD_DIR%"
    del "%DATA_DIR%\steamcmd.zip"
) else (
    echo [1/4] SteamCMD already installed.
)

:: 2. Game
echo [2/4] Downloading game via SteamCMD ^(AppID: %EOB_APP_ID%^)...
if defined STEAM_USER (
    if defined STEAM_PASS (
        "%STEAMCMD_DIR%\steamcmd.exe" +force_install_dir "%GAME_DIR%" +login %STEAM_USER% %STEAM_PASS% %STEAM_AUTH_CODE% +app_update %EOB_APP_ID% validate +quit
    ) else (
        "%STEAMCMD_DIR%\steamcmd.exe" +force_install_dir "%GAME_DIR%" +login %STEAM_USER% +app_update %EOB_APP_ID% validate +quit
    )
) else (
    "%STEAMCMD_DIR%\steamcmd.exe" +force_install_dir "%GAME_DIR%" +login anonymous +app_update %EOB_APP_ID% validate +quit
)

:: 3. MelonLoader
if not exist "%GAME_DIR%\MelonLoader" (
    echo [3/4] Downloading and extracting MelonLoader...
    curl -fsSL "%MELONLOADER_URL%" -o "%DATA_DIR%\melonloader.zip"
    tar -xf "%DATA_DIR%\melonloader.zip" -C "%GAME_DIR%"
    del "%DATA_DIR%\melonloader.zip"
) else (
    echo [3/4] MelonLoader already appears to be installed.
)

:: 4. Andromeda Mod
echo [4/4] Downloading Andromeda Mod...
curl -fsSL "%ANDROMEDA_MOD_URL%" -o "%MODS_DIR%\Andromeda.Mod.dll"

:: Create or update .env file
echo [setup] Checking configuration in .env ...
set ENV_FILE=%BASE_DIR%.env
if not exist "%ENV_FILE%" (
    copy "%BASE_DIR%.env.example" "%ENV_FILE%" >nul
)

echo.
echo ===================================================
echo Setup complete. 
echo Ensure your .env file is updated for process mode:
echo   HOST_RUNTIME_MODE=process
echo   HOST_GAME_EXECUTABLE_PATH=%GAME_DIR%\%EOB_EXE_RELATIVE_PATH%
echo.
echo Run the orchestrator with:
echo   uvicorn main:app --host 0.0.0.0 --port 9000
echo ===================================================
pause
