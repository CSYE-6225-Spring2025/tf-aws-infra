data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-java-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-java-app-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_policy" "kms_access" {
  name = "ec2-kms-access-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:ReEncrypt*",
          "kms:CreateGrant"
        ],
        Resource = [
          aws_kms_key.ec2_kms.arn,
          aws_kms_key.rds_kms.arn,
          aws_kms_key.s3_kms.arn,
          aws_kms_key.secrets_kms.arn
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = [aws_secretsmanager_secret.db_secret.arn]
      }
    ]
  })
}

# Single policy attachment for KMS
resource "aws_iam_role_policy_attachment" "kms_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.kms_access.arn
}

# CloudWatch attachment remains the same
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
