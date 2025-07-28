data "aws_ami" "windows2022" {
  most_recent = true
  owners      = ["801119661308"] # Amazon

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_ami" "ubuntu2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
locals {
  instances = {
    windows = {
      ami           = data.aws_ami.windows2022.id
      instance_type = "t3.medium"
      extra_ebs     = 2
      sg_config = {
        name        = "windows-sg"
        description = "Allow RDP"
        ingress_rules = [
          {
            from_port   = 3389
            to_port     = 3389
            protocol    = "tcp"
            cidr_blocks = ["176.34.130.192/32"]
          }
        ]
      }
      subnet_id = aws_subnet.public.id
      public_ip = true
    },
    al2023 = {
      ami           = data.aws_ami.al2023.id
      instance_type = "t3.micro"
      extra_ebs     = 1
      sg_config = {
        name        = "linux-sg"
        description = "Allow SSH"
        ingress_rules = [
          {
            from_port   = 22
            to_port     = 22
            protocol    = "tcp"
            cidr_blocks = ["176.34.130.192/32"]
          }
        ]
      }
      subnet_id = aws_subnet.public.id
      public_ip = true
    },
    ubuntu = {
      ami           = data.aws_ami.ubuntu2204.id
      instance_type = "t3.small"
      extra_ebs     = 0
      sg_config = {
        name        = "linux-sg-2"
        description = "Allow SSH"
        ingress_rules = [
          {
            from_port = 22
            to_port   = 22
            protocol  = "tcp"
            # security_groups = [aws_security_group.dynamic_sg.linux-sg.id]
            cidr_blocks = ["176.34.130.192/32"]
          }
        ]
      }
      subnet_id = aws_subnet.private.id
      public_ip = false
    }
  }
  device_letters = ["f", "g", "h", "i"]
  default_tags = {
    Environment = "POC"
    Project     = "POC"
    Owner       = "john.doe@example.com"
  }
  # Flattened map for EBS volumes
  ebs_volumes = merge([
    for instance_name, instance_config in local.instances : {
      for i in range(instance_config.extra_ebs) :
      "${instance_name}-ebs-${i}" => {
        instance_name = instance_name
        device_name   = "/dev/sd${local.device_letters[i]}"
        volume_index  = i
        subnet_id     = instance_config.subnet_id
      }
    }
  ]...)
}


resource "aws_security_group" "dynamic_sg" {
  for_each    = local.instances
  name        = each.value.sg_config.name
  description = each.value.sg_config.description
  vpc_id      = aws_vpc.Lab_VPC.id

  dynamic "ingress" {
    for_each = each.value.sg_config.ingress_rules
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = lookup(ingress.value, "cidr_blocks", null)
      security_groups = lookup(ingress.value, "security_groups", null)
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "ec2" {
  for_each                    = local.instances
  ami                         = each.value.ami
  instance_type               = each.value.instance_type
  key_name                    = "ta-ireland"
  subnet_id                   = each.value.subnet_id
  associate_public_ip_address = each.value.public_ip
  vpc_security_group_ids      = [aws_security_group.dynamic_sg[each.key].id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
    tags = merge(local.default_tags, {
      Name = "${title(each.key)}-root-ebs"
    })
  }

  # dynamic "ebs_block_device" {
  #   for_each = range(each.value.extra_ebs)
  #   content {
  #     device_name = "/dev/sd${local.device_letters[ebs_block_device.key]}" # /dev/sdf, /dev/sdg, etc.
  #     volume_size = 10
  #     volume_type = "gp2"
  #   }
  # }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 required
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  tags = merge(local.default_tags, {
    Name = "${title(each.key)}"
  })
}

resource "aws_ebs_volume" "extra_ebs" {
  for_each = local.ebs_volumes

  availability_zone = each.value.subnet_id == aws_subnet.public.id ? aws_subnet.public.availability_zone : aws_subnet.private.availability_zone
  size              = 10
  type              = "gp2"

  tags = merge(local.default_tags, {
    Name = "${each.value.instance_name}-block-ebs-${each.value.volume_index}"
  })
}

resource "aws_volume_attachment" "ebs_attachment" {
  for_each = local.ebs_volumes

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.extra_ebs[each.key].id
  instance_id = aws_instance.ec2[each.value.instance_name].id
}

# IAM Role for EC2 SSM Access
resource "aws_iam_role" "ssm_ec2_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach AmazonSSMManagedInstanceCore policy
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create the instance profile
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ec2-ssm-role"
  role = aws_iam_role.ssm_ec2_role.name
}
