from typing import Any, Dict

import requests
from models_config import API_MODELS


class APIClient:
    def __init__(self):
        self.providers = API_MODELS

    def query_model(self, provider: str, model: str, prompt: str) -> Dict[str, Any]:
        if provider not in self.providers:
            raise ValueError(f"Unknown provider: {provider}")

        provider_config = self.providers[provider]
        if model not in provider_config["models"]:
            raise ValueError(f"Unknown model {model} for provider {provider}")

        headers = {"Authorization": f"Bearer {provider_config['api_key']}"}

        # Adjust request based on provider
        if provider == "mistral":
            endpoint = f"{provider_config['base_url']}/chat/completions"
            data = {"model": model, "messages": [{"role": "user", "content": prompt}]}
        elif provider in ["deepseek", "xai"]:
            endpoint = f"{provider_config['base_url']}/completions"
            data = {
                "model": model,
                "prompt": prompt,
                "max_tokens": provider_config["models"][model].get(
                    "context_length", 2048
                ),
            }
        else:
            raise ValueError(f"Unsupported provider: {provider}")

        response = requests.post(endpoint, headers=headers, json=data)
        response.raise_for_status()
        return response.json()
