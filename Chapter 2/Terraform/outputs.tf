output "VPC ID" {
  value = "${aws_vpc.terraform-vpc.id}"
}

output "NAT EIP" {
  value = "${aws_nat_gateway.terraform-nat.public_ip}"
}

output "ELB URI" {
  value = "${aws_elb.terraform-elb.dns_name}"
}

output "RDS Endpoint" {
  value = "${aws_db_instance.terraform.endpoint}"
}
