
resource "aws_iam_role" "bucket_access_role" {
  name = "s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    tag-key = "bucket-access-role"
  }
}

resource "aws_iam_role_policy" "s3_role_policy" {
  name = "s3-role-policy"
  role = aws_iam_role.bucket_access_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "s3:ListBucket",
        "s3:GetObject",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Effect = "Allow",
      Resource = [
        "arn:aws:s3:::client-portal-userdata-2024",
        "arn:aws:s3:::client-portal-userdata-2024/*"   
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "instance_profile"
  role = aws_iam_role.bucket_access_role.name
}


resource "aws_s3_bucket" "client_portal_userdata_script" {
  bucket        = "client-portal-userdata-2024"
  acl    = "private"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.client_portal_userdata_script.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_crypto_conf" {
  bucket = aws_s3_bucket.client_portal_userdata_script.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_object" "instrumentation_upload_object" {
  bucket                 = aws_s3_bucket.client_portal_userdata_script.id
  key                    = "userdata_2.ps1"
  source                 = "userdata_2.ps1"
  server_side_encryption = "AES256"

  tags = {
    Name = "Upload to bucket"
  }
}




