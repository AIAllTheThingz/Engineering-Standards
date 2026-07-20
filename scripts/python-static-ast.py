"""Parse untrusted Python files as inert text with the standard-library AST."""
import ast
import json
import sys

results = []
for path in json.loads(sys.stdin.read()):
    try:
        with open(path, "r", encoding="utf-8", errors="strict") as source:
            ast.parse(source.read(), filename=path)
    except (SyntaxError, UnicodeError) as error:
        results.append({"path": path, "line": getattr(error, "lineno", 1) or 1, "message": str(error)})
json.dump(results, sys.stdout, sort_keys=True, separators=(",", ":"))
