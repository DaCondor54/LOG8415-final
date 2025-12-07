terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.24"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
  }

  required_version = ">= 1.14"
}

provider "aws" {
  region = "us-east-1"
}

provider "cloudinit" {

}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.5"

  name = "log8415-vpc"
  cidr = "10.0.0.0/16"
  azs  = ["us-east-1a"]

  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.4.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true

  manage_default_security_group = true

  default_security_group_ingress = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {

      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }, 
    {
      from_port   = 8
      to_port     = 0
      protocol    = "icmp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  default_security_group_egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }    
  ]
}

resource "aws_route53_zone" "private_zone" {
  name = "internal"
  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

resource "aws_route53_record" "source" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "source.internal"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.source.private_ip]
}

resource "aws_route53_record" "replica_1" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "replica_1.internal"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.replica_1.private_ip]
}

resource "aws_route53_record" "replica_2" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "replica_2.internal"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.replica_2.private_ip]
}

resource "aws_route53_record" "proxy" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "proxy.internal"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.proxy.private_ip]
}


resource "aws_instance" "source" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  depends_on = [module.vpc.aws_nat_gateway]

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.private_subnets[0]
  user_data              = file("${path.module}/scripts/source-server.sh")
  key_name               = "tp3"

  tags = {
    Name = "log8415-tp3-source"
  }
}

resource "aws_instance" "replica_1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  depends_on = [aws_instance.source, module.vpc.aws_nat_gateway]

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.private_subnets[0]
  key_name               = "tp3"

  user_data = templatefile("${path.module}/scripts/replica.sh.tftpl", {
    instance_num = 1
  })

  tags = {
    Name = "log8415-tp3-replica-1"
  }
}

resource "aws_instance" "replica_2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  depends_on = [aws_instance.source, module.vpc.aws_nat_gateway]

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.private_subnets[0]
  key_name               = "tp3"

  user_data = templatefile("${path.module}/scripts/replica.sh.tftpl", {
    instance_num = 2
  })

  tags = {
    Name = "log8415-tp3-replica-2"
  }
}

locals {
  proxy_py           = file("${path.module}/../proxy/main.py")
  proxy_requirements = file("${path.module}/../proxy/requirements.txt")

  gatekeeper_py           = file("${path.module}/../gatekeeper/main.py")
  gatekeeper_requirements = file("${path.module}/../gatekeeper/requirements.txt")

  startup_script = file("${path.module}/scripts/startup.sh")
}

data "cloudinit_config" "proxy_user_data" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = yamlencode({
      write_files = [{
        content     = local.proxy_py
        path        = "/opt/main.py"
        owner       = "root:root"
        permissions = "0777"
        }, {
        content     = local.proxy_requirements
        path        = "/opt/requirements.txt"
        owner       = "root:root"
        permissions = "0777"
      }]
    })
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "startup.sh"
    content      = local.startup_script
  }
}

data "cloudinit_config" "gatekeeper_user_data" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = yamlencode({
      write_files = [{
        content     = local.gatekeeper_py
        path        = "/opt/main.py"
        owner       = "root:root"
        permissions = "0777"
        }, {
        content     = local.gatekeeper_requirements
        path        = "/opt/requirements.txt"
        owner       = "root:root"
        permissions = "0777"
      }]
    })
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "startup.sh"
    content      = local.startup_script
  }
}

resource "aws_instance" "proxy" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  depends_on = [module.vpc.aws_nat_gateway]

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.private_subnets[0]
  key_name               = "tp3"

  user_data = data.cloudinit_config.proxy_user_data.rendered

  tags = {
    Name = "log8415-tp3-proxy"
  }
}

resource "aws_instance" "gatekeeper" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  vpc_security_group_ids      = [module.vpc.default_security_group_id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name                    = "tp3"

  user_data = data.cloudinit_config.gatekeeper_user_data.rendered

  tags = {
    Name = "log8415-tp3-gatekeeper"
  }
}