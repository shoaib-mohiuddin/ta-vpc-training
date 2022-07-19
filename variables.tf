variable "vpc_name" {
    description = "This is the VPC name"
    type = string
}

variable "vpc_cidr" {
    description = "This is the VPC CIDR"
}

variable "cidr_public" {
    description = "CIDR for Public Subnet"
}

variable "cidr_private" {
    description = "CIDR for Private Subnet"
}

variable "cidr_data" {
    description = "CIDR for Data Subnet"
}