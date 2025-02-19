provider "aws" {
  region  = var.region
  profile = var.profile
}


resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = var.vpc_tag
  }
}


resource "aws_subnet" "public" {
  count                   = length(var.availabilityzones_names)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets_cidrs[count.index]
  availability_zone       = var.availabilityzones_names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "var.public_subnet_tag-${count.index}"
  }
}


resource "aws_subnet" "private" {
  count             = length(var.availabilityzones_names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidrs[count.index]
  availability_zone = var.availabilityzones_names[count.index]
  tags = {
    Name = "var.private_subnet_tag-${count.index}"
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Internet Gateway"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "AWS route Table"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}


resource "aws_route_table_association" "public" {
  count          = length(var.availabilityzones_names)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "AWS Private route Table"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.availabilityzones_names)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
