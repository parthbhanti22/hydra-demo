from flask import Flask, render_template, jsonify, request
import os
import socket
import redis
import time
import math
import requests
from urllib.parse import urlparse
import boto3
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

# Initialize the Flask app FIRST
app = Flask(__name__, static_folder="../static", template_folder="templates")

# --- AWS and Screenshot Configuration ---
S3_BUCKET_NAME = os.environ.get("S3_BUCKET_NAME")
s3 = boto3.client("s3")

def take_screenshot(url: str) -> bytes:
    """Uses a headless Chrome browser to take a screenshot of a URL."""
    chrome_options = Options()
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("window-size=1280x720")
    
    # This assumes chromedriver is in the system's PATH
    driver = webdriver.Chrome(options=chrome_options)
    try:
        driver.get(url)
        # The screenshot is returned as a PNG image in binary format
        screenshot = driver.get_screenshot_as_png()
        return screenshot
    finally:
        driver.quit()

# --- Helper Function ---
def normalize_url(u: str) -> str:
    u = u.strip()
    if not u:
        return ""
    parsed = urlparse(u)
    if not parsed.scheme:
        u = "https://" + u
    return u

# --- Redis and Instance Configuration ---
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))
r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)
INSTANCE = socket.gethostname()

try:
    r.setnx("blocked_count", 0)
except Exception as e:
    print(f"Could not connect to Redis: {e}")

# --- API Routes ---

@app.route("/")
def index():
    return render_template("index.html.template", instance=INSTANCE)

@app.route("/block", methods=["POST"])
def block():
    """
    Simulates blocking a URL and triggers the AWS threat analysis workflow.
    """
    raw_url = request.form.get("url", "")
    target_url = normalize_url(raw_url)

    if not target_url:
        return jsonify({"status": "error", "message": "URL is required"}), 400

    if not S3_BUCKET_NAME:
        return jsonify({"status": "error", "message": "S3 bucket not configured"}), 500

    try:
        # 1. Take a screenshot of the suspicious site
        screenshot_data = take_screenshot(target_url)
        
        # 2. Upload the screenshot to S3
        file_name = f"evidence/{socket.gethostname()}-{int(time.time())}.png"
        s3.put_object(Bucket=S3_BUCKET_NAME, Key=file_name, Body=screenshot_data, ContentType='image/png')
        
        # 3. Increment the Redis counter
        blocked = r.incr("blocked_count", 1)
        
        return jsonify({
            "status": "blocked",
            "blocked_count": blocked,
            "url": target_url,
            "s3_key": file_name,
            "message": f"URL blocked. Screenshot saved as {file_name} in bucket {S3_BUCKET_NAME}."
        })

    except Exception as e:
        print(f"Error in /block endpoint: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route("/check")
def check():
    raw = request.args.get("url", "")
    target = normalize_url(raw)
    if not target:
        return jsonify({"error": "empty url"}), 400

    try:
        resp = requests.get(target, timeout=6, allow_redirects=True, headers={"User-Agent":"Hydra-Checker/1.0"})
        snippet = (resp.text or "")[:800].replace("\n"," ").replace("\r"," ")
        return jsonify({
            "url": target, "reachable": True, "status_code": resp.status_code,
            "content_snippet": snippet, "error": None
        })
    except requests.exceptions.RequestException as e:
        return jsonify({
            "url": target, "reachable": False, "status_code": None,
            "content_snippet": "", "error": str(e)
        }), 502

@app.route("/status")
def status():
    try:
        count = r.get("request_count") or 0
        return f"✅ Healthy ({count} requests)"
    except Exception:
        return "⚠️ Backend Error"

# Other routes from your original file can be kept as they are
@app.route("/metrics")
def metrics():
    blocked = int(r.get("blocked_count") or 0)
    return jsonify({"instance": INSTANCE, "blocked": blocked})

@app.route("/compute")
def compute():
    loops = int(request.args.get("work", "1000000"))
    s = 0.0
    for i in range(loops):
        s += math.sqrt((i % 100) + 1) * 0.000001
    return jsonify({"result": "done", "loops": loops, "instance": INSTANCE})