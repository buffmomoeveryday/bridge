import yaml, yaml/annotations, options, tables

type
  RequestConfig* {.sparse.} = object
    path*: string
    `method`*: string
    is_regex* {.defaultVal: none(bool).}: Option[bool]
    match_body* {.defaultVal: none(Table[string, string]).}: Option[Table[string, string]]

  ResponseConfig* {.sparse.} = object
    status* {.defaultVal: none(int).}: Option[int]
    body* {.defaultVal: none(string).}: Option[string]
    headers* {.defaultVal: none(Table[string, string]).}: Option[Table[string, string]]
    delay_ms* {.defaultVal: none(int).}: Option[int]
    latency_range* {.defaultVal: none(string).}: Option[string]     # e.g., "100-2000"
    throttle_kbps* {.defaultVal: none(float).}: Option[float]      # e.g., 50.0 for 50KB/s
    error_rate* {.defaultVal: none(float).}: Option[float]         # 0.0 - 1.0

  ProxyConfig* {.sparse.} = object
    url*: string
    timeout_ms* {.defaultVal: none(int).}: Option[int]
    headers* {.defaultVal: none(Table[string, string]).}: Option[Table[string, string]]

  StoreConfig* {.sparse.} = object
    key*: string
    action* {.defaultVal: some("set").}: Option[string]
    value* {.defaultVal: none(string).}: Option[string]

  ContractEntry* {.sparse.} = object
    request*: RequestConfig
    response* {.defaultVal: none(ResponseConfig).}: Option[ResponseConfig]
    responses* {.defaultVal: none(seq[ResponseConfig]).}: Option[seq[ResponseConfig]]
    proxy* {.defaultVal: none(ProxyConfig).}: Option[ProxyConfig]
    cycle* {.defaultVal: none(bool).}: Option[bool]
    headers* {.defaultVal: none(Table[string, string]).}: Option[Table[string, string]]
    error_rate* {.defaultVal: none(float).}: Option[float]
    store* {.defaultVal: none(StoreConfig).}: Option[StoreConfig]

type
  BridgeContract* {.sparse.} = object
    openapi* {.defaultVal: some("3.0.0").}: Option[string]
    info* {.defaultVal: none(Table[string, string]).}: Option[Table[string, string]]
    contracts*: seq[ContractEntry]
