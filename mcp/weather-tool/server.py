from mcp.server.fastmcp import FastMCP

mcp = FastMCP("weather-tool")

MOCK_WEATHER: dict[str, dict] = {
    "miami": {"temp": "28°C", "condition": "Sunny", "humidity": "75%"},
    "new york": {"temp": "12°C", "condition": "Cloudy", "humidity": "60%"},
    "los angeles": {"temp": "22°C", "condition": "Clear", "humidity": "50%"},
    "chicago": {"temp": "8°C", "condition": "Windy", "humidity": "65%"},
    "london": {"temp": "10°C", "condition": "Rainy", "humidity": "80%"},
    "lima": {"temp": "18°C", "condition": "Overcast", "humidity": "85%"},
    "bogota": {"temp": "14°C", "condition": "Partly Cloudy", "humidity": "70%"},
}


@mcp.tool()
def get_weather(city: str) -> dict:
    """Return current weather conditions for a given city."""
    key = city.lower().strip()
    weather = MOCK_WEATHER.get(key, {"temp": "N/A", "condition": "Unknown", "humidity": "N/A"})
    return {"city": city, **weather}


if __name__ == "__main__":
    mcp.run()
