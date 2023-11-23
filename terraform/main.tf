terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.4.2"
}


provider "aws" {
  region = "ap-south-1"
}

# Lambda Start
data "aws_iam_policy_document" "assume_role" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "upload_file_lambda_iam_role" {
  name               = "upload_file_lambda_iam_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


data "archive_file" "upload_file_zip" {
  type        = "zip"
  source_file = "../code/lambda_function.py"
  output_path = "../code/upload_file.zip"
}

resource "aws_lambda_function" "upload_file" {
  filename         = "../code/upload_file.zip"
  function_name    = "lambda_function"
  role             = aws_iam_role.upload_file_lambda_iam_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.upload_file_zip.output_base64sha256

  runtime = "python3.10"
  environment {
    variables = {
      ENV     = local.environment
      API_KEY = var.API_KEY
    }
  }

  tags = {
    name        = "Upload file lambda"
    enviroment  = "DEV"
    description = "Lambda use for uploading file via API"
  }
}


# Lambda End


# API Gateway Start
resource "aws_api_gateway_rest_api" "upload_file_rest_api" {
  name = "upload_file_rest_api"
}

resource "aws_api_gateway_resource" "upload_file_resource" {
  path_part   = "resource"
  parent_id   = aws_api_gateway_rest_api.upload_file_rest_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.upload_file_rest_api.id
}

resource "aws_api_gateway_method" "upload_file_method" {
  rest_api_id   = aws_api_gateway_rest_api.upload_file_rest_api.id
  resource_id   = aws_api_gateway_resource.upload_file_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_file_integration" {
  rest_api_id             = aws_api_gateway_rest_api.upload_file_rest_api.id
  resource_id             = aws_api_gateway_resource.upload_file_resource.id
  http_method             = aws_api_gateway_method.upload_file_method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.upload_file.invoke_arn
}
# API Gateway End
