resource "aws_vpc" "Lab_VPC" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.Lab_VPC.id
  cidr_block = var.cidr_public

  tags = {
    Name = "Public"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.Lab_VPC.id
  cidr_block = var.cidr_private

  tags = {
    Name = "Private"
  }
}

resource "aws_subnet" "data-a" {
  vpc_id            = aws_vpc.Lab_VPC.id
  cidr_block        = var.cidr_data_a
  availability_zone = "eu-west-1a"

  tags = {
    Name = "Data-a"
  }
}

resource "aws_subnet" "data-b" {
  vpc_id            = aws_vpc.Lab_VPC.id
  cidr_block        = var.cidr_data_b
  availability_zone = "eu-west-1b"

  tags = {
    Name = "Data-b"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.Lab_VPC.id

  tags = {
    Name = "my_gw"
  }
}

resource "aws_eip" "nat_eip" {
  #vpc      = true ## Deprecated
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}
