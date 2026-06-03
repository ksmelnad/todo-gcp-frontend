#!/usr/bin/env python3
"""Generate Supabase JWT_SECRET, ANON_KEY, and SERVICE_ROLE_KEY.

Usage:
  python3 infra/generate-supabase-keys.py
  python3 infra/generate-supabase-keys.py --secret YOUR_EXISTING_SECRET
"""

import argparse
import base64
import hashlib
import hmac
import json
import os
import sys
import time


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def make_jwt(payload: dict, secret: str) -> str:
    header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    body = b64url(json.dumps(payload, separators=(",", ":")).encode())
    signing_input = f"{header}.{body}".encode()
    sig = hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
    return f"{header}.{body}.{b64url(sig)}"


def generate(secret: str) -> None:
    now = int(time.time())
    exp = now + 10 * 365 * 24 * 3600  # 10 years

    anon = make_jwt({"role": "anon", "iss": "supabase", "iat": now, "exp": exp}, secret)
    svc = make_jwt({"role": "service_role", "iss": "supabase", "iat": now, "exp": exp}, secret)

    print("# Copy these values into your .env file on the Supabase VM", file=sys.stderr)
    print(f"JWT_SECRET={secret}")
    print(f"ANON_KEY={anon}")
    print(f"SERVICE_ROLE_KEY={svc}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--secret", help="Use existing JWT secret instead of generating new one")
    args = parser.parse_args()

    secret = args.secret or base64.b64encode(os.urandom(32)).decode().rstrip("=")
    generate(secret)
