output "VPC ID" {
  value = "${aws_vpc.terraform-vpc.id}"
}

output "ELB URI" {
  value = "${aws_elb.terraform-elb.dns_name}"
}
