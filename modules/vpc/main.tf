# VPC
resource "aws_vpc" "default" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true

  tags = merge(
    { Name = var.name },
    var.tags
  )
}

# INTERNET GATEWAY
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id

  tags = merge(
    { Name = "${var.name}_IG" },
    var.tags
  )
}

# ROUTE TABLE
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }

  tags = merge(
    { Name = "${var.name}_MAIN_RT" },
    var.tags
  )
}

resource "aws_main_route_table_association" "main_rt_association" {
  vpc_id         = aws_vpc.default.id
  route_table_id = aws_route_table.main.id
}
