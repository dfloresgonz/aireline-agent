import json
import os
import uuid
from datetime import datetime, timezone

import boto3

dynamodb = boto3.resource("dynamodb")


def lambda_handler(event, context):
    print(json.dumps(event))

    action_group = event.get("actionGroup")
    function = event.get("function")
    parameters = {p["name"]: p["value"] for p in event.get("parameters", [])}

    reservation_id = str(uuid.uuid4())[:8].upper()
    table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
    table.put_item(
        Item={
            "reservation_id": reservation_id,
            "passenger_name": parameters.get("passenger_name"),
            "flight_number": parameters.get("flight_number"),
            "departure_date": parameters.get("departure_date"),
            "seat_class": parameters.get("seat_class", "economy"),
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
