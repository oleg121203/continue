import pytest

from src.combined_analysis import CombinedAnalysis


def test_combined_analysis():
    analyzer = CombinedAnalysis()
    result = analyzer.analyze("Test prompt")

    assert "results" in result
    assert "consensus" in result
    assert isinstance(result["results"], dict)
    assert result["consensus"] in ["Agreement", "Disagreement"]


def test_custom_models():
    analyzer = CombinedAnalysis()
    models = [
        {"provider": "ollama", "model": "qwen2.5-coder-7b"},
        {"provider": "mistral", "model": "mistral-large"},
    ]
    result = analyzer.analyze("Test prompt", models)

    assert "ollama-qwen2.5-coder-7b" in result["results"]
    assert "mistral-mistral-large" in result["results"]


def test_invalid_model():
    analyzer = CombinedAnalysis()
    with pytest.raises(ValueError):
        analyzer.analyze("test", [{"provider": "invalid", "model": "test"}])
