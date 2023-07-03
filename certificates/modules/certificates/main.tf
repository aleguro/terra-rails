resource "aws_acm_certificate" "site" {
  domain_name               = "${var.site_domain}"
  subject_alternative_names = ["*.${var.site_domain}"]
  validation_method         = "DNS"

   tags = {
    Environment = "certificate for ${var.site_domain}"
  }

  lifecycle {
    create_before_destroy = true
  }
}