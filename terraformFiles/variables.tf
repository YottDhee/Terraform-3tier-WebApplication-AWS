variable "aws_region" {
  default = "us-east-1"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  default     = "NV-Keypair"
}

variable "db_username" {
  default = "admin"
}

variable "db_password" {
  default = "YottDhee@167$"
}
