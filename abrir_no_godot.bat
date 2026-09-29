@echo off
rem Abre o projeto no editor do Godot 4.7 (instalado pelo scoop). Ajuste o caminho se usar outro Godot.
start "" godot --path "%~dp0" -e
