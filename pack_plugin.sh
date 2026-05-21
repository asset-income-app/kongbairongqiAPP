#!/bin/bash
echo "正在打包 hello_world 插件..."
cd "$(dirname "$0")/example_plugins/hello_world"
zip -r ../../hello_world.zip manifest.json index.html
echo "插件已打包到: $(dirname "$0")/hello_world.zip"
