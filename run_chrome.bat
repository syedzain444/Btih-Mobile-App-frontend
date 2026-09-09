@echo off
REM Run Flutter web on Chrome with flags for the hospital API self-signed HTTPS cert.
cd /d "%~dp0"
flutter run -d chrome ^
  --web-browser-flag "--ignore-certificate-errors" ^
  --web-browser-flag "--ignore-urlfetcher-cert-requests" ^
  --web-browser-flag "--disable-web-security" ^
  --web-browser-flag "--user-data-dir=%TEMP%\btih_chrome_dev"
