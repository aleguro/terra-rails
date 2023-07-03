output "url" {
  value = "${aws_route53_record.development_ui_record.name}"
}

output "instance-ip" {
  value = "${aws_eip.dev_instance.public_ip}"
}