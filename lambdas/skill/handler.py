import json
import os
import uuid

import boto3

bedrock_agent_runtime = boto3.client("bedrock-agent-runtime")

AGENT_ID = os.environ["AGENT_ID"]
AGENT_ALIAS_ID = os.environ["AGENT_ALIAS_ID"]


CONFIRMATION_WORDS = {"confirmo", "confirmado", "afirmativo", "correcto", "exacto", "dale", "adelante", "procede", "proceder"}

def invoke_agent(message: str, session_id: str) -> str:
    print(f"invoke_agent session={session_id} message={message!r}")
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
    print(f"invoke_agent response={completion!r}")
    return completion


def handle_alexa(event: dict) -> dict:
    request_type = event["request"]["type"]
    session_id = event["session"]["sessionId"]

    if request_type == "LaunchRequest":
        speech = "Hola, soy tu asistente de aerolínea. ¿En qué te puedo ayudar?"
        return alexa_response(speech, reprompt="¿Quieres reservar un vuelo o consultar una reservación?")

    if request_type == "IntentRequest":
        intent = event["request"]["intent"]["name"]

        if intent in ("AMAZON.CancelIntent", "AMAZON.StopIntent"):
            return alexa_response("Hasta luego.", end_session=True)

        if intent == "AMAZON.HelpIntent":
            return alexa_response(
                "Puedo ayudarte a reservar vuelos o consultar tus reservaciones. ¿Qué necesitas?",
                reprompt="¿Quieres reservar un vuelo?",
            )

        if intent == "AMAZON.FallbackIntent":
            answer = invoke_agent("no entendí bien lo que dijiste, ¿puedes repetirlo?", session_id)
            return alexa_response(answer, reprompt="Di sí para confirmar o no para cancelar.")

        if intent in ("ChatIntent", "AMAZON.YesIntent"):
            slots = event["request"]["intent"].get("slots", {})
            query = slots.get("query", {}).get("value") or "sí"
            words = set(query.lower().split())
            if words & CONFIRMATION_WORDS:
                query = "sí, confirmo"
            answer = invoke_agent(query, session_id)
            if "confirmas" in answer.lower() or "confirma" in answer.lower():
                reprompt = "Di sí para confirmar o no para cancelar."
            else:
                reprompt = "¿Hay algo más en lo que te pueda ayudar?"
            return alexa_response(answer, reprompt=reprompt)

        if intent == "AMAZON.NoIntent":
            answer = invoke_agent("no, cancela", session_id)
            return alexa_response(answer, reprompt="¿En qué más te puedo ayudar?")

    if request_type == "SessionEndedRequest":
        return {"version": "1.0", "response": {}}

    return alexa_response("No entendí eso. ¿Puedes repetirlo?")


def handle_http(event: dict) -> dict:
    body = json.loads(event.get("body") or "{}")
    message = body.get("message", "")
    session_id = body.get("session_id") or str(uuid.uuid4())
    completion = invoke_agent(message, session_id)
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"session_id": session_id, "response": completion}),
    }


def alexa_response(speech: str, reprompt: str = None, end_session: bool = False) -> dict:
    response = {
        "outputSpeech": {"type": "PlainText", "text": speech},
        "shouldEndSession": end_session,
    }
    if reprompt:
        response["reprompt"] = {"outputSpeech": {"type": "PlainText", "text": reprompt}}
    return {"version": "1.0", "response": response}


def lambda_handler(event, context):
    print(json.dumps(event))
    if "session" in event:
        return handle_alexa(event)
    return handle_http(event)
