#!/usr/bin/env python3
"""Data-only helpers: never evaluate project configuration or completion text."""
import base64
import json
import sys
from pathlib import Path
from urllib.parse import quote, unquote


def main():
    action = sys.argv[1]
    if action == "scripts":
        try:
            scripts = json.loads(Path("package.json").read_text()).get("scripts", {})
            if isinstance(scripts, dict):
                for key in scripts:
                    if isinstance(key, str) and not any(c.isspace() for c in key):
                        print(key)
        except (OSError, ValueError, AttributeError):
            pass
        return
    data = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else sys.stdin.read()
    if action == "e64":
        result = base64.b64encode(data.encode()).decode()
    elif action == "d64":
        result = base64.b64decode(data.strip(), validate=True).decode()
    elif action == "urlencode":
        result = quote(data, safe="")
    elif action == "urldecode":
        result = unquote(data)
    elif action == "urlencode_json":
        result = json.dumps(data, ensure_ascii=False)
    elif action == "urldecode_json":
        result = json.loads(data)
        if not isinstance(result, str):
            raise ValueError("expected a JSON string")
    elif action in ("pp_json", "is_json"):
        result = json.loads(data)
        if action == "is_json":
            return
        result = json.dumps(result, indent=2, ensure_ascii=False)
    else:
        raise ValueError("unknown helper: " + action)
    print(result)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, UnicodeError) as error:
        print(f"dotfiles: {error}", file=sys.stderr)
        sys.exit(1)
