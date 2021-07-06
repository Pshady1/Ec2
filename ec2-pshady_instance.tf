provider "aws" {
	region = var.aws_region
}
resource "aws_key_pair" "my_first_terraform" {
  key_name   = "terraform_pshady"
  public_key = file("terraform_pshady.pub")
}

resource "aws_instance" "Instance1" {
  ami           = lookup(var.ami,var.aws_region)
  instance_type = var.instance_type
  key_name      = aws_key_pair.terraform_pshady.key_name
}

resource "aws_instance" "instance2" {
  count         = var.instance_count
  ami           = lookup(var.ami,var.aws_region)
  instance_type = var.instance_type
  key_name      = aws_key_pair.terraform_pshady.key_name
  user_data     = file("install_httpd.sh")

  tags = {
    Name  = element(var.instance_tags, count.index)
    Batch = "5AM"
  }
}

output "ip" {
  value = aws_instance.my-instance.*.public_ip
}
resource "aws_security_group" "webservers" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = aws_vpc.terra_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
# Create a new load balancer
resource "aws_elb" "pshady-elb" {
  name               = "pshady-elb"
  subnets = aws_subnet.public.*.id
  security_groups = [aws_security_group.webservers.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/index.html"
    interval            = 30
  }

  instances                   = [aws_instance.webservers[0].id, aws_instance.webservers[1].id]
  cross_zone_load_balancing   = true
  idle_timeout                = 100
  connection_draining         = true
  connection_draining_timeout = 300

  tags = {
    Name = "terraform-elb"
  }
}

output "elb-dns-name" {
  value = aws_elb.terra-elb.dns_name
}
