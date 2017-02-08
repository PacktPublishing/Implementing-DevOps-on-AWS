output "VPC ID" {
  value = "${aws_vpc.terraform-vpc.id}"
}

output "JENKINS EIP" {
  value = "${aws_eip.jenkins.public_ip}"
}
