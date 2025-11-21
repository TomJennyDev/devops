# ============================================
# VPC
# ============================================
resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    {
      Name                                        = "${var.cluster_name}-vpc"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    },
    var.tags
  )
}

# ============================================
# Public Subnets
# ============================================
resource "aws_subnet" "eks_subnet_public" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name                                        = "${var.cluster_name}-public-subnet-${count.index + 1}"
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    },
    var.tags
  )
}

# ============================================
# Private Subnets
# ============================================
resource "aws_subnet" "eks_subnet_private" {
  count             = var.private_subnet_count
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = merge(
    {
      Name                                        = "${var.cluster_name}-private-subnet-${count.index + 1}"
      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    },
    var.tags
  )
}

# ============================================
# Internet Gateway
# ============================================
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = merge(
    {
      Name = "${var.cluster_name}-igw"
    },
    var.tags
  )
}

# ============================================
# Elastic IPs for NAT Gateways
# ============================================
resource "aws_eip" "nat_eip" {
  count  = var.enable_nat_gateway ? var.nat_gateway_count : 0
  domain = "vpc"

  tags = merge(
    {
      Name = "${var.cluster_name}-nat-eip-${count.index + 1}"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.eks_igw]
}

# ============================================
# NAT Gateways
# ============================================
resource "aws_nat_gateway" "eks_nat" {
  count         = var.enable_nat_gateway ? var.nat_gateway_count : 0
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.eks_subnet_public[count.index].id

  tags = merge(
    {
      Name = "${var.cluster_name}-nat-${count.index + 1}"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.eks_igw]
}

# ============================================
# Public Route Table
# ============================================
resource "aws_route_table" "eks_public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = merge(
    {
      Name = "${var.cluster_name}-public-rt"
    },
    var.tags
  )
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.eks_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.eks_igw.id
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = var.public_subnet_count
  subnet_id      = aws_subnet.eks_subnet_public[count.index].id
  route_table_id = aws_route_table.eks_public_rt.id
}

# ============================================
# Private Route Tables
# ============================================
resource "aws_route_table" "eks_private_rt" {
  count  = var.private_subnet_count
  vpc_id = aws_vpc.eks_vpc.id

  tags = merge(
    {
      Name = "${var.cluster_name}-private-rt-${count.index + 1}"
    },
    var.tags
  )
}

resource "aws_route" "private_route" {
  count                  = var.enable_nat_gateway ? var.private_subnet_count : 0
  route_table_id         = aws_route_table.eks_private_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.eks_nat[*].id, count.index)
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = var.private_subnet_count
  subnet_id      = aws_subnet.eks_subnet_private[count.index].id
  route_table_id = aws_route_table.eks_private_rt[count.index].id
}