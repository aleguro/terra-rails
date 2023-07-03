
output "certificate_arn" {
  value = "${aws_acm_certificate.site.arn}"
}