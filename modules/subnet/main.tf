# GET ALL THE AVAILABLE AZ
data "aws_availability_zones" "available" {
  state = "available"
}

# CREATE A SUBNET IN EACH AZ
resource "aws_subnet" "multi_az" {
  count = length(data.aws_availability_zones.available.names)

  vpc_id                  = var.vpc_id
  cidr_block              = replace(var.cidr_block, "X", count.index + 1)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    { Name = "${var.name}_${data.aws_availability_zones.available.names[count.index]}" },
    var.tags
  )
}
