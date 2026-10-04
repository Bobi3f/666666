@echo off
rem FIRST GEAR: start through DirectX (ANGLE) instead of OpenGL.
rem Helps on old Intel graphics and when the game closes at start.
start "" "%~dp0FirstGear.exe" --rendering-driver opengl3_angle
