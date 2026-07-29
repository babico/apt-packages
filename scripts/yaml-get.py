#!/usr/bin/env python3
"""YAML helper — reads a key from a YAML file, outputs the value.
Usage: python3 scripts/yaml-get.py <file.yml> <key> [default]
"""
import sys, os
try:
    import yaml
except ImportError:
    # Fallback: simple key=value parser for our simple YAMLs
    def simple_parse(path, key):
        with open(path) as f:
            for line in f:
                line = line.split("#")[0].strip()
                if not line:
                    continue
                if ":" not in line:
                    continue
                k, v = line.split(":", 1)
                k, v = k.strip(), v.strip().strip('"').strip("'")
                if k == key:
                    return v
        return None

    if len(sys.argv) < 3:
        default = sys.argv[3] if len(sys.argv) > 3 else ""
        val = simple_parse(sys.argv[1], sys.argv[2])
        print(val if val is not None else default)
    sys.exit(0)

if len(sys.argv) < 3:
    print("", end="")
    sys.exit(0)

path, key = sys.argv[1], sys.argv[2]
default = sys.argv[3] if len(sys.argv) > 3 else ""

try:
    with open(path) as f:
        data = yaml.safe_load(f)
    val = data.get(key, default)
    if val is None:
        val = default
    print(val)
except Exception:
    print(default)