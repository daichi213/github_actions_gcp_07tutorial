# ====================
#
# VPC
#
# ====================
resource "aws_vpc" "locker_app_vpc" {
  cidr_block                       = "10.1.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  instance_tenancy                 = "default"
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "locker_app_vpc"
  }
}

# ====================
#
# Internet Gateway
#
# ====================
resource "aws_internet_gateway" "locker_app_gateway" {
  vpc_id = aws_vpc.locker_app_vpc.id

  tags = {
    Name = "locker_app_gateway"
  }
}
# ====================
#
# Subnet
#
# ====================
resource "aws_subnet" "public_1a" {
  vpc_id            = "${aws_vpc.locker_app_vpc.id}"
  cidr_block        = cidrsubnet(aws_vpc.locker_app_vpc.cidr_block, 8, 1)
  availability_zone = "ap-northeast-1a"
  # trueにするとインスタンスにパブリックIPアドレスを自動的に割り当ててくれる
  map_public_ip_on_launch = false

  tags = {
    Name = "public_1a"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id            = "${aws_vpc.locker_app_vpc.id}"
  cidr_block        = cidrsubnet(aws_vpc.locker_app_vpc.cidr_block, 8, 4)
  availability_zone = "ap-northeast-1c"
  # trueにするとインスタンスにパブリックIPアドレスを自動的に割り当ててくれる
  map_public_ip_on_launch = false

  tags = {
    Name = "public_1c"
  }
}

resource "aws_subnet" "public_1d" {
  vpc_id            = "${aws_vpc.locker_app_vpc.id}"
  cidr_block        = cidrsubnet(aws_vpc.locker_app_vpc.cidr_block, 8, 7)
  availability_zone = "ap-northeast-1a"
  # trueにするとインスタンスにパブリックIPアドレスを自動的に割り当ててくれる
  map_public_ip_on_launch = false

  tags = {
    Name = "public_1d"
  }
}


# ====================
#
# Route Table
#
# ====================
resource "aws_route_table" "locker_app_route_table" {
  vpc_id = aws_vpc.locker_app_vpc.id

  tags = {
    Name = "locker_app_route_table"
  }
}

resource "aws_route" "locker_app_route" {
  gateway_id             = aws_internet_gateway.locker_app_gateway.id
  route_table_id         = aws_route_table.locker_app_route_table.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "example" {
  subnet_id      = "${aws_subnet.public_1a.id}"
  route_table_id = "${aws_route_table.locker_app_route_table.id}"
}

resource "aws_route_table_association" "pubic_1c" {
  subnet_id      = "${aws_subnet.public_1c.id}"
  route_table_id = "${aws_route_table.locker_app_route_table.id}"
}
# ====================
#
# Security Group
#
# ====================
resource "aws_security_group" "security_rule" {
  vpc_id = aws_vpc.locker_app_vpc.id
  name   = "security_rule"

  tags = {
    Name = "security_rule"
  }
}

# インバウンドルール(ssh接続用)
resource "aws_security_group_rule" "in_ssh" {
  security_group_id = aws_security_group.security_rule.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
}

# インバウンドルール(pingコマンド用)
resource "aws_security_group_rule" "in_icmp" {
  security_group_id = aws_security_group.security_rule.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
}

# インバウンドルール(httpアクセス用)
resource "aws_security_group_rule" "in_http" {
  security_group_id = aws_security_group.security_rule.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
}

# インバウンドルール(httpsアクセス用)
resource "aws_security_group_rule" "in_https" {
  security_group_id = aws_security_group.security_rule.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
}

# アウトバウンドルール(全開放)
resource "aws_security_group_rule" "out_all" {
  security_group_id = aws_security_group.security_rule.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}

# ====================
#
# Elastic IP
#
# ====================
resource "aws_eip" "my_eip" {
  instance   = aws_instance.locker_app_instance.id
  vpc        = true
  depends_on = [aws_internet_gateway.locker_app_gateway]
}

# ====================
#
# EC2 Instance
#
# ====================
resource "aws_instance" "locker_app_instance" {
  ami                    = "ami-0ce107ae7af2e92b5"
  vpc_security_group_ids = [aws_security_group.security_rule.id]
  subnet_id              = aws_subnet.public_1a.id
  key_name               = aws_key_pair.my_key_pair.id
  instance_type          = "t2.micro"
  monitoring             = false
  tags = {
    Name = "locker_app_instance"
  }
  lifecycle {
    prevent_destroy = true
  }
}

# ====================
#
# Key Pair
#
# ====================
resource "aws_key_pair" "my_key_pair" {
  key_name   = "my-key-pair"
  public_key = file("./my-key-pair.pub")
}


# ====================
#
# SSL化手続き
#
# ====================
resource "aws_route53_zone" "route53-zone" {
  name = "lockerappli.com"
  # private_zone = false
}

data "aws_route53_zone" "route53-zone" {
  name = "lockerappli.com"
  # private_zone = false
}

resource "aws_acm_certificate" "cert" {
  # private_key       = tls_private_key.ssl_key_type.private_key_pem
  # certificate_body  = tls_self_signed_cert.ssl_key.cert_pem
  domain_name       = "www.lockerappli.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.route53-zone.zone_id
  name    = "www.lockerappli.com"
  type    = "A"

  alias {
    name                   = aws_lb.myalb.dns_name
    zone_id                = aws_lb.myalb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = data.aws_route53_zone.route53-zone.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

# ACM証明書とCNAMEレコードの連携
resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

data "aws_subnet_ids" "subs" {
  vpc_id = "${aws_vpc.locker_app_vpc.id}"
}

# ELBは異なるアベイラビリティゾーンに割り当てたsubnetをそれぞれ2つ以上指定する必要がある
resource "aws_lb" "myalb" {
  name                       = "myalb"
  load_balancer_type         = "application"
  internal                   = false
  idle_timeout               = 60
  enable_deletion_protection = false

  subnets = "${data.aws_subnet_ids.subs.ids}"
}

resource "aws_lb_target_group" "myapp" {
  name                 = "myapp"
  port                 = 80
  protocol             = "HTTP"
  # 2020/11/13現在未対応
  # protocol_version     = "HTTP2"
  vpc_id               = aws_vpc.locker_app_vpc.id
  deregistration_delay = "10"

  health_check {
    protocol            = "HTTP"
    path                = "/"
    port                = 80
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    matcher             = 200
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    target_group_arn = aws_lb_target_group.myapp.arn
    type             = "forward"
  }
}

resource "aws_lb_listener_certificate" "example" {
  listener_arn    = aws_lb_listener.front_end.arn
  certificate_arn = aws_acm_certificate.cert.arn
}

resource "aws_lb_target_group_attachment" "myinstance" {
  # count            = length(var.lb_target_config.instance_id)
  target_group_arn = aws_lb_target_group.myapp.arn
  target_id        = aws_instance.locker_app_instance.id
  # target_id        = element(var.lb_target_config.instance_id, count.index % length(var.lb_target_config.instance_id))
  port = 80
}