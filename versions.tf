terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Same state bucket as the portfolio stack, separate key. The bucket and its
  # native S3 lockfile locking already exist; nothing to bootstrap here.
  backend "s3" {
    bucket       = "andyziber-tfstate"
    key          = "blog-lab/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "blog-lab"
      ManagedBy = "terraform"
      Env       = "lab"
    }
  }
}
