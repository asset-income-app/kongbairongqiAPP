@echo off
echo 正在打包 hello_world 插件...
cd /d "%~dp0example_plugins\hello_world"
powershell Compress-Archive -Path manifest.json,index.html -DestinationPath ..\..\hello_world.zip -Force
echo 插件已打包到: %~dp0hello_world.zip
pause
