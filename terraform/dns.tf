data "aws_route53_zone" "root" {
  name         = var.root_domain
  private_zone = false
}

resource "aws_route53_record" "ecommerce_a" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = var.domain
  type    = "A"
  ttl     = 300
  records = [aws_eip.ecommerce.public_ip]
}

resource "aws_route53_record" "ecommerce_www" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "www.${var.domain}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.ecommerce.public_ip]
}
