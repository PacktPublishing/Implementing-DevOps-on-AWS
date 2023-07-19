output "VPC ID" {
  value = "${aws_vpc.terraform-vpc.id}"
}

output ""
output "JENKINS EIP" {
  value = "${aws_eip.jenkins.public_ip}"
}

output "server_info" {
  value = aws_instance.jenkins
}

resource "null_resource" "create_server_trigger" {
  triggers = {
    server_id = aws_instance.jenkins.id
  }

  provisioner "local-exec" {
    command = <<EOF
      echo "Server ID: ${aws_instance.jenkins.id}" > create-server-ansible
      echo "Server Public IP: ${aws_instance.jenkins.public_ip}" >> create-server-ansible
      echo "Server Private IP: ${aws_instance.jenkins.private_ip}" >> create-server-ansible
      echo "Server DNS: ${aws_instance.jenkins.public_dns}" >> create-server-ansible
      echo "Server SSH Key Name: ${aws_instance.jenkins.key_name}" >> create-server-ansible
      echo "Server Username: <provide username>" >> create-server-ansible
     EOF
  }
}
