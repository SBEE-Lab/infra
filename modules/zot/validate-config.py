"""Validate structure without reading runtime secrets into the Nix store."""

import json
import sys
from pathlib import Path
from typing import Any


def placeholders(value: Any, field: str = "") -> Any:
    if isinstance(value, dict):
        return {key: placeholders(item, key) for key, item in value.items()}
    if isinstance(value, list):
        return [placeholders(item, field) for item in value]
    if isinstance(value, str) and value.startswith("/run/credentials/zot.service/"):
        name = value.removeprefix("/run/credentials/zot.service/")
        if not name or "/" in name or name in {".", ".."}:
            raise ValueError("Invalid zot credential name")
        # Zot selects the secret decoder from the filename extension.
        path = Path.cwd() / f"placeholder-{name}-{field}.json"
        content = ""
        if field == "sessionKeysFile":
            content = json.dumps({"hashKey": "0" * 64, "encryptKey": "0" * 32})
        elif field == "credentialsFile":
            content = json.dumps({"clientid": "validation", "clientsecret": "validation"})
        path.write_text(content)
        return str(path)
    return value


source, destination = sys.argv[1:]
Path(destination).write_text(json.dumps(placeholders(json.loads(Path(source).read_text()))))
