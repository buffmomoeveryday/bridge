import times, json, terminal
import ./types
import ./events

const MAX_LOGS* = 100

proc logRequest*(meth, path: string, status: int) =
  {.cast(gcsafe).}:
    let log = RequestLog(
      `method`: meth,
      path: path,
      status: status,
      time: now().format("HH:mm:ss")
    )
    gLogs.add(log)
    if gLogs.len > MAX_LOGS:
      gLogs.delete(0)
    
    # Console Output
    let color = if status >= 500: fgRed 
                elif status >= 400: fgYellow 
                elif status >= 300: fgCyan 
                else: fgGreen
    
    stdout.styledWrite(fgBlue, meth, " ", fgWhite, path, " ")
    stdout.styledWriteLine(color, $status)

    broadcast("logs", $(%gLogs))
