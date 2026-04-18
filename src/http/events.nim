import asyncdispatch, asyncnet
import ./types

proc broadcast*(event: string, data: string) =
  {.cast(gcsafe).}:
    let msg = "data: {\"type\": \"" & event & "\", \"payload\": " & data & "}\n\n"
    var dead: seq[int] = @[]
    for i, client in gClients:
      if client.isClosed:
        dead.add(i)
        continue
      try:
        asyncCheck client.send(msg)
      except:
        dead.add(i)
    
    for i in countdown(dead.len - 1, 0):
      gClients.delete(dead[i])
