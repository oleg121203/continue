from typing import Any, Dict, List

from api_client import APIClient
from llama_client import OllamaClient


class CombinedAnalysis:
    def __init__(self):
        self.ollama_client = OllamaClient()
        self.api_client = APIClient()

    def analyze(
        self, prompt: str, models: List[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        if models is None:
            models = [
                {"provider": "ollama", "model": "qwen2.5-coder-7b"},
                {"provider": "mistral", "model": "mistral-large"},
                {"provider": "deepseek", "model": "deepseek-coder"},
            ]

        results = {}
        for model_config in models:
            provider = model_config["provider"]
            model = model_config["model"]

            try:
                if provider == "ollama":
                    response = self.ollama_client.query_model(model, prompt)
                else:
                    response = self.api_client.query_model(provider, model, prompt)
                results[f"{provider}-{model}"] = response
            except Exception as e:
                results[f"{provider}-{model}"] = {"error": str(e)}

        return {"results": results, "consensus": self._check_consensus(results)}

    def _check_consensus(self, results: Dict[str, Any]) -> str:
        # Simple consensus check - can be improved
        responses = [str(r) for r in results.values() if "error" not in r]
        return "Agreement" if len(set(responses)) == 1 else "Disagreement"


def combined_analysis(prompt: str) -> Dict[str, Any]:
    analyzer = CombinedAnalysis()
    return analyzer.analyze(prompt)
