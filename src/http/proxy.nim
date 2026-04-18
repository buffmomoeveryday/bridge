import asynchttpserver, asyncdispatch, net, asyncnet
import strformat, tables, options, strutils, random, json, sequtils
import terminal

import ../configType
import ./fakerProvider
import ./dashboard
import ./types
import ./events
import ./logger
import ./router
import ./responder

randomize()

var gServer: AsyncHttpServer
var gConfig: BridgeContract
var cycleCounters = initTable[string, int]()

proc updateConfig*(config: BridgeContract) {.gcsafe.} =
  {.cast(gcsafe).}:
    gConfig = config

proc getCycleIdx(path: string): int {.gcsafe.} =
  {.cast(gcsafe).}:
    result = cycleCounters.getOrDefault(path, 0)

proc setCycleIdx(path: string, idx: int) {.gcsafe.} =
  {.cast(gcsafe).}:
    cycleCounters[path] = idx

proc handleDashboard(req: Request) {.async.} =
  case req.url.path
  of "/_bridge/ui":
    let headers = newHttpHeaders({"Content-Type": "text/html"})
    await req.respond(Http200, DASHBOARD_HTML, headers)
  of "/_bridge/events":
    let headers = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n"
    await req.client.send(headers)
    {.cast(gcsafe).}:
      gClients.add(req.client)
    while true:
      var isClosed = false
      {.cast(gcsafe).}:
        isClosed = req.client.isClosed()
      if isClosed: break
      await sleepAsync(1000)
  of "/_bridge/data/logs":
    let headers = newHttpHeaders({"Content-Type": "application/json"})
    var l: string
    {.cast(gcsafe).}: l = $(%gLogs)
    await req.respond(Http200, l, headers)
  of "/_bridge/data/store":
    let headers = newHttpHeaders({"Content-Type": "application/json"})
    var s: string
    {.cast(gcsafe).}: s = $(%gStore)
    await req.respond(Http200, s, headers)
  of "/_bridge/data/config":
     var c: string
     {.cast(gcsafe).}: c = gRawConfig
     await req.respond(Http200, c)
  else:
    await req.respond(Http404, "Not found")

proc handler(req: Request) {.async, gcsafe.} =
  if req.url.path.startsWith("/_bridge/"):
    await handleDashboard(req)
    return

  {.cast(gcsafe).}:
    let config = gConfig
  
  for entry in config.contracts:
    var captures: seq[string] = @[]
    if matchRequest(req, entry, captures):
      if entry.proxy.isSome:
        await sendExternalRequest(req, entry)
        return

      var chaosPool: seq[ResponseConfig] = @[]
      if entry.responses.isSome:
        chaosPool = entry.responses.get().filterIt(it.status.get(200) >= 400)

      if entry.error_rate.isSome:
        let rate = entry.error_rate.get().clamp(0.0, 1.0)
        {.cast(gcsafe).}:
          let roll = rand(1.0)
        if roll < rate:
          await sendChaosResponse(req, chaosPool)
          return

      if entry.store.isSome:
        let s = entry.store.get()
        var action: string
        var val: string
        var key: string
        {.cast(gcsafe).}:
          val = applyFakers(options.get(s.value, ""), req.body)
          key = s.key
          action = options.get(s.action, "set")
          case action
          of "append":
            gStore[key] = gStore.getOrDefault(key, "") & val
          of "inc":
            try:
              let cur = gStore.getOrDefault(key, "0").parseInt()
              gStore[key] = $(cur + val.parseInt())
            except: discard
          else:
            gStore[key] = val
          broadcast("store", $(%gStore))
        stdout.styledWriteLine(fgYellow, "  ☁ store: ", fgWhite, key, " = ", val)

      if entry.cycle.get(false) and entry.responses.isSome:
        let resList = entry.responses.get()
        if resList.len > 0:
          let idx = getCycleIdx(entry.request.path)
          let res = resList[idx]
          logRequest($req.reqMethod, req.url.path, res.status.get(200))
          await sendMockRequest(req, res, chaosPool, captures)
          setCycleIdx(entry.request.path, (idx + 1) mod resList.len)
        return
      elif entry.responses.isSome and entry.responses.get().len > 0:
        let res = entry.responses.get()[0]
        logRequest($req.reqMethod, req.url.path, res.status.get(200))
        await sendMockRequest(req, res, chaosPool, captures)
        return
      elif entry.response.isSome:
        let res = entry.response.get()
        logRequest($req.reqMethod, req.url.path, res.status.get(200))
        await sendMockRequest(req, res, chaosPool, captures)
        return

  logRequest($req.reqMethod, req.url.path, 404)
  await req.respond(Http404, "Router not defined in Bridge Contract")

proc startServer*(port: int, config: BridgeContract) {.async.} =
  stdout.styledWriteLine(fgGreen, fmt"Starting server on port {port}")
  if config.info.isSome:
    let info = config.info.get()
    let title = info.getOrDefault("title", "Unknown API")
    let version = info.getOrDefault("version", "v0.0.0")
    stdout.styledWriteLine(fgCyan, fmt"API: {title} ({version})")
  {.cast(gcsafe).}:
    gConfig = config
    cycleCounters = initTable[string, int]()
  gServer = newAsyncHttpServer(reuseAddr = true)
  setControlCHook(proc() {.noconv.} =
    stdout.styledWriteLine(fgYellow, "Shutting down...")
    gServer.close()
    quit 0
  )
  proc callback(req: Request): Future[void] {.async, gcsafe.} = await handler(req)
  waitFor gServer.serve(Port(port), callback)
