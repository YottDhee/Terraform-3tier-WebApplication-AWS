terraform {
  backend s3 {
    bucket         = "tf3tierbucket"
    key            = "terraform/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
