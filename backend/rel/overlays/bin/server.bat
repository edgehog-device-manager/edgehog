set PHX_SERVER=true
call "%~dp0\edgehog" eval Edgehog.Release.migrate
call "%~dp0\edgehog" start
