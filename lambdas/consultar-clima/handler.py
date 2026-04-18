import json
import os
import urllib.request

MCP_SERVER_URL = os.environ["MCP_SERVER_URL"]


def mcp_request(method: str, params: dict = None, req_id: int = 1) -> dict:
    payload = {"jsonrpc": "2.0", "id": req_id, "method": method}
    if params:
        payload["params"] = params
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        MCP_SERVER_URL,
        data=data,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def lambda_handler(event, context):
    print(json.dumps(event))

    action_group = event.get("actionGroup")
    function = event.get("function")
    parameters = {p["name"]: p["value"] for p in event.get("parameters", [])}
    city = parameters.get("city", "").strip()

    try:
        mcp_request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "bedrock-mcp-client", "version": "1.0"},
            },
        )
        response = mcp_request(
            "tools/call",
            {"name": "consultar_clima", "arguments": {"city": city}},
            req_id=2,
        )
        content = response.get("result", {}).get("content", [{}])
        body = json.loads(content[0].get("text", "{}"))
    except Exception as e:
        body = {"error": str(e)}

    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": action_group,
            "function": function,
            "functionResponse": {
                "responseBody": {"TEXT": {"body": json.dumps(body)}}
            },
        },
    }
