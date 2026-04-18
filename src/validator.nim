# src/validator.nim
import yaml/tojson, strutils, strformat, re
import terminal
import json

type
  ValidationError* = object
    line*: int
    message*: string

const kKnownFakerTags = [
  "name", "firstName", "first_name", "lastName", "last_name",
  "email", "safeEmail", "safe_email", "username", "userName",
  "phone", "phoneNumber", "phone_number", "address", "city",
  "country", "postcode", "zipcode", "zip", "streetAddress", "street_address",
  "company", "companySuffix", "company_suffix", "job", "bs",
  "catchPhrase", "catch_phrase", "word", "ssn", "md5", "sha1",
  "mimeType", "mime_type", "fileExtension", "file_extension",
  "fileName", "file_name", "filePath", "file_path",
  "userAgent", "user_agent", "iban", "currency",
  "currencyCode", "currency_code", "currencyName", "currency_name",
  "boolean", "bool", "uuid", "timestamp"
]

proc checkFakerTags(body: string, entryNum: int, field: string): seq[
    ValidationError] =
  result = @[]
  var i = 0
  while i < body.len:
    let s = body.find("{{", i)
    if s < 0: break
    let e = body.find("}}", s + 2)
    if e < 0:
      result.add(ValidationError(line: entryNum,
        message: fmt"Entry {entryNum}: unclosed '{{{{' in {field}"))
      break
    let tag = body[s + 2 ..< e].strip()
    let isDynamicTag = tag == "req.body" or tag.startsWith("req.json.") or
                       tag.startsWith("store.")
    if tag notin kKnownFakerTags and not isDynamicTag:
      result.add(ValidationError(line: entryNum,
        message: fmt"Entry {entryNum}: unknown faker tag '{{{{{tag}}}}}' in {field}"))
    i = e + 2

proc validateConfig*(content: string): seq[ValidationError] =
  result = @[]

  var spec: seq[JsonNode]
  try:
    spec = loadToJson(content)
  except CatchableError as e:
    result.add(ValidationError(line: 0, message: "YAML parse error: " & e.msg))
    return

  if spec.len == 0: return

  let root = spec[0]

  var entries: JsonNode
  if root.kind == JArray:
    entries = root
  elif root.kind == JObject and root{"contracts"} != nil:
    entries = root["contracts"]
  else:
    result.add(ValidationError(line: 0,
      message: "Root must be a sequence of contract entries or an object with a 'contracts' key"))
    return

  for i, entry in entries.elems:
    let entryNum = i + 1

    # ── request block ────────────────────────────────────────────────────
    let req = entry{"request"}
    if req == nil:
      result.add(ValidationError(line: entryNum,
        message: fmt"Entry {entryNum}: missing required 'request' block"))
      continue

    let pathNode = req{"path"}
    let meth = req{"method"}
    let isRegex = req{"is_regex"}

    if pathNode == nil or pathNode.getStr("") == "":
      result.add(ValidationError(line: entryNum,
        message: fmt"Entry {entryNum}: 'request.path' is required"))

    if meth == nil or meth.getStr("") == "":
      result.add(ValidationError(line: entryNum,
        message: fmt"Entry {entryNum}: 'request.method' is required"))

    # is_regex true but path has no regex metacharacters
    if isRegex != nil and isRegex.getBool(false):
      let p = pathNode.getStr("")
      let hasRegexChars = "(" in p or "[" in p or "+" in p or
                          "*" in p or "?" in p or "^" in p or
                          "$" in p or "|" in p or "\\" in p
      if not hasRegexChars:
        result.add(ValidationError(line: entryNum,
          message: fmt"Entry {entryNum}: 'is_regex' is true but path '{p}' contains no regex pattern"))

    # is_regex false/absent but path looks like a regex
    if isRegex == nil or not isRegex.getBool(false):
      let p = pathNode.getStr("")
      if "(" in p or "[" in p:
        result.add(ValidationError(line: entryNum,
          message: fmt"Entry {entryNum}: path '{p}' looks like a regex but 'is_regex' is not set to true"))

    # validate the regex compiles
    if isRegex != nil and isRegex.getBool(false):
      try:
        discard re(pathNode.getStr(""))
      except RegexError as e:
        result.add(ValidationError(line: entryNum,
          message: fmt"Entry {entryNum}: 'request.path' is not a valid regex: {e.msg}"))

    # method must be a known verb or wildcard
    if meth != nil:
      let m = meth.getStr("").toUpperAscii()
      if m notin ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS", "*"]:
        result.add(ValidationError(line: entryNum,
          message: fmt"Entry {entryNum}: unknown HTTP method '{m}'"))

    # ── must have response, responses, or proxy ──────────────────────────
    let hasResponse = entry{"response"} != nil
    let hasResponses = entry{"responses"} != nil and
                       entry["responses"].kind == JArray and
                       entry["responses"].elems.len > 0
    let hasProxy = entry{"proxy"} != nil

    if not hasResponse and not hasResponses and not hasProxy:
      result.add(ValidationError(line: entryNum,
        message: fmt"Entry {entryNum}: must have at least one of 'response', 'responses', or 'proxy'"))

    # ── cycle needs responses, not response ──────────────────────────────
    let cycle = entry{"cycle"}
    if cycle != nil and cycle.getBool(false):
      if not hasResponses:
        result.add(ValidationError(line: entryNum,
          message: fmt"Entry {entryNum}: 'cycle' is true but 'responses' list is missing or empty"))
      if hasResponse:
        result.add(ValidationError(line: entryNum,
          message: fmt"Entry {entryNum}: use 'responses' (plural) with 'cycle', not 'response'"))

    # ── proxy needs a url ────────────────────────────────────────────────
    if hasProxy:
      let proxyUrl = entry["proxy"]{"url"}
      if proxyUrl == nil or proxyUrl.getStr("") == "":
        result.add(ValidationError(line: entryNum,
          message: fmt"Entry {entryNum}: 'proxy' block is missing required 'url'"))

    # ── response status should be a valid HTTP code ──────────────────────
    if hasResponse:
      let status = entry["response"]{"status"}
      if status != nil:
        let code = status.getInt(0)
        if code < 100 or code > 599:
          result.add(ValidationError(line: entryNum,
            message: fmt"Entry {entryNum}: 'response.status' {code} is not a valid HTTP status code"))
    # ── Error rate should be between 0.0 and 1.0 ──────────────────────
    let entryErrorRate = entry{"error_rate"}
    if entryErrorRate != nil:
      let rate = entryErrorRate.getFloat(0.0)
      if rate < 0.0 or rate > 1.0:
        result.add(ValidationError(line: entryNum,
          message: fmt"Entry {entryNum}: root 'error_rate' must be between 0.0 and 1.0, got {rate}"))

    if hasResponse:
      let errorRate = entry["response"]{"error_rate"}
      if errorRate != nil:
        let rate = errorRate.getFloat(0.0)
        if rate < 0.0 or rate > 1.0:
          result.add(ValidationError(line: entryNum,
            message: fmt"Entry {entryNum}: 'response.error_rate' must be between 0.0 and 1.0, got {rate}"))
    # ── faker tags in response body ──────────────────────────────────────
    if hasResponse:
      let body = entry["response"]{"body"}
      if body != nil and body.kind == JString:
        result.add checkFakerTags(body.getStr(), entryNum, "response.body")

    if hasResponses:
      for j, res in entry["responses"].elems:
        let body = res{"body"}
        if body != nil and body.kind == JString:
          result.add checkFakerTags(body.getStr(), entryNum,
            fmt"responses[{j}].body")

proc printValidationErrors*(errors: seq[ValidationError]) =
  for err in errors:
    let loc = if err.line > 0: fmt"entry {err.line}" else: "config"
    stdout.styledWriteLine(fgRed, "Config Error ", fgYellow, fmt"[{loc}]",
      fgWhite, ": " & err.message)
