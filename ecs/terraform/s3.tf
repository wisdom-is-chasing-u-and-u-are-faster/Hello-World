##############################################
# S3 bucket — the "other resource" integration
#
# The ECS task reads this object at startup via
# its IAM task role (no static credentials).
# This is intentional: it gives the migration
# agent a realistic ECS -> S3 coupling to detect
# and migrate to GCS, mirroring the S3 workload
# already used in the Lambda/EKS demos' broader
# migration-agent test matrix.
##############################################
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "content" {
  bucket        = "${var.project_name}-content-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # easy teardown for a demo

  tags = {
    Project  = "aws-to-gcp-migration-demo"
    Workload = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "content" {
  bucket = aws_s3_bucket.content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "content" {
  bucket = aws_s3_bucket.content.id
  versioning_configuration {
    status = "Disabled" # demo simplicity; enable for production
  }
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.content.id
  key          = "index.html"
  content_type = "text/html"

  content = <<-HTML
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hosted in AWS ECS</title>
    <style>
      html, body { height: 100%; margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
      body { display: flex; align-items: center; justify-content: center;
             background: linear-gradient(135deg, #232f3e 0%, #ff9900 100%); color: #ffffff; }
      .card { text-align: center; padding: 60px 80px; background: rgba(0,0,0,0.25);
              border-radius: 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.3); }
      .badge { font-size: 14px; letter-spacing: 2px; text-transform: uppercase; opacity: 0.85; }
      h1 { font-size: 40px; margin: 16px 0 0 0; }
      .icon { font-size: 64px; margin-bottom: 10px; }
      .sub { font-size: 14px; opacity: 0.7; margin-top: 12px; }
    </style>
  </head>
  <body>
    <div class="card">
      <div class="icon">&#128736;&#65039;</div>
      <div class="badge">Amazon ECS &middot; Fargate</div>
      <h1>This is Deployed in ECS</h1>
      <div class="sub">Content served from Amazon S3 via the task's IAM role</div>
    </div>
  </body>
  </html>
  HTML
}
