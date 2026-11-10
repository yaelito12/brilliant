@echo off
rem Doble clic para jugar: arranca el servidor (si esta al lado), sirve el juego
rem en la red local y muestra los links para esta PC y para las demas.
setlocal EnableDelayedExpansion
cd /d "%~dp0"
title Brilliant

rem --- IPs de esta PC en la red local (sin 127.x ni 169.254.x) ---
set IPS=
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4).IPAddress -notmatch '^(127|169\.254)\.'"') do (
  set IPS=!IPS! %%i
)

rem --- CORS: permitir el juego desde localhost y desde cada IP ---
rem (las variables de entorno tienen prioridad sobre el .env del servidor)
set CORS_ORIGINS=http://localhost:5000,http://localhost:5001
for %%i in (%IPS%) do set CORS_ORIGINS=!CORS_ORIGINS!,http://%%i:5000

if exist "..\brilliant_server\Iniciar servidor.bat" (
  start "Servidor Brilliant" cmd /c "..\brilliant_server\Iniciar servidor.bat"
) else (
  echo No encontre ..\brilliant_server, el juego abrira sin servidor.
)

rem --- Aviso si el firewall no tiene la regla para los puertos ---
netsh advfirewall firewall show rule name="Brilliant" >nul 2>&1
if errorlevel 1 (
  echo.
  echo  AVISO: el Firewall de Windows puede bloquear a las otras PCs.
  echo  Abre PowerShell como administrador y ejecuta una sola vez:
  echo    New-NetFirewallRule -DisplayName "Brilliant" -Direction Inbound -Protocol TCP -LocalPort 3000,5000 -Action Allow
)

echo.
echo ============================================================
echo   En esta PC:        http://localhost:5000
if "%IPS%"=="" (
  echo   No encontre conexion de red: solo se puede jugar en esta PC.
) else (
  echo   Desde otra PC ^(misma red Wi-Fi o cable^):
  for %%i in (%IPS%) do echo                      http://%%i:5000
)
echo ============================================================
echo   La primera vez tarda un poco en compilar. El navegador se
echo   abrira solo cuando el juego este listo.
echo.

rem Abre el navegador de esta PC cuando el puerto 5000 ya responde.
start "" /min powershell -NoProfile -WindowStyle Hidden -Command "while (-not (Test-NetConnection localhost -Port 5000 -InformationLevel Quiet -WarningAction SilentlyContinue)) { Start-Sleep 2 }; Start-Sleep 3; Start-Process 'http://localhost:5000'"

rem --release: sin depurador (evita los avisos "WebSocket debug connection")
rem y el juego carga mucho mas rapido en las otras PCs.
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 5000 --release
