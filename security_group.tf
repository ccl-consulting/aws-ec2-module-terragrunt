# =============================================================================
# SECURITY GROUP
# =============================================================================

resource "aws_security_group" "this" {
  name        = local.security_group_name
  description = "Security group for ${var.instance_name}"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(
    {
      Name = local.security_group_name
    },
    var.tags
  )
}

# =============================================================================
# INGRESS RULES
# =============================================================================

# SSH access for Linux instances
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count             = var.operating_system == "linux" && length(var.allowed_ssh_cidrs) > 0 ? length(var.allowed_ssh_cidrs) : 0
  security_group_id = aws_security_group.this.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_ssh_cidrs[count.index]
  description       = "SSH access from ${var.allowed_ssh_cidrs[count.index]}"

  tags = {
    Name = "SSH-${count.index + 1}"
  }
}

# RDP access for Windows instances
resource "aws_vpc_security_group_ingress_rule" "rdp" {
  count             = var.operating_system == "windows" && length(var.allowed_rdp_cidrs) > 0 ? length(var.allowed_rdp_cidrs) : 0
  security_group_id = aws_security_group.this.id
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_rdp_cidrs[count.index]
  description       = "RDP access from ${var.allowed_rdp_cidrs[count.index]}"

  tags = {
    Name = "RDP-${count.index + 1}"
  }
}

# HTTP access
resource "aws_vpc_security_group_ingress_rule" "http" {
  count             = length(var.allowed_http_cidrs)
  security_group_id = aws_security_group.this.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_http_cidrs[count.index]
  description       = "HTTP access from ${var.allowed_http_cidrs[count.index]}"

  tags = {
    Name = "HTTP-${count.index + 1}"
  }
}

# HTTPS access
resource "aws_vpc_security_group_ingress_rule" "https" {
  count             = length(var.allowed_https_cidrs)
  security_group_id = aws_security_group.this.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_https_cidrs[count.index]
  description       = "HTTPS access from ${var.allowed_https_cidrs[count.index]}"

  tags = {
    Name = "HTTPS-${count.index + 1}"
  }
}

# Custom ingress rules
resource "aws_vpc_security_group_ingress_rule" "custom_ingress" {
  count             = length(var.custom_ingress_rules)
  security_group_id = aws_security_group.this.id
  from_port         = var.custom_ingress_rules[count.index].from_port
  to_port           = var.custom_ingress_rules[count.index].to_port
  ip_protocol       = var.custom_ingress_rules[count.index].protocol
  cidr_ipv4         = join(",", var.custom_ingress_rules[count.index].cidr_blocks)
  description       = var.custom_ingress_rules[count.index].description

  tags = {
    Name = "Custom-Ingress-${count.index + 1}"
  }
}

# =============================================================================
# EGRESS RULES
# =============================================================================

# Default egress rule (all outbound) - only if egress is not restricted
resource "aws_vpc_security_group_egress_rule" "default_egress" {
  count             = !var.restrict_egress && length(var.custom_egress_rules) == 0 ? 1 : 0
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound traffic"

  tags = {
    Name = "Default-Egress"
  }
}

# Custom egress rules
resource "aws_vpc_security_group_egress_rule" "custom_egress" {
  count             = length(var.custom_egress_rules)
  security_group_id = aws_security_group.this.id
  from_port         = var.custom_egress_rules[count.index].from_port
  to_port           = var.custom_egress_rules[count.index].to_port
  ip_protocol       = var.custom_egress_rules[count.index].protocol
  cidr_ipv4         = join(",", var.custom_egress_rules[count.index].cidr_blocks)
  description       = var.custom_egress_rules[count.index].description

  tags = {
    Name = "Custom-Egress-${count.index + 1}"
  }
}

# Restricted egress - only HTTPS and DNS if restrict_egress is true and no custom rules
resource "aws_vpc_security_group_egress_rule" "https_egress" {
  count             = var.restrict_egress && length(var.custom_egress_rules) == 0 ? 1 : 0
  security_group_id = aws_security_group.this.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTPS outbound traffic"

  tags = {
    Name = "HTTPS-Egress"
  }
}

resource "aws_vpc_security_group_egress_rule" "dns_tcp_egress" {
  count             = var.restrict_egress && length(var.custom_egress_rules) == 0 ? 1 : 0
  security_group_id = aws_security_group.this.id
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "DNS TCP outbound traffic"

  tags = {
    Name = "DNS-TCP-Egress"
  }
}

resource "aws_vpc_security_group_egress_rule" "dns_udp_egress" {
  count             = var.restrict_egress && length(var.custom_egress_rules) == 0 ? 1 : 0
  security_group_id = aws_security_group.this.id
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "DNS UDP outbound traffic"

  tags = {
    Name = "DNS-UDP-Egress"
  }
}

resource "aws_vpc_security_group_egress_rule" "http_egress" {
  count             = var.restrict_egress && length(var.custom_egress_rules) == 0 ? 1 : 0
  security_group_id = aws_security_group.this.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTP outbound traffic"

  tags = {
    Name = "HTTP-Egress"
  }
}
