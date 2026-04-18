import asyncnet

type
  RequestLog* = object
    `method`*: string
    path*: string
    status*: int
    time*: string

var gLogs* {.threadvar.}: seq[RequestLog] # Use threadvar but cast to gcsafe as needed
var gClients* {.threadvar.}: seq[AsyncSocket]
var gRawConfig*: string
