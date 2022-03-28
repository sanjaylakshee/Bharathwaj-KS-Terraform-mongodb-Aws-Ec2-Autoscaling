# Region

variable "region" {
  description = "The AWS region to create things in"
  default     = "us-west-2"
}

# Instances

variable "total_instances" {
  default = 1
}


variable "instance_prefix" {
  description = "Name to instance"
  default     = "mongo-ec2"
}

variable "instance_type" {
  description = "Instance AWS type"
  default     = "t2.micro"
}

variable "instance_user" {
  description = "Instance user to use into instance"
  default     = "ubuntu"
}

# Key Pair Name

variable "key_name" {
  description = "Value to key pair created in AWS"
  default     = "andrescolonia_key"
}

variable "private_key" {
  description = "Key to connect into instance to run script"
  default     = "/Users/andres/.ssh/id_rsa"
}

# Vpc

variable "vpc_id" {
  description = "Mongo VPC"
  default     = "vpc-ec545294"
}

# Subnet
variable "subnet_ids" {
  type = map(string)

  default = {
    "us-west-2a" = "subnet-347cc17e"
    "us-west-2b" = "subnet-eb33a393"
    "us-west-2c" = "subnet-55600208"
  }
}

# Security Group

variable "cidr_blocks" {
  default     = "0.0.0.0/0"
  description = "CIDR for sg"
}

variable "sg_name" {
  default     = "mongo security group"
  description = "Security Group to MongoDB"
}

variable "instancetype" {
  default = "t2.micro"
}


variable "availability_zone1" {
  default = "us-west-1a"
}

variable "availability_zone2" {
  default = "us-west-2b"
}

variable "emails" {
  default = "iambharathwaj.ks@gmail.com, "
}

variable "environment_tag" {
  description = "Environment Tag"
  default     = "DEV"
}