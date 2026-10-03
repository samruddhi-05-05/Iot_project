# ============================================================
# AWS IoT Data Processing Pipeline
# Smart Agriculture Project
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}


# ============================================================
# AWS PROVIDER
# ============================================================

provider "aws" {
  region = "ap-south-1"
}


# ============================================================
# S3 BUCKET
# Stores raw, historical IoT data and backups
# ============================================================

resource "aws_s3_bucket" "iot_data" {

  bucket_prefix = "aws-iot-data-pipeline-"

  tags = {
    Name        = "AWS IoT Data Storage"
    Project     = "AWS IoT Data Processing Pipeline"
    Environment = "Development"
  }
}


# S3 VERSIONING

resource "aws_s3_bucket_versioning" "iot_data" {

  bucket = aws_s3_bucket.iot_data.id

  versioning_configuration {
    status = "Enabled"
  }
}


# S3 PUBLIC ACCESS BLOCK

resource "aws_s3_bucket_public_access_block" "iot_data" {

  bucket = aws_s3_bucket.iot_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# S3 ENCRYPTION

resource "aws_s3_bucket_server_side_encryption_configuration" "iot_data" {

  bucket = aws_s3_bucket.iot_data.id

  rule {

    apply_server_side_encryption_by_default {

      sse_algorithm = "AES256"

    }
  }
}


# ============================================================
# DYNAMODB
# Stores latest / real-time IoT sensor data
# ============================================================

resource "aws_dynamodb_table" "iot_data" {

  name         = "IoTSensorData"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "device_id"
  range_key = "timestamp"


  attribute {
    name = "device_id"
    type = "S"
  }


  attribute {
    name = "timestamp"
    type = "S"
  }


  tags = {

    Name        = "IoT Sensor Data"
    Project     = "AWS IoT Data Processing Pipeline"
    Environment = "Development"

  }
}


# ============================================================
# IAM ROLE FOR LAMBDA
# ============================================================

resource "aws_iam_role" "lambda_role" {

  name = "aws-iot-lambda-role"


  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"

      }

    ]

  })
}


# ============================================================
# IAM POLICY FOR LAMBDA
# Allows Lambda to access DynamoDB, S3 and CloudWatch
# ============================================================

resource "aws_iam_role_policy" "lambda_policy" {

  name = "aws-iot-lambda-policy"

  role = aws_iam_role.lambda_role.id


  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      # DynamoDB permissions

      {

        Effect = "Allow"

        Action = [

          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"

        ]

        Resource = aws_dynamodb_table.iot_data.arn

      },


      # S3 permissions

      {

        Effect = "Allow"

        Action = [

          "s3:PutObject",
          "s3:GetObject"

        ]

        Resource = "${aws_s3_bucket.iot_data.arn}/*"

      },


      # CloudWatch Logs permissions

      {

        Effect = "Allow"

        Action = [

          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"

        ]

        Resource = "*"

      }

    ]

  })
}


# ============================================================
# LAMBDA ZIP
# Python Lambda function
# ============================================================

data "archive_file" "lambda_zip" {

  type = "zip"

  source_file = "${path.module}/../lambda/processor/lambda_function.py"

  output_path = "${path.module}/lambda_function.zip"

}


# ============================================================
# AWS LAMBDA
# Processes IoT sensor data
# ============================================================

resource "aws_lambda_function" "processor" {

  function_name = "aws-iot-data-processor"


  filename = data.archive_file.lambda_zip.output_path

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256


  role = aws_iam_role.lambda_role.arn


  handler = "lambda_function.lambda_handler"

  runtime = "python3.12"


  timeout = 30


  environment {

    variables = {

      TABLE_NAME = aws_dynamodb_table.iot_data.name

      BUCKET_NAME = aws_s3_bucket.iot_data.bucket

    }

  }


  tags = {

    Name        = "IoT Data Processor"
    Project     = "AWS IoT Data Processing Pipeline"
    Environment = "Development"

  }

}


# ============================================================
# CLOUDWATCH LOG GROUP
# Stores Lambda logs
# ============================================================

resource "aws_cloudwatch_log_group" "lambda_logs" {

  name = "/aws/lambda/${aws_lambda_function.processor.function_name}"

  retention_in_days = 7

}


# ============================================================
# AWS IoT CORE
# Receives sensor data
# ============================================================

resource "aws_iot_topic_rule" "sensor_data" {

  name        = "aws_iot_sensor_data_rule"
  enabled     = true

  sql = "SELECT * FROM 'sensors/data'"

  sql_version = "2016-03-23"


  # Send IoT data to Lambda

  lambda {

    function_arn = aws_lambda_function.processor.arn

  }


  tags = {

    Name        = "IoT Sensor Data Rule"
    Project     = "AWS IoT Data Processing Pipeline"
    Environment = "Development"

  }

}


# ============================================================
# PERMISSION
# Allows AWS IoT Core to invoke Lambda
# ============================================================

resource "aws_lambda_permission" "iot_permission" {

  statement_id = "AllowIoTCoreInvoke"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.processor.function_name

  principal = "iot.amazonaws.com"

  source_arn = aws_iot_topic_rule.sensor_data.arn

}


# ============================================================
# OUTPUTS
# ============================================================

output "s3_bucket_name" {

  value = aws_s3_bucket.iot_data.bucket

}


output "dynamodb_table_name" {

  value = aws_dynamodb_table.iot_data.name

}


output "lambda_function_name" {

  value = aws_lambda_function.processor.function_name

}


output "iot_topic" {

  value = "sensors/data"

}


output "aws_region" {

  value = "ap-south-1"

}
