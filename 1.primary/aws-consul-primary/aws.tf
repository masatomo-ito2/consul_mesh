data "aws_subnet" "public" {
  id = var.public_subnets_id[0]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "consul" {
  name        = "consul"
  description = "consul"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
    cidr_blocks = [data.aws_subnet.public.cidr_block]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = [data.aws_subnet.public.cidr_block]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = [data.aws_subnet.public.cidr_block]
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Consul server
resource "aws_instance" "consul" {
  instance_type               = "t3.small"
  ami                         = data.aws_ami.ubuntu.id
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.consul.id]
  subnet_id                   = var.public_subnets_id[0]
  associate_public_ip_address = true
  user_data                   = data.template_file.init.rendered
  iam_instance_profile        = var.aws_consul_iam_instance_profile_name
  tags = {
    Name = "consul"
    Env  = "consul-${var.env}"
  }
}

data "template_file" "init" {
  template = file("${path.module}/scripts/aws_consul_server.sh")

  vars = {
    tpl_env          = var.env
    tpl_vault_addr   = var.vault_addr
    tpl_region       = var.region
    tpl_namespace    = var.vault_namespace
    tpl_admin_passwd = var.admin_passwd
    tpl_role_id      = var.role_id
    tpl_secret_id    = var.secret_id
  }
}

# Consul client
resource "aws_instance" "consul_client" {
  instance_type               = "t3.small"
  ami                         = data.aws_ami.ubuntu.id
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.consul.id]
  subnet_id                   = var.public_subnets_id[0]
  associate_public_ip_address = true
  user_data                   = data.template_file.client.rendered
  iam_instance_profile        = var.aws_consul_iam_instance_profile_name
  tags = {
    Name = "consul-client"
    Env  = "consul-${var.env}"
  }
}

data "template_file" "client" {
  template = file("${path.module}/scripts/aws_consul_client.sh")

  vars = {
    tpl_env          = var.env
    tpl_vault_addr   = var.vault_addr
    tpl_region       = var.region
    tpl_azure_region = var.azure_region
    tpl_namespace    = var.vault_namespace
    tpl_admin_passwd = var.admin_passwd
  }

}

# Mesh gateway
resource "aws_instance" "mesh_gateway" {
  instance_type               = "t3.small"
  ami                         = data.aws_ami.ubuntu.id
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.consul.id]
  subnet_id                   = var.public_subnets_id[0]
  associate_public_ip_address = true
  user_data                   = data.template_file.aws_mgw_init.rendered
  iam_instance_profile        = var.aws_consul_iam_instance_profile_name
  tags = {
    Name = "consul-mgw-${var.env}"
  }
}

data "template_file" "aws_mgw_init" {
  template = file("${path.module}/scripts/aws_mesh_gateway.sh")
  vars = {
    tpl_env        = var.env
    tpl_vault_addr = var.vault_addr
    tpl_region     = var.region
    tpl_namespace  = var.vault_namespace
    tpl_role_id    = var.role_id
    tpl_secret_id  = var.mgw_secret_id
  }
}
