from flask import Flask, render_template, jsonify, request
import os
import socket
import redis
import time
import math

REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))
r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)

app = Flask(__name__, static_folder="static", template_folder="templates")

INSTANCE = socket.gethostname()

# ensure key exists
try:
    r.setnx("blocked_count", 0)
except Exception:
    pass

@app.route("/")
def index():
    api_url = os.environ.get("API_PUBLIC_URL", "")
    return render_template("index.html.template", instance=INSTANCE, api_url=api_url)

@app.route("/metrics")
def metrics():
    blocked = int(r.get("blocked_count") or 0)
    return jsonify({"instance": INSTANCE, "blocked": blocked})

@app.route("/block", methods=["POST", "GET"])
def block():
    # Simulate detection and blocking of a phishing attempt
    r.incr("blocked_count", 1)
    blocked = int(r.get("blocked_count") or 0)
    return jsonify({"status": "blocked", "blocked": blocked})

@app.route("/compute")
def compute():
    # a CPU-heavy task controlled by 'work' parameter to generate CPU usage
    loops = int(request.args.get("work", "1000000"))
    s = 0.0
    # busy work
    for i in range(loops):
        s += math.sqrt((i % 100) + 1) * 0.000001
    return jsonify({"result": "done", "loops": loops, "instance": INSTANCE})
