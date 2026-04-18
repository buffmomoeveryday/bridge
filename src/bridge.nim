import os, tables, terminal, net, strutils, times
import cligen
import yaml, streams
import asyncdispatch
import json

import ./validator
import ./configType
import ./http/proxy
import ./openapi/parsers
import ./postman/parsers
import ./http/types
import ./utils/envSubst

proc isPortInUse(port: int): bool =
  var socket = newSocket()
  defer: socket.close()
  socket.setSockOpt(OptReuseAddr, true)
  try:
    socket.bindAddr(Port(port))
    false
  except OSError:
    true

proc loadConfig(configPath: string, openapi: bool = false): BridgeContract =
  if not fileExists(configPath):
    stdout.styledWriteLine(fgRed, "Error: Config file not found.")
    quit 1

  if openapi:
    return openApiToBridge(configPath)

  let raw = readFile(configPath)
  gRawConfig = raw
  let expanded = expandEnvVars(raw)

  let errors = validateConfig(expanded)
  if errors.len > 0:
    printValidationErrors(errors)
    quit 1

  let s = newStringStream(expanded)
  defer: s.close()
  var myConfig: BridgeContract
  load(s, myConfig)
  return myConfig

proc watchConfig(configPath: string, intervalMs: int = 500, openapi: bool = false) {.async.} =
  var lastMod = getLastModificationTime(configPath)
  var pendingError = false
  stdout.styledWriteLine(fgCyan, "Watching ", fgWhite, configPath,
    fgCyan, " for changes...")

  while true:
    await sleepAsync(intervalMs)

    if not fileExists(configPath):
      stdout.styledWriteLine(fgYellow, "Warning: config file disappeared, waiting...")
      pendingError = true
      continue

    let currentMod = getLastModificationTime(configPath)
    if currentMod == lastMod and not pendingError:
      continue

    lastMod = currentMod

    # Validate first
    if openapi:
      try:
        let newConfig = openApiToBridge(configPath)
        updateConfig(newConfig)
        if pendingError:
          stdout.styledWriteLine(fgGreen, "Config fixed! Server resumed with new config.")
        else:
          stdout.styledWriteLine(fgGreen, "Config reloaded successfully.")
        pendingError = false
      except CatchableError as e:
        stdout.styledWriteLine(fgRed, "Reload error: ", fgWhite, e.msg)
        stdout.styledWriteLine(fgYellow, "Waiting for fix...")
        pendingError = true
      continue

    let raw = readFile(configPath)
    gRawConfig = raw
    let expanded = expandEnvVars(raw)
    let errors = validateConfig(expanded)
    if errors.len > 0:
      if not pendingError:
        stdout.styledWriteLine(fgRed, "Config error — server paused until fixed:")
      else:
        stdout.styledWriteLine(fgRed, "Still invalid, waiting for fix:")
      printValidationErrors(errors)
      pendingError = true
      continue

    # Valid — try to load and swap
    try:
      let s = newStringStream(expanded)
      defer: s.close()
      var newConfig: BridgeContract
      load(s, newConfig)
      updateConfig(newConfig)
      if pendingError:
        stdout.styledWriteLine(fgGreen, "Config fixed! Server resumed with new config.")
      else:
        stdout.styledWriteLine(fgGreen, "Config reloaded successfully.")
      pendingError = false
    except CatchableError as e:
      stdout.styledWriteLine(fgRed, "Reload error: ", fgWhite, e.msg)
      stdout.styledWriteLine(fgYellow, "Waiting for fix...")
      pendingError = true

proc serve(config: string = "config.yaml", port: int = 42069,
    watch: bool = true, openapi: bool = false) =
  if isPortInUse(port):
    stdout.styledWriteLine(fgRed, "Error: Port is already in use.")
    quit 1

  let contract = loadConfig(config, openapi)

  if watch:
    asyncCheck watchConfig(config, 500, openapi)

  waitFor startServer(port, contract)

proc convertOpenAPI(openapi: string, output: string = "bridge-contract.yaml") =
  let contract = openApiToBridge(openapi)
  dumpBridgeContract(contract, output)

proc importPostman(input: string, output: string = "bridge-contract.yaml") =
  let contract = postmanToBridge(input)
  dumpBridgeContract(contract, output)
  stdout.styledWriteLine(fgGreen, "Success: ", fgWhite,
      "Imported Postman collection to ", fgYellow, output)

proc exportPostman(config: string = "config.yaml",
    output: string = "postman-collection.json") =
  let contract = loadConfig(config)
  let postmanJson = bridgeToPostman(contract)
  writeFile(output, pretty(postmanJson))
  stdout.styledWriteLine(fgGreen, "Success: ", fgWhite,
      "Exported Bridge contract to ", fgYellow, output)

if paramCount() == 0 or (paramCount() > 0 and paramStr(1).startsWith("-")):
  dispatch(serve, short = {"config": 'c', "watch": 'w', "openapi": 'O'})
else:
  dispatchMulti(
    [serve, short = {"config": 'c', "watch": 'w', "openapi": 'O'}],
    [convertOpenAPI, short = {"openapi": 'f', "output": 'o'}],
    [importPostman, short = {"input": 'i', "output": 'o'}],
    [exportPostman, short = {"config": 'c', "output": 'o'}]
  )
