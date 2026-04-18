import asynchttpserver, re, strutils, options, json, tables
import ../configType

proc matchRequest*(req: Request, entry: ContractEntry, captures: var seq[string]): bool =
  let methodMatches =
    entry.request.`method` == "*" or
    entry.request.`method`.toUpperAscii() == $req.reqMethod
  if not methodMatches:
    return false

  # JSON Body Matching
  if entry.request.match_body.isSome:
    let expected = entry.request.match_body.get()
    if req.body == "": return false
    try:
      let actual = parseJson(req.body)
      for k, v in expected:
        let actualVal = if actual{k} != nil:
                          if actual[k].kind == JString: actual[k].getStr()
                          else: $actual[k]
                        else: ""
        if actualVal != v:
          return false
    except:
      return false

  if entry.request.is_regex.get(false):
    var m: array[10, string]
    if req.url.path.match(re(entry.request.path), m):
      captures = @[]
      for val in m:
        if val != "":
          captures.add(val)
      return true
    return false
  else:
    return req.url.path == entry.request.path
