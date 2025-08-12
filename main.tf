resource "random_pet" "p" {}

provider "aws" {
  alias  = "va"
  region = "us-east-1"
}

resource "aws_s3_bucket" "mktest" {
  provider = aws.va
  bucket   = random_pet.p.id

  tags = {
    Name        = random_pet.p.id
    Environment = "env0"
  }
}

output "bucket-name" {
  value = "aws_s3_bucket.mktest.name"
}

terraform {
  required_version = "~> 1.0"
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.100"
    }
  }
}
