@echo off
setlocal enabledelayedexpansion

:: Chrome paths and profiles
set CHROME="C:\Program Files\Google Chrome\Application\chrome.exe"

:: Open Windows Terminal with all services
start wt new-tab --title "Docker Daemon" cmd /k "wsl sudo dockerd" ^
    ; new-tab --title "Database Services" cmd /k "wsl cd ../../Users/mma300/Documents/Projects/cn-projects/linkplanner_web/backend/app && sudo docker-compose up database adminer redis" ^
    ; new-tab --title "Web Services" cmd /k "wsl cd ../../Users/mma300/Documents/Projects/cn-projects/linkplanner_web/backend/app && sudo docker-compose up web worker3" ^
    ; new-tab --title "Frontend" cmd /k "cd /d %USERPROFILE%\Documents\Projects\cn-projects\linkplanner_web\frontend\app && npm start" ^
    ; new-tab --title "CNHEAT Frontend" cmd /k "set NODE_OPTIONS=--openssl-legacy-provider && cd /d %USERPROFILE%\Documents\Projects\cn-projects\CNHEAT\cnheat2\frontend && npm start"

:: Wait for services to start
timeout /t 10 /nobreak

:: Open Chrome windows with different profiles
start "" %CHROME% --profile-directory="Profile 1" --new-window "http://localhost:3000/"
start "" %CHROME% --profile-directory="Profile 1" --new-tab "https://jira.cambiumnetworks.com/secure/RapidBoard.jspa?projectKey=LPWEB"
start "" %CHROME% --profile-directory="Profile 1" --new-tab "https://bitbucket.cambiumnetworks.com/projects/LINK/repos/linkplanner_web/pull-requests"
start "" %CHROME% --profile-directory="Profile 1" --new-tab "https://react.semantic-ui.com/elements/icon/"

timeout /t 2 /nobreak

start "" %CHROME% --profile-directory="Profile 1_2" --new-window "http://localhost:8000/"
start "" %CHROME% --profile-directory="Profile 1_2" --new-tab "https://jira.cambiumnetworks.com/secure/RapidBoard.jspa?projectKey=CNHEAT"
start "" %CHROME% --profile-directory="Profile 1_2" --new-tab "https://bitbucket.cambiumnetworks.com/projects/CNHEAT/repos/cnheat2/pull-requests"
start "" %CHROME% --profile-directory="Profile 1_2" --new-tab "https://react.semantic-ui.com/elements/icon/"

timeout /t 2 /nobreak

start "" %CHROME% --profile-directory="Profile 3" --new-window "https://claude.ai/new"
start "" %CHROME% --profile-directory="Profile 3" --new-tab "https://chatgpt.com/"

:: Open other applications
start "" "GitHub Desktop"
start "" "Teams"
start "" "Slack"
start "" "OUTLOOK"
start "" "vpnui"
start "" "sublime_text" 