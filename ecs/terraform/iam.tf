##############################################
# IAM — execution role vs. task role kept
# separate on purpose (least privilege):
#   - execution role: pulls images, writes logs
#   - task role: the only one with S3 access,
#     scoped to a single object
##############################################
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.project_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = { Project = "aws-to-gcp-migration-demo" }
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.project_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = { Project = "aws-to-gcp-migration-demo" }
}

data "aws_iam_policy_document" "task_s3_read" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.content.arn}/index.html"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.content.arn]
  }
}

resource "aws_iam_role_policy" "task_s3_read" {
  name   = "${var.project_name}-task-s3-read"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_s3_read.json
}
