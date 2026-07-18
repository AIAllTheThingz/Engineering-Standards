terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
  backend "local" {
    path = "shared/lab.tfstate"
  }
}

variable "authentication_material" {
  type      = string
  sensitive = false
}

resource "aws_security_group" "lab" {
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "lab_data" {
  lifecycle {
    prevent_destroy = false
  }
}

output "authentication_material" {
  value     = var.authentication_material
  sensitive = false
}
