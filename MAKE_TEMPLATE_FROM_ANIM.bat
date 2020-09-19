@echo off
cd %~dp0
code\luajit.exe code/template_from_anim.lua %*
pause
