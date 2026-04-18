import json
import urllib.parse
import urllib.request

TOOLS = [
    {
        "name": "consultar_clima",
        "description": "Returns current temperature and weather condition for a city",
        "inputSchema": {
            "type": "object",
            "properties": {
                "city": {
                    "type": "string",
                    "description": "City name (e.g. Miami, Madrid, Mexico City)",
                }
            },
            "required": ["city"],
        },
    }
]


def get_weather(city: str) -> dict:
    url = f"https://wttr.in/{urllib.parse.quote(city)}?format=j1"
    with urllib.request.urlopen(url, timeout=5) as resp:
        data = json.loads(resp.read())
    cc = data["current_condition"][0]
    return {
        "city": city,
        "temp_c": cc["temp_C"],
        "feels_like_c": cc["FeelsLikeC"],
        "condition": cc["weatherDesc"][0]["value"],
        "humidity_pct": cc["humidity"],
    }


def handle(body: dict) -> dict:
    method = body.get("method")
    req_id = body.get("id")

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "weather-mcp-server", "version": "1.0"},
            },
        }

    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}

    if method == "tools/call":
        params = body.get("params", {})
        name = params.get("name")
        args = params.get("arguments", {})
        if name == "consultar_clima":
            try:
                result = get_weather(args.get("city", ""))
                text = json.dumps(result)
            except Exception as e:
                text = json.dumps({"error": str(e)})
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {"content": [{"type": "text", "text": text}]},
            }

    return {
        "jsonrpc": "2.0",
        "id": req_id,
        "error": {"code": -32601, "message": f"Method not found: {method}"},
    }


def lambda_handler(event, context):
    print(json.dumps(event))
    body = json.loads(event.get("body") or "{}")
    result = handle(body)
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(result),
    }
