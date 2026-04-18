import json
import os
import uuid
from datetime import datetime, timezone

import boto3

dynamodb = boto3.resource("dynamodb")

REQUIRED = ["passenger_name", "flight_number", "departure_date"]


def lambda_handler(event, context):
    print(json.dumps(event))

    action_group = event.get("actionGroup")
    function = event.get("function")
    parameters = {p["name"]: p["value"] for p in event.get("parameters", [])}

    missing = [f for f in REQUIRED if not parameters.get(f, "").strip()]
    if missing:
        body = {"error": f"Missing required fields: {', '.join(missing)}"}
        return {
            "messageVersion": "1.0",
            "response": {
                "actionGroup": action_group,
                "function": function,
                "functionResponse": {
                    "responseState": "FAILURE",
                    "responseBody": {"TEXT": {"body": json.dumps(body)}},
                },
            },
        }

    reservation_id = str(uuid.uuid4())[:8].upper()
    table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
    table.put_item(
        Item={
            "reservation_id": reservation_id,
            "passenger_name": parameters["passenger_name"].strip(),
            "flight_number": parameters["flight_number"].replace(" ", "").upper(),
            "departure_date": parameters["departure_date"].strip(),
            "seat_class": parameters.get("seat_class", "economy").strip() or "economy",
            "status": "confirmed",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
    )

    return {
        "messageVersion": "1.0",
        "response": {
            "actionGroup": action_group,
            "function": function,
            "functionResponse": {
                "responseBody": {
                    "TEXT": {
                        "body": json.dumps(
                            {
                                "reservation_id": reservation_id,
                                "status": "confirmed",
                                "message": f"Reservation {reservation_id} created successfully",
                            }
                        )
                    }
                }
            },
        },
    }
