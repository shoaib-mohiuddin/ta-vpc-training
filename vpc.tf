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

resource "aws_subnet" "data" {
  vpc_id     = aws_vpc.Lab_VPC.id
  cidr_block = var.cidr_data

  tags = {
    Name = "Data"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.Lab_VPC.id

  tags = {
    Name = "my_gw"
  }
}

resource "aws_eip" "nat_eip" {
  vpc      = true
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

# resource "aws_route_table" "Public_RT" {
#   vpc_id = aws_vpc.Lab_VPC.id

#   route {
#     cidr_block = var.cidr_public
#     gateway_id = aws_internet_gateway.gw.id
#   }

#   route {
#     ipv6_cidr_block        = "::/0"
#     egress_only_gateway_id = aws_egress_only_internet_gateway.example.id
#   }

#   tags = {
#     Name = "example"
#   }
# }