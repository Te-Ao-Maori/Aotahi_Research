"""Stubbed StealthOCR helper for the analysis metadata utilities."""

from dataclasses import dataclass
from typing import Dict, Any


@dataclass
class StealthOCR:
    """Placeholder implementation matching the interface expected by analysis/metadata.py."""

    def _generate_protection_metadata(self, resource: str) -> Dict[str, Any]:
        return {"resource": resource, "protected": False}
