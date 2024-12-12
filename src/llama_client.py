import requests
from models_config import OLLAMA_BASE_URL, OLLAMA_MODELS


def query_llama(prompt):
    """Legacy method updated to use Ollama port"""
    response = requests.post(
        f"{OLLAMA_BASE_URL}/api/generate",
        json={"model": "llama3.1:latest", "prompt": prompt},  # default model
    )
    response.raise_for_status()
    return response.json()


class OllamaClient:
    def __init__(self):
        self.base_url = OLLAMA_BASE_URL  # Now using port 11434

    def query_model(self, model_name: str, prompt: str):
        if model_name not in OLLAMA_MODELS:
            raise ValueError(f"Unknown model: {model_name}")

        model_config = OLLAMA_MODELS[model_name]

        response = requests.post(
            f"{self.base_url}/api/generate",
            json={
                "model": model_config["model"],
                "prompt": prompt,
                "temperature": model_config["temperature"],
                "max_tokens": model_config["max_tokens"],
            },
        )
        response.raise_for_status()
        return response.json()
