#!/bin/zsh

cd "$(dirname "$0")"

xcodebuild

echo "copying .."
D="/System/Library/Application Support/SIMBL/Plugins/"
sudo rm -rf "$D/FScriptAnywhere.bundle"
sudo cp -a "build/Release/FScriptAnywhere.bundle" "$D"

# debugging:
# defaults write net.culater.SIMBL SIMBLLogLevel -int 0
# disable with ... -int 2
