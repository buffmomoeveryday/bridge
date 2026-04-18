import asynchttpserver, asyncdispatch, httpclient, asyncnet, net
import strutils, options, tables, random
import ../configType
import ./fakerProvider
import ./logger

proc sendMockRequest*(
    req: Request,
    res: ResponseConfig,
    chaosPool: seq[ResponseConfig] = @[],
    captures: seq[string] = @[],
) {.async.} =
  # Chaos: random failure injection
  if res.error_rate.isSome:
    let rate = res.error_rate.get().clamp(0.0, 1.0)
    {.cast(gcsafe).}:
      let roll = rand(1.0)
    if roll < rate:
      if chaosPool.len > 0:
        {.cast(gcsafe).}:
          let picked = sample(chaosPool)
        let headers = newHttpHeaders()
        if picked.headers.isSome:
          for k, v in picked.headers.get():
            headers.add(k, v)
        let body = applyFakers(options.get(picked.body, ""), req.body)
        await req.respond(HttpCode(picked.status.get(500)), body, headers)
      else:
        await req.respond(Http500, "Internal Server Error")
      return

  # Normal delay and jitter
  if res.delay_ms.isSome:
    await sleepAsync(res.delay_ms.get())

  if res.latency_range.isSome:
    let parts = res.latency_range.get().split('-')
    if parts.len == 2:
      try:
        let minD = parts[0].strip().parseInt()
        let maxD = parts[1].strip().parseInt()
        let delay = rand(minD .. maxD)
        await sleepAsync(delay)
      except:
        discard

  var body = applyFakers(options.get(res.body, ""), req.body)
  for i, c in captures:
    body = body.replace("$" & $(i + 1), c)

  let status = res.status.get(200)

  if res.throttle_kbps.isSome and res.throttle_kbps.get() > 0.0:
    let kbps = res.throttle_kbps.get()
    var headerStr = "HTTP/1.1 " & $status & " " & $HttpCode(status) & "\r\n"
    let h = newHttpHeaders()
    if res.headers.isSome:
      for k, v in res.headers.get():
        h.add(k, v)
    h.add("Content-Length", $body.len)
    for k, vals in h.table:
      for v in vals:
        headerStr &= k & ": " & v & "\r\n"
    headerStr &= "\r\n"

    await req.client.send(headerStr)
    let chunkSize = 1024
    let delayPerChunk = int((chunkSize.float / (kbps * 1024.0)) * 1000.0)
    var sent = 0
    while sent < body.len:
      let nextSize = min(chunkSize, body.len - sent)
      await req.client.send(body[sent ..< sent + nextSize])
      sent += nextSize
      if sent < body.len:
        await sleepAsync(delayPerChunk)
  else:
    let headers = newHttpHeaders()
    if res.headers.isSome:
      for k, v in res.headers.get():
        headers.add(k, v)
    await req.respond(HttpCode(status), body, headers)

proc sendExternalRequest*(req: Request, entry: ContractEntry) {.async.} =
  let proxy = entry.proxy.get()
  let ctx = newContext(verifyMode = CVerifyNone)
  var client = newAsyncHttpClient(userAgent = "BridgeProxy/0.1", sslContext = ctx)
  if proxy.timeout_ms.isSome:
    client.timeout = proxy.timeout_ms.get()

  try:
    let url = proxy.url
    let res = await client.get(url)
    let body = await res.body
    let responseHeaders = newHttpHeaders()
    for k, vals in res.headers.table:
      if k.toLowerAscii() notin ["transfer-encoding", "connection", "keep-alive"]:
        for v in vals:
          responseHeaders.add(k, v)
    logRequest($req.reqMethod, req.url.path, res.code.int)
    await req.respond(res.code, body, responseHeaders)
  except CatchableError as e:
    await req.respond(Http502, "Bad Gateway: " & e.msg)
  finally:
    client.close()

proc sendChaosResponse*(req: Request, chaosPool: seq[ResponseConfig]) {.async.} =
  if chaosPool.len > 0:
    {.cast(gcsafe).}:
      let picked = sample(chaosPool)
    let status = picked.status.get(500)
    logRequest($req.reqMethod, req.url.path, status)
    let headers = newHttpHeaders()
    if picked.headers.isSome:
      for k, v in picked.headers.get():
        headers.add(k, v)
    let body = applyFakers(options.get(picked.body, ""), req.body)
    await req.respond(HttpCode(status), body, headers)
  else:
    await req.respond(Http500, "Internal Server Error")
