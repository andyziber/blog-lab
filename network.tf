# ---------------------------------------------------------------------------
# One VPC, one public subnet, no NAT gateway.
#
# Instances get public IPs for egress only (apt, public sites, SSM). Nothing
# accepts inbound traffic from the internet: access is through SSM Session
# Manager, so there is no SSH port and no key pair.
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.name_prefix }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = { Name = var.name_prefix }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "${var.name_prefix}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = { Name = "${var.name_prefix}-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Lock down the default security group so nothing lands in it by accident.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.lab.id
}

# ---------------------------------------------------------------------------
# Security groups.
#
# client: no ingress at all. Egress anywhere (it browses public sites).
# c2:     HTTPS from the client SG only. Egress anywhere (apt, SSM).
# ---------------------------------------------------------------------------

resource "aws_security_group" "client" {
  name        = "${var.name_prefix}-client"
  description = "Lab client: no inbound, outbound anywhere"
  vpc_id      = aws_vpc.lab.id

  tags = { Name = "${var.name_prefix}-client" }
}

resource "aws_vpc_security_group_egress_rule" "client_all" {
  security_group_id = aws_security_group.client.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "c2" {
  name        = "${var.name_prefix}-c2"
  description = "Simulated C2: HTTPS from the lab client only"
  vpc_id      = aws_vpc.lab.id

  tags = { Name = "${var.name_prefix}-c2" }
}

resource "aws_vpc_security_group_ingress_rule" "c2_https_from_client" {
  security_group_id            = aws_security_group.c2.id
  description                  = "HTTPS beacon from the lab client"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.client.id
}

resource "aws_vpc_security_group_egress_rule" "c2_all" {
  security_group_id = aws_security_group.c2.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
