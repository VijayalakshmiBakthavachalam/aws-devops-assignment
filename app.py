"""
Simple Python Flask web app for AWS DevOps pipeline demo.
Runs on port 8000. Retrieves a secret from AWS Secrets Manager and masks it.
"""
import os
import json

import boto3
from flask import Flask, render_template

app = Flask(__name__)

# Secret name in AWS Secrets Manager (set by infra stack or env)
SECRET_NAME = os.environ.get("APP_SECRET_NAME", "devops-demo/app-secret")


def get_secret_from_manager():
    """Retrieve secret from AWS Secrets Manager. Returns (value, masked_value)."""
    try:
        client = boto3.client("secretsmanager")
        response = client.get_secret_value(SecretId=SECRET_NAME)
    except Exception as e:
        return None, f"*** (error: {type(e).__name__})"

    if "SecretString" in response:
        secret_str = response["SecretString"]
        try:
            data = json.loads(secret_str)
            # Support both {"password": "x"} and plain string
            value = data.get("password", data.get("secret", secret_str))
        except (TypeError, json.JSONDecodeError):
            value = secret_str
    else:
        value = response.get("SecretBinary", b"").decode("utf-8", errors="replace")

    # Mask: show only last 4 characters, rest as asterisks
    if not value or len(value) < 4:
        masked = "****" if value else "****"
    else:
        masked = "*" * (len(value) - 4) + value[-4:]
    return value, masked


@app.route("/")
def index():
    _, masked_secret = get_secret_from_manager()
    return render_template("index.html", greeting="Welcome to the AWS DevOps Demo!", secret_masked=masked_secret)


@app.route("/health")
def health():
    return {"status": "healthy", "service": "aws-devops-demo"}, 200


@app.route("/api/info")
def api_info():
    _, masked = get_secret_from_manager()
    return {
        "app": "AWS DevOps Demo",
        "version": "1.0.0",
        "description": "Python web app with Secrets Manager and CI/CD",
        "secret_retrieved": True,
        "secret_masked": masked,
    }


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=False)
