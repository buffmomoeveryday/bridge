import unittest, asynchttpserver, options, tables, uri
import ../src/http/router
import ../src/configType

# Helper to create a dummy request
proc dummyReq(meth: HttpMethod, path: string, body: string = ""): Request =
  Request(
    reqMethod: meth,
    url: parseUri("http://localhost" & path),
    body: body,
    headers: newHttpHeaders()
  )

suite "Router Matching":
  test "matchRequest - Simple Path":
    let req = dummyReq(HttpGet, "/api/me")
    let entry = ContractEntry(
      request: RequestConfig(path: "/api/me", `method`: "GET")
    )
    var captures: seq[string] = @[]
    check(matchRequest(req, entry, captures) == true)

  test "matchRequest - Method Mismatch":
    let req = dummyReq(HttpPost, "/api/me")
    let entry = ContractEntry(
      request: RequestConfig(path: "/api/me", `method`: "GET")
    )
    var captures: seq[string] = @[]
    check(matchRequest(req, entry, captures) == false)

  test "matchRequest - JSON Body Matching":
    let req = dummyReq(HttpPost, "/api/login", """{"user": "admin"}""")
    let entry = ContractEntry(
      request: RequestConfig(
        path: "/api/login",
        `method`: "POST",
        match_body: some({"user": "admin"}.toTable)
      )
    )
    var captures: seq[string] = @[]
    check(matchRequest(req, entry, captures) == true)
    
    let reqFail = dummyReq(HttpPost, "/api/login", """{"user": "guest"}""")
    check(matchRequest(reqFail, entry, captures) == false)
