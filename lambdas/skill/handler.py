import json
import os
import uuid

import boto3

bedrock_agent_runtime = boto3.client("bedrock-agent-runtime")

AGENT_ID = os.environ["AGENT_ID"]
AGENT_ALIAS_ID = os.environ["AGENT_ALIAS_ID"]


def lambda_handler(event, context):
    print(json.dumps(event))

    body = json.loads(event.get("body") or "{}")
    message = body.get("message", "")
    session_id = body.get("session_id") or str(uuid.uuid4())

    response = bedrock_agent_runtime.invoke_agent(
        agentId=AGENT_ID,
        agentAliasId=AGENT_ALIAS_ID,
        sessionId=session_id,
        inputText=message,
    )

    completion = ""
    for chunk in response["completion"]:
        if "chunk" in chunk:
            completion += chunk["chunk"]["bytes"].decode("utf-8")

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"session_id": session_id, "response": completion}),
    }
