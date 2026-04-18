import std/[strutils, tables, json]
import times
import faker
import random
randomize()

var gStore* = initTable[string, string]()

let fake = newFaker()

proc userName(): string =
  fake.firstName() & $rand(100)

proc getSystemTimeUtc*(): string =
  let now = getTime() # Gets the current Time (Unix timestamp)
  let utcTime = now.utc() # Converts to a DateTime object in UTC
  return utcTime.format("yyyy-MM-dd HH:mm:ss 'UTC'")

proc resolveFaker*(tag: string): string {.gcsafe.} =
  {.cast(gcsafe).}:
    case tag
    of "name":
      fake.name()
    of "firstName", "first_name":
      fake.firstName()
    of "lastName", "last_name":
      fake.lastName()
    of "email":
      fake.email()
    of "safeEmail", "safe_email":
      fake.safeEmail()
    of "username", "userName":
      userName()
    of "phone", "phoneNumber", "phone_number":
      fake.phoneNumber()
    of "address":
      fake.address()
    of "city":
      fake.city()
    of "country":
      fake.country()
    of "postcode", "zipcode", "zip":
      fake.postcode()
    of "streetAddress", "street_address":
      fake.streetAddress()
    of "company":
      fake.company()
    of "companySuffix", "company_suffix":
      fake.companySuffix()
    of "job":
      fake.job()
    of "bs":
      fake.bs()
    of "catchPhrase", "catch_phrase":
      fake.catchPhrase()
    of "word":
      fake.word()
    of "ssn":
      fake.ssn()
    of "md5":
      fake.md5()
    of "sha1":
      fake.sha1()
    of "mimeType", "mime_type":
      fake.mimeType()
    of "fileExtension", "file_extension":
      fake.fileExtension()
    of "fileName", "file_name":
      fake.fileName()
    of "filePath", "file_path":
      fake.filePath()
    of "userAgent", "user_agent":
      fake.userAgent()
    of "iban":
      fake.iban()
    of "currency":
      fake.currencyName()
    of "currencyCode", "currency_code":
      fake.currencyCode()
    of "currencyName", "currency_name":
      fake.currencyName()
    of "boolean", "bool":
      $fake.boolean()
    of "uuid":
      fake.md5()
    of "timestamp":
      getSystemTimeUtc()
    else:
      "{{" & tag & "}}"

proc resolveTag*(tag: string, reqBody: string = ""): string {.gcsafe.} =
  if tag == "req.body":
    return reqBody
  if tag.startsWith("req.json."):
    let path = tag[9 ..^ 1]
    try:
      let j = parseJson(reqBody)
      var curr = j
      for part in path.split('.'):
        curr = curr[part]
      return
        if curr.kind == JString:
          curr.getStr()
        else:
          $curr
    except:
      return ""
  if tag.startsWith("store."):
    let key = tag[6 ..^ 1]
    {.cast(gcsafe).}:
      return gStore.getOrDefault(key, "")
  return resolveFaker(tag)

proc applyFakers*(body: string, reqBody: string = ""): string {.gcsafe.} =
  result = body
  var i = 0
  while i < result.len:
    let s = result.find("{{", i)
    if s < 0:
      break
    let e = result.find("}}", s + 2)
    if e < 0:
      break
    let tag = result[s + 2 ..< e].strip()
    let replacement = resolveTag(tag, reqBody)
    result = result[0 ..< s] & replacement & result[e + 2 .. ^1]
    i = s + replacement.len
