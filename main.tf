resource "random_pet" "p" {}

resource "aws_s3_bucket" "mktest" {
  bucket = random_pet.p.id

  tags = {
    Name        = random_pet.p.id
    Environment = "env0"
  }
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
