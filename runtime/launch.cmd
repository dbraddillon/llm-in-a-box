@echo off
setlocal
set HERE=%~dp0
set LLAMA_BIN=%HERE%bin\llama-server.exe
set MODEL=%HERE%model\model.gguf

if not exist "%LLAMA_BIN%" (
  echo llama-server binary not found at %LLAMA_BIN%
  echo This box was assembled without a model runtime binary bundled -- see README.md.
  pause
  exit /b 1
)

start "llama-server" "%LLAMA_BIN%" -m "%MODEL%" --port 8080
timeout /t 2 /nobreak >nul
node "%HERE%server\index.mjs"
