# Package

version = "0.1.0"
author = "Siddhartha Khanal"
description = "A cli to help mock api responses"
license = "MIT"
srcDir = "src"
bin = @["bridge"]

# Dependencies

requires "nim >= 2.2.6"

requires "cligen >= 1.9.6"
requires "yaml >= 2.2.1"

requires "faker >= 0.16.0"

task build_linux, "Build for Linux":
  mkDir "bin"
  exec "nim c -d:release --out:bin/bridge-linux src/bridge.nim"
  exec "mv bridge bin/bridge-linux"

task build_windows, "Build for Windows":
  mkDir "bin"
  exec "nim c -d:release --os:windows --cpu:amd64 --gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-gcc --out:bin/bridge-windows.exe src/bridge.nim"
  exec "mv bridge.exe bin/bridge-windows.exe"

task build_macos, "Build for macOS":
  mkDir "bin"
  exec "nim c -d:release --os:macosx --cpu:amd64 --out:bin/bridge-macos src/bridge.nim"
  exec "mv bridge bin/bridge-macos"
