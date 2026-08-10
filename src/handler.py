HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Hosted in AWS</title>
  <style>
    html, body {
      height: 100%;
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    body {
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #232f3e 0%, #ff9900 100%);
      color: #ffffff;
    }
    .card {
      text-align: center;
      padding: 60px 80px;
      background: rgba(0, 0, 0, 0.25);
      border-radius: 20px;
      box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
    }
    .badge {
      font-size: 14px;
      letter-spacing: 2px;
      text-transform: uppercase;
      opacity: 0.8;
    }
    h1 {
      font-size: 40px;
      margin: 16px 0 0 0;
    }
    .cloud {
      font-size: 64px;
      margin-bottom: 10px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="cloud">&#9729;&#65039;</div>
    <div class="badge">Amazon Web Services</div>
    <h1>This function is hosted in AWS</h1>
  </div>
</body>
</html>"""


def handler(event, context):
    """AWS Lambda handler.

    Returns a simple full-screen HTML page for the demo. Open the Function URL
    in a browser to see the screen: "This function is hosted in AWS".

    Stateless, no dependencies -> clean lift to GCP Cloud Run.
    """
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/html; charset=utf-8"},
        "body": HTML,
    }
