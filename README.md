# Bridge

Bridge is a high performance and lightweight CLI tool designed to bridge the development gap between frontend and backend teams. It allows developers to define API contracts in YAML to mock responses, capture regex groups, simulate network latency, and proxy requests during development.

## Quick Start

### Installation

Ensure you have Nim 2.2.6 or later installed.

```bash
git clone https://github.com/siddharthakhanal/bridge.git
cd bridge
nimble build
```

The binary will be generated as ./bridge.

### Basic Usage

Start the server using the example configuration:

```bash
./bridge serve --config example/config.yaml --port 42069
```

## Key Features

### Static and Dynamic Mocking
Define simple JSON, HTML, or text responses. Use template variables for dynamic data generation.

### Response Cycling
Rotate through a sequence of responses to test state changes or intermittent error handling.

### Regex Pattern Matching and Substitution
Capture segments of the URL path and reuse them in your response body using capture groups such as $1 or $2.

### Transparent Proxying
Forward requests to an upstream server with custom headers and configurable timeouts.

### Latency Simulation
Simulate slow connections by adding a delay_ms field to any contract.

### OpenAPI Integration
Convert existing OpenAPI specifications directly into Bridge contracts.

### Postman Support
Import existing Postman collections to jumpstart your mocks or export your Bridge contracts back to Postman for team collaboration.

### Environment Variable Support
Use shell environment variables within your configuration files using the ${ VAR } or ${VAR:-default} syntax.

### Hot Reloading
The server automatically watches your configuration file for changes and reloads rules without requiring a restart.

### Chaos Engineering
Inject random failures into your API by specifying an error_rate at either the individual response or the entire contract level.

## Configuration Guide

Contracts are defined in a config.yaml file. You can root your contracts directly as a list or under a contracts key.

### Basic Contract
```yaml
- request:
    path: "/health"
    method: "GET"
  response:
    status: 200
    body: '{"status": "ok"}'
```

### JSON Body Matching
Route requests to different mocks based on the content of the request body using `match_body`.
```yaml
- request:
    path: "/api/login"
    method: "POST"
    match_body:
      username: "admin"
  response:
    body: '{"token": "secret-admin-token"}'
```

### Dynamic Templating with Faker
Bridge integrates with a faker system to generate realistic dummy data.
```yaml
- request:
    path: "/api/me"
    method: "GET"
  response:
    body: |
      {
        "id": "{{uuid}}",
        "name": "{{name}}",
        "email": "{{email}}",
        "bio": "{{catchPhrase}}"
      }
```

### Regex and Capture Groups
Match complex paths and extract values for your response.
```yaml
- request:
    path: "/api/users/(\\d+)"
    is_regex: true
    method: "GET"
  response:
    body: '{"id": $1, "name": "{{name}}", "status": "active"}'
```

### Response Cycling
Rotate through a sequence of responses to test varying states, like delayed eventual consistency.
```yaml
- request:
    path: "/status"
    method: "GET"
  cycle: true
  responses:
    - { status: 202, body: "Processing..." }
    - { status: 202, body: "Still processing..." }
    - { status: 200, body: "Done!" }
```

### Stateful Mocking (Variables)
Persist data across requests using `store`. Supported actions are `set`, `append`, and `inc`.
```yaml
- request:
    path: "/counter/increment"
    method: "POST"
  store:
    action: "inc"
    key: "counter_val"
    value: "1"
  response:
    body: '{"message": "Incremented"}'

- request:
    path: "/counter"
    method: "GET"
  response:
    body: '{"count": {{store.counter_val}} }'
```

### Advanced Proxying with Environment Variables
Use environment variables using `${VAR}`.
```yaml
- request:
    path: "/api/v1/(.*)"
    is_regex: true
    method: "*"
  proxy:
    url: "${UPSTREAM_URL:-https://production-api.com/}"
    timeout_ms: 5000
```

### Chaos Engineering and Error Rates
Inject random failures either per-route or globally.
```yaml
- request:
    path: "/unreliable"
    method: "GET"
  response:
    error_rate: 0.3 # 30% chance to fail with 500 status
    body: "Success!"
```

### Latency Simulation and Network Throttling
Simulate variable network connections with jitter and slow streaming.
```yaml
- request:
    path: "/api/flakey"
    method: "GET"
  response:
    latency_range: "500-2000" # Random delay between 0.5s and 2s
    throttle_kbps: 50.0 # Throttle streaming speed to 50 KB/s
    body: '{"status": "eventually loaded"}'
```


## CLI Commands

### Run Server
```bash
./bridge serve --config config.yaml --port 42069 --watch
```
* -c, --config: Path to YAML config (default: config.yaml).
* -p, --port: Port to listen on (default: 42069).
* -w, --watch: Enable or disable configuration watching (default: true).
* -O, --openapi: Treat the config file as an OpenAPI specification instead of a Bridge contract (default: false).

### Convert OpenAPI
```bash
./bridge convertOpenAPI --openapi spec.json --output bridge-contract.yaml
```
* -f, --openapi: Path to the OpenAPI specification file.
* -o, --output: Filename for the generated Bridge contract.

### Import Postman Collection
```bash
./bridge importPostman --input collection.json --output bridge-contract.yaml
```
* -i, --input: Path to the Postman collection JSON.
* -o, --output: Filename for the generated Bridge contract.

### Export to Postman
```bash
./bridge exportPostman --config config.yaml --output postman-collection.json
```
* -c, --config: Path to the Bridge configuration file.
* -o, --output: Filename for the exported Postman collection.

## Available Template Tags

| Tag | Description |
| :--- | :--- |
| {{name}} | Full name |
| {{email}} | Random email address |
| {{timestamp}} | Current UTC timestamp |
| {{uuid}} | Random UUID |
| {{city}} | City name |
| {{country}} | Country name |
| {{company}} | Random company name |
| {{job}} | Random job title |
| {{boolean}} | true or false |
| {{userAgent}} | Browser user agent string |
| {{currencyCode}} | Random currency code |
| {{ssn}} | Random Social Security Number |

## License

Distributed under the MIT License.

Built with Nim
