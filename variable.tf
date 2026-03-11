variable "region_name" {
  default = "ap-south-1"
}
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}
variable "public_cidr" {
  default = "10.0.0.0/20"
}
variable "private_cidr" {
  default = "10.0.16.0/20"
}

variable "availability" {
  default = "ap-south-1a"
}
variable "jume_server_ami" {
  default = "ami-051a31ab2f4d498f5"
}
variable "jume_server_instance_type" {
  default = "t3.micro"
}
variable "jume_server_key" {
  default = "Avdhoot-key"
}
variable "application_server_ami" {
  default = "ami-051a31ab2f4d498f5"
}
variable "application_server_instance_type" {
  default = "t3.micro"
}
variable "application_server_key" {
  default = "Avdhoot-key"
}