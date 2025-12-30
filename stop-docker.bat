@echo off
cd /d "%~dp0"
where docker-compose >nul 2>nul
if %errorlevel% neq 0 (
  echo docker-compose was not found. Please install Docker Desktop.
  exit /b 1
)
docker-compose down
if %errorlevel% neq 0 (
  echo Failed to stop docker-compose. Please ensure Docker Desktop is running.
  exit /b %errorlevel%
)
