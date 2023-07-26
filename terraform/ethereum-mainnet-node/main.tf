provider "aws" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# https://docs.prylabs.network/docs/prysm-usage/p2p-host-ip#determine-your-ip-addresses
resource aws_security_group "ethereum_mainnet_node" {
  description = "ethereum mainnet node"
  vpc_id      = "vpc-00fb614383877b2a3"
  tags = {
    Name = "ethereum-mainnet-node"
  }
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_vpc_security_group_egress_rule" "outbound" {
  description = "outbound all"
  security_group_id = aws_security_group.ethereum_mainnet_node.id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  description       = "ssh"
  security_group_id = aws_security_group.ethereum_mainnet_node.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "grafana_dashboard" {
  description       = "Grafana Dashboard"
  security_group_id = aws_security_group.ethereum_mainnet_node.id
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "beacon_query_api" {
  description       = "beacon node query API"
  security_group_id = aws_security_group.ethereum_mainnet_node.id
  from_port         = 3500
  to_port           = 3500
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "prometheus_dashboard" {
  description       = "prometheus dashboard"
  security_group_id = aws_security_group.ethereum_mainnet_node.id
  from_port         = 9090
  to_port           = 9090
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "beacon_discovery" {
  description       = "ethereum node RPC port"
  security_group_id = aws_security_group.ethereum_mainnet_node.id
  from_port         = 12000
  to_port           = 12000
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
}

# https://docs.libp2p.io/guides/getting-started/go/
resource "aws_vpc_security_group_ingress_rule" "libp2p" {
  description       = "ethereum node P2P port"
  security_group_id = aws_security_group.ethereum_mainnet_node.id
  from_port         = 13000
  to_port           = 13000
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "execution_listener_tcp" {
  description       = "execution listener TCP"
  security_group_id = aws_security_group.ethereum_mainnet_node.id
  from_port         = 30303
  to_port           = 30303
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "execution_listener_udp" {
  description       = "execution listener UDP"
  security_group_id = aws_security_group.ethereum_mainnet_node.id
  from_port         = 30303
  to_port           = 30303
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "ethereum_mainnet_node" {
  ami                         = data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  instance_type               = "i4i.large"
  key_name                    = "ethereum-mainnet-node"
  root_block_device {
    volume_size = 20
  }
  vpc_security_group_ids = [aws_security_group.ethereum_mainnet_node.id]
  # public subnet
  subnet_id       = "subnet-05c72ad17f0a2043b"

  tags = {
    Name = "ethereum-mainnet-node"
  }
  # Ethereum node startup script
  user_data = filebase64("${path.module}/bootstrap.sh") 
}

resource "local_file" "ip" {
  content  = aws_instance.ethereum_mainnet_node.public_ip
  filename = "${path.module}/ip.txt"
}

output "ip" {
  value = aws_instance.ethereum_mainnet_node.public_ip
}
