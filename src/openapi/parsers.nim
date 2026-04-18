import strutils, json, options, tables, streams
import yaml, yaml/tojson
import ../configType

const kValidVerbs = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]

proc toRegexPath(path: string, paramSchemas: Table[string, string]): (string, bool) =
  if "{" notin path:
    return (path, false)

  var res = path
  while "{" in res:
    let s = res.find('{')
    let e = res.find('}', s)
    if s < 0 or e < 0: break
    let paramName = res[s + 1 ..< e]
    let capture =
      case paramSchemas.getOrDefault(paramName, "string")
      of "integer", "number": "(\\d+)"
      else: "([^/]+)"
    res = res[0 ..< s] & capture & res[e + 1 .. ^1]

  return (res, true)

proc jsonToBodyString(node: JsonNode): string =
  if node == nil: return ""
  case node.kind
  of JString: return node.getStr()
  else: return $node

proc firstExample(responseNode: JsonNode): string =
  if responseNode == nil: return ""
  let content = responseNode{"content"}
  if content == nil: return ""

  var media: JsonNode = content{"application/json"}
  if media == nil:
    for _, v in content.pairs: media = v; break
  if media == nil: return ""

  let ex = media{"example"}
  if ex != nil: return jsonToBodyString(ex)

  let exs = media{"examples"}
  if exs != nil:
    for _, v in exs.pairs:
      let val = v{"value"}
      if val != nil: return jsonToBodyString(val)

  return ""

proc pickBest(cs: seq[(int, JsonNode)]): (int, JsonNode) =
  var best: (int, JsonNode) = (-1, nil)
  for (c, n) in cs:
    if c == 200: return (c, n)
    if best[0] == -1 or
       (c == 201 and best[0] != 200) or
       (c < best[0] and best[0] != 200 and best[0] != 201):
      best = (c, n)
  return best

proc openApiToBridge*(inputPath: string): BridgeContract =
  result = BridgeContract(contracts: @[])

  var spec: JsonNode
  try:
    let raw = readFile(inputPath)
    spec = loadToJson(raw)[0]
  except CatchableError as e:
    raise newException(ValueError, "Error: could not parse OpenAPI file: " & e.msg)

  if spec{"paths"} == nil:
    raise newException(ValueError, "Warning: OpenAPI spec has no 'paths' key — nothing to convert.")

  for rawPath, methods in spec["paths"].pairs:
    if methods == nil or methods.kind != JObject: continue

    # Collect path-level parameter schemas
    var paramSchemas = initTable[string, string]()
    let pathParams = methods{"parameters"}
    if pathParams != nil and pathParams.kind == JArray:
      for p in pathParams:
        let name = p{"name"}
        let schema = p{"schema"}
        if name != nil and schema != nil:
          paramSchemas[name.getStr()] = schema{"type"}.getStr("string")

    for verb, operation in methods.pairs:
      let upperVerb = verb.toUpperAscii()
      if upperVerb notin kValidVerbs: continue
      if operation == nil or operation.kind != JObject: continue

      # Merge operation-level parameters (these override path-level)
      let opParams = operation{"parameters"}
      if opParams != nil and opParams.kind == JArray:
        for p in opParams:
          let name = p{"name"}
          let schema = p{"schema"}
          if name != nil and schema != nil:
            paramSchemas[name.getStr()] = schema{"type"}.getStr("string")

      let (cleanPath, isRegex) = toRegexPath(rawPath, paramSchemas)

      var req = RequestConfig(
        path: cleanPath,
        `method`: upperVerb,
        is_regex: if isRegex: some(true) else: none(bool)
      )

      var chosenStatus = 200
      var chosenBody = ""
      var chosenHeaders = initTable[string, string]()

      let responses = operation{"responses"}
      if responses != nil and responses.kind == JObject:
        var candidates: seq[(int, JsonNode)] = @[]
        for code, node in responses.pairs:
          try:
            candidates.add((parseInt(code), node))
          except ValueError:
            discard

        let (pickedCode, pickedNode) = pickBest(candidates)
        if pickedCode >= 0:
          chosenStatus = pickedCode
          chosenBody = firstExample(pickedNode)

          let content = pickedNode{"content"}
          if content != nil and content.kind == JObject:
            for mediaType, _ in content.pairs:
              chosenHeaders["Content-Type"] = mediaType
              break

      var resp = ResponseConfig(status: some(chosenStatus))
      if chosenBody != "":
        resp.body = some(chosenBody)
      if chosenHeaders.len > 0:
        resp.headers = some(chosenHeaders)

      result.contracts.add(ContractEntry(
        request: req,
        response: some(resp)
      ))

proc dumpBridgeContract*(contract: BridgeContract, outputPath: string) =
  var dumper = Dumper()
  dumper.setBlockOnlyStyle()
  var s = newFileStream(outputPath, fmWrite)
  defer: s.close()
  dumper.dump(contract, s)

proc bridgeContractToYaml*(contract: BridgeContract): string =
  var dumper = Dumper()
  dumper.setBlockOnlyStyle()
  return dumper.dump(contract)
