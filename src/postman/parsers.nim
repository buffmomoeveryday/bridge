import json, strutils, options, tables, sequtils
import ../configType

proc parsePostmanUrl(urlNode: JsonNode): string =
  if urlNode.kind == JString:
    let raw = urlNode.getStr()
    # Extract path from raw URL if possible
    if "://" in raw:
      let parts = raw.split("://", 1)
      if "/" in parts[1]:
        return "/" & parts[1].split("/", 1)[1]
      else:
        return "/"
    return raw

  if urlNode.kind == JObject:
    let pathNode = urlNode{"path"}
    if pathNode != nil and pathNode.kind == JArray:
      var pathParts: seq[string] = @[]
      for p in pathNode:
        pathParts.add(p.getStr())
      return "/" & pathParts.join("/")

    let raw = urlNode{"raw"}
    if raw != nil:
      return parsePostmanUrl(raw)

  return "/"

proc extractItems(node: JsonNode, contracts: var seq[ContractEntry]) =
  if node.kind == JArray:
    for item in node:
      extractItems(item, contracts)
    return

  if node.kind == JObject:
    let items = node{"item"}
    if items != nil:
      extractItems(items, contracts)
      return

    let request = node{"request"}
    if request != nil:
      let methodStr = request{"method"}.getStr("GET")
      let path = parsePostmanUrl(request{"url"})

      var res = ResponseConfig(status: some(200))

      # Try to find a recorded response in Postman
      let responses = node{"response"}
      if responses != nil and responses.kind == JArray and responses.len > 0:
        let firstRes = responses[0]
        res.status = some(firstRes{"code"}.getInt(200))
        res.body = some(firstRes{"body"}.getStr(""))

        var headers = initTable[string, string]()
        let resHeaders = firstRes{"header"}
        if resHeaders != nil and resHeaders.kind == JArray:
          for h in resHeaders:
            headers[h{"key"}.getStr()] = h{"value"}.getStr()
        if headers.len > 0:
          res.headers = some(headers)

      contracts.add(ContractEntry(
        request: RequestConfig(path: path, `method`: methodStr),
        response: some(res)
      ))

proc postmanToBridge*(inputPath: string): BridgeContract =
  let data = parseFile(inputPath)
  result = BridgeContract(contracts: @[])

  let info = data{"info"}
  if info != nil:
    var meta = initTable[string, string]()
    meta["title"] = info{"name"}.getStr("Imported Postman Collection")
    meta["version"] = "1.0.0"
    result.info = some(meta)

  extractItems(data, result.contracts)

proc bridgeToPostman*(contract: BridgeContract): JsonNode =
  result = newJObject()

  let title = if contract.info.isSome: contract.info.get().getOrDefault("title",
      "Bridge Collection") else: "Bridge Collection"

  result["info"] = %*{
    "name": title,
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  }

  var items = newJArray()
  for entry in contract.contracts:
    let req = entry.request
    var item = newJObject()
    item["name"] = %(req.`method` & " " & req.path)

    var requestNode = %*{
      "method": req.`method`,
      "header": newJArray(),
      "url": {
        "raw": "http://localhost:42069" & req.path,
        "protocol": "http",
        "host": ["localhost"],
        "port": "42069",
        "path": req.path.split("/").filterIt(it != "")
      }
    }

    # Headers
    if entry.response.isSome and entry.response.get().headers.isSome:
      for k, v in entry.response.get().headers.get():
        requestNode["header"].add(%*{"key": k, "value": v, "type": "text"})

    item["request"] = requestNode

    # Optional response sample
    if entry.response.isSome:
      let res = entry.response.get()
      var responseNode = %*{
        "name": "Default Response",
        "originalRequest": requestNode,
        "status": "OK",
        "code": res.status.get(200),
        "header": newJArray(),
        "body": res.body.get("")
      }
      if res.headers.isSome:
        for k, v in res.headers.get():
          responseNode["header"].add(%*{"key": k, "value": v})
      item["response"] = %[responseNode]

    items.add(item)

  result["item"] = items
