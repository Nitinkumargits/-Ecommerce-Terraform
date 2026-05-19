resource "aws_key_pair" "ecommerce" {
  key_name   = "ecommerce-deploy-key"
  public_key = var.ec2_public_key
}

resource "aws_instance" "ecommerce" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ecommerce.id]
  key_name                    = aws_key_pair.ecommerce.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "ecommerce-server"
  }
}

resource "aws_eip" "ecommerce" {
  instance = aws_instance.ecommerce.id
  domain   = "vpc"

  tags = {
    Name = "ecommerce-eip"
  }

  depends_on = [aws_internet_gateway.ecommerce]
}
