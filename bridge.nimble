# Package

version       = "0.1.0"
author        = "Siddhartha Khanal"
description   = "A reverse proxy cli to help mock api responses"
license       = "MIT"
srcDir        = "src"
bin           = @["bridge"]


# Dependencies

requires "nim >= 2.2.6"

requires "cligen >= 1.9.6"
requires "yaml >= 2.2.1"

requires "faker >= 0.16.0"