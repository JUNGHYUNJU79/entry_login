@echo off
chcp 65001 >nul
title 하원초 6학년 엔트리 자동 로그인 - 설치
echo.
echo  하원초 6학년 엔트리 자동 로그인을 이 컴퓨터에 설치합니다.
echo  설치 중에는 브라우저 창이 저절로 열리고 눌립니다. 끝날 때까지 마우스와 키보드를 건드리지 마세요.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 (
  echo.
  echo  설치 중 문제가 생겼습니다. 위 내용을 선생님께 보여 주세요.
  pause
)
