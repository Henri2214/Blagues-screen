@echo off
rem Lance nia.ps1 (place dans le meme dossier) sans fenetre de console visible
start "" /min powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0nia.ps1"
