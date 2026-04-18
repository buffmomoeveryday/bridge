import unittest, tables
import ../src/http/fakerProvider

suite "Faker Provider":
  test "resolveTag - basic faker":
    let name = resolveTag("firstName")
    check(name.len > 0)
  
  test "resolveTag - req.body":
    let res = resolveTag("req.body", "hello world")
    check(res == "hello world")
    
  test "resolveTag - req.json":
    let body = """{"user": {"id": 123}}"""
    let res = resolveTag("req.json.user.id", body)
    check(res == "123")

  test "applyFakers - multiple tags":
    let body = "Hello {{req.json.name}}!"
    let req = """{"name": "Alice"}"""
    let res = applyFakers(body, req)
    check(res == "Hello Alice!")

  test "stateful store":
    # Clear store for test
    gStore.clear()
    gStore["score"] = "10"
    let res = resolveTag("store.score")
    check(res == "10")
