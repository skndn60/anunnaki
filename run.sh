#!/bin/bash
set -e
echo "Building..."
xcodebuild -project Me.xcodeproj -scheme Me -configuration Debug build 2>&1 | tail -3
echo "Launching..."
open ~/Library/Developer/Xcode/DerivedData/Me-*/Build/Products/Debug/Me.app
