import json
import os

import boto3

dynamodb = boto3.resource("dynamodb")


def lambda_handler(event, context):
    print(json.dumps(event))

    action_group = event.get("actionGroup")
    function = event.get("function")
    parameters = {p["name"]: p["value"] for p in event.get("parameters", [])}

    reservation_id = parameters.get("reservation_id", "").replace(" ", "").upper()
    table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
    response = table.get_item(Key={"reservation_id": reservation_id})

    item = response.get("Item")
    if item:
        body = item
    else:
        body = {"error": f"Reservation {reservation_id} not found"}

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
