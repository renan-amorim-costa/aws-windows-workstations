# One public subnet for the workstations and two private ones for the
# databases. What makes a subnet public is its route to the internet
# gateway, not a flag: the private ones have no route out at all.
#
# No NAT gateway on purpose: it bills by the hour, and the databases never
# need to reach the internet.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = { Name = "${var.project}-vpc" }
}

# Workstations get a public IP for outbound traffic, the price of skipping
# the NAT gateway. Inbound stays closed unless admin_cidrs is set.
#trivy:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project}-public" }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnet_cidrs

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = "${var.aws_region}${each.key}"

  tags = { Name = "${var.project}-private-${each.key}" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project}-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
