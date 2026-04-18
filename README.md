# Airline Agent Demo

Agente conversacional para aerolíneas construido sobre **Amazon Bedrock Agents**. Permite reservar vuelos, consultar reservaciones y responder preguntas sobre políticas de equipaje, cancelaciones y mascotas — a través de una Lambda HTTP o una Alexa Skill.

## Arquitectura

```
Usuario / Alexa
      │
      ▼
┌─────────────────┐
│  skill Lambda   │  ← HTTP (Function URL) o Alexa SDK
│  (entry point)  │
└────────┬────────┘
         │ InvokeAgent
         ▼
┌─────────────────────────────────────────────────────┐
│               Amazon Bedrock Agent                  │
│  foundation model: Claude 3 Haiku                   │
│                                                     │
│  ┌──────────────────┐   ┌───────────────────────┐  │
│  │  Action Groups   │   │    Knowledge Base     │  │
│  │  ┌────────────┐  │   │  Titan Embed v2       │  │
│  │  │  reservar  │──┼──▶│  S3 Vectors (index)   │  │
│  │  │   vuelo    │  │   │  docs: equipaje,      │  │
│  │  └────────────┘  │   │  cancelaciones,       │  │
│  │  ┌────────────┐  │   │  mascotas             │  │
│  │  │ consultar  │  │   └───────────────────────┘  │
│  │  │  reserva  │  │                               │
│  │  └────────────┘  │                               │
│  └──────────────────┘                               │
└────────────┬────────────────────────────────────────┘
             │ InvokeFunction
    ┌────────┴────────┐
    │                 │
    ▼                 ▼
┌────────┐     ┌──────────────────┐
│reserva │     │ consultar-reserva│
│ Lambda │     │     Lambda       │
└───┬────┘     └────────┬─────────┘
    │                   │
    └─────────┬─────────┘
              ▼
       ┌─────────────┐
       │  DynamoDB   │
       │ reservations│
       └─────────────┘

┌──────────────────────┐
│  MCP Weather Tool    │  ← servidor local MCP (no Lambda)
│  mcp/weather-tool/   │
└──────────────────────┘
```

## Estructura del proyecto

```
airline-agent-demo/
│
├── lambdas/
│   ├── skill/               # Entry point: recibe mensajes e invoca el agente
│   ├── reserva/             # Acción: crea una reservación en DynamoDB
│   └── consultar-reserva/   # Acción: consulta una reservación por ID
│
├── mcp/
│   └── weather-tool/        # Servidor MCP local para consulta de clima
│
├── knowledge-base/
│   └── docs/
│       ├── equipaje.md
│       ├── cancelaciones.md
│       └── mascotas.md
│
├── agent/
│   └── schemas/             # Esquemas de funciones del agente (referencia)
│       ├── reservar-vuelo.json
│       └── consultar-reserva.json
│
├── alexa/                   # Alexa Skill manifest e interaction model (es-ES)
│
├── infra/                   # Terraform
│   ├── main.tf
│   └── modules/
│       ├── dynamodb/
│       ├── iam/
│       ├── lambdas/
│       └── bedrock-agent/   # Agent + KB + S3 Vectors + Action Groups
│
├── scripts/
│   ├── deploy.sh
│   ├── destroy.sh
│   └── seed-kb.sh
│
├── Makefile
└── .env.example
```

## Prerrequisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configurado (`aws configure`)
- Python 3.12 (solo para desarrollo local)
- Acceso a modelos habilitado en Bedrock (región `us-east-1`):
  - `anthropic.claude-3-haiku-20240307-v1:0`
  - `amazon.titan-embed-text-v2:0`

## Quick start

### 1. Configurar variables de entorno

```bash
cp .env.example .env
# editar .env con tu región y perfil de AWS si es necesario
```

### 2. Desplegar infraestructura

```bash
make deploy
```

Al finalizar se imprimen los outputs:

```
agent_id                    = "XXXXXXXXXX"
agent_alias_id              = "YYYYYYYYYY"
knowledge_base_id           = "ZZZZZZZZZZ"
skill_function_url          = "https://xxxxxxxx.lambda-url.us-east-1.on.aws/"
reserva_function_name       = "airlines-app-dev-reserva"
consultar_reserva_function_name = "airlines-app-dev-consultar-reserva"
```

### 3. Cargar documentos en la Knowledge Base

```bash
make seed
```

Sube los `.md` de `knowledge-base/docs/` a S3 y dispara el ingestion job. Espera ~1-2 minutos a que el job finalice antes de probar.

### 4. Probar

```bash
# Nueva conversación
curl -X POST <skill_function_url> \
  -H "Content-Type: application/json" \
  -d '{"message": "quiero reservar un vuelo"}'

# Continuar sesión
curl -X POST <skill_function_url> \
  -H "Content-Type: application/json" \
  -d '{"message": "para Juan Pérez, vuelo AA123, el 2025-05-20", "session_id": "<session_id>"}'

# Consultar política de equipaje (KB)
curl -X POST <skill_function_url> \
  -H "Content-Type: application/json" \
  -d '{"message": "cuántas maletas puedo llevar en economy?"}'
```

## API de la skill Lambda

**Request**

```json
{
  "message": "quiero reservar un vuelo",
  "session_id": "opcional-para-continuar-conversacion"
}
```

**Response**

```json
{
  "session_id": "abc-123",
  "response": "Con gusto te ayudo a reservar un vuelo. ¿A qué destino..."
}
```

## Capacidades del agente

| Capacidad | Fuente |
|---|---|
| Reservar vuelo | Lambda `reserva` → DynamoDB |
| Consultar reservación | Lambda `consultar-reserva` → DynamoDB |
| Políticas de equipaje | Knowledge Base (RAG) |
| Políticas de cancelación | Knowledge Base (RAG) |
| Viaje con mascotas | Knowledge Base (RAG) |
| Consulta de clima | MCP Weather Tool (local) |

## MCP Weather Tool

Servidor MCP local para integrar consulta de clima con agentes que soporten el protocolo MCP.

```bash
cd mcp/weather-tool
pip install -r requirements.txt
python server.py
```

## Makefile

```
make deploy    # terraform init + apply + outputs
make seed      # sube docs a S3 y dispara ingestion job
make destroy   # destruye toda la infraestructura (pide confirmación)
```

## Infraestructura desplegada

| Recurso | Descripción |
|---|---|
| `aws_bedrockagent_agent` | Agente Bedrock con Claude 3 Haiku |
| `aws_bedrockagent_knowledge_base` | KB con Titan Embed v2 |
| `aws_s3vectors_vector_bucket` | Vector store (pay-per-use, sin costo fijo) |
| `aws_s3vectors_index` | Índice vectorial (cosine, 1024 dims, float32) |
| `aws_s3_bucket` | Bucket S3 para documentos fuente |
| `aws_dynamodb_table` | Tabla de reservaciones (PAY_PER_REQUEST) |
| `aws_lambda_function` × 3 | skill, reserva, consultar-reserva |
| `aws_iam_role` × 3 | Lambda, Bedrock Agent, Knowledge Base |

## Alexa developer console

```bash
npm install -g ask-cli
ask configure
make alexa
```

## Destruir

```bash
make destroy
```

Pide confirmación antes de ejecutar. Elimina todos los recursos de AWS.
