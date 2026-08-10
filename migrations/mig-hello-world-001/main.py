import os
from flask import Flask
app = Flask(__name__)
HTML = """<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Hosted in GCP</title>
<style>html,body{height:100%;margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;}
body{display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,#1a73e8 0%,#34a853 100%);color:#fff;}
.card{text-align:center;padding:60px 80px;background:rgba(0,0,0,0.25);border-radius:20px;box-shadow:0 10px 40px rgba(0,0,0,0.3);}
.badge{font-size:14px;letter-spacing:2px;text-transform:uppercase;opacity:0.8;}
h1{font-size:40px;margin:16px 0 0 0;}.cloud{font-size:64px;margin-bottom:10px;}</style></head>
<body><div class="card"><div class="cloud">☁️</div>
<div class="badge">Google Cloud Platform</div>
<h1>This function is hosted in GCP</h1></div></body></html>"""
@app.route("/")
def index():
    return HTML, 200, {"Content-Type": "text/html; charset=utf-8"}
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
