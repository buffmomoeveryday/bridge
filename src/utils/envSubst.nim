import os, strutils

proc expandEnvVars*(content: string): string =
  result = ""
  var i = 0
  while i < content.len:
    if content[i] == '$' and i + 1 < content.len and content[i+1] == '{':
      let closing = content.find('}', i + 2)
      if closing != -1:
        let full = content[i+2 ..< closing]
        var name = full
        var defaultVal = ""
        if ":-" in full:
          let parts = full.split(":-", 1)
          name = parts[0]
          defaultVal = parts[1]

        result.add(getEnv(name, defaultVal))
        i = closing + 1
        continue
    result.add(content[i])
    inc i
