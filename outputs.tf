output "ec2_kms_key_id" {
  value = aws_kms_key.ec2_kms.key_id
}

output "rds_kms_key_id" {
  value = aws_kms_key.rds_kms.key_id
}

output "s3_kms_key_id" {
  value = aws_kms_key.s3_kms.key_id
}

output "secrets_kms_key_id" {
  value = aws_kms_key.secrets_kms.key_id
}
