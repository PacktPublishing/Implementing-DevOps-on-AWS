# Set a Provider
provider "aws" {
  region = "${var.aws-region}"
}

### VPC ###

# Create a VPC
resource "aws_vpc" "terraform-vpc" {
  cidr_block = "${var.vpc-cidr}"

  tags {
    Name = "${var.vpc-name}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "terraform-igw" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"
}

# Create public route tables
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.terraform-igw.id}"
  }

  tags {
    Name = "Public"
  }
}

# Create and associate public subnets with a route table
resource "aws_subnet" "public-1" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"
  cidr_block = "${cidrsubnet(var.vpc-cidr, 8, 1)}"
  availability_zone = "${element(split(",",var.aws-availability-zones), count.index)}"
  map_public_ip_on_launch = true

  tags {
    Name = "Public"
  }
}

resource "aws_route_table_association" "public-1" {
  subnet_id = "${aws_subnet.public-1.id}"
  route_table_id = "${aws_route_table.public.id}"
}


### EC2 ###

resource "aws_security_group" "jenkins" {
  name = "jenkins"
  description = "ec2 instance security group"
  vpc_id = "${aws_vpc.terraform-vpc.id}"

  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "443"
    to_port = "443"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_iam_role" "jenkins" {
    name = "jenkins"
    path = "/"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "jenkins" {
    name = "jenkins"
    role = "${aws_iam_role.jenkins.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
       {
            "Effect": "Allow",
            "Action": [
                "codecommit:Get*",
                "codecommit:GitPull",
                "codecommit:List*"
            ],
            "Resource": "*"
       },
       {
            "Effect": "Allow",
            "NotAction": [
                "s3:DeleteBucket"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "jenkins" {
    name = "jenkins"
    roles = ["${aws_iam_role.jenkins.name}"]
}

resource "aws_instance" "jenkins" {
    ami = "${var.jenkins-ami-id}"
    instance_type = "${var.jenkins-instance-type}"
    key_name = "${var.jenkins-key-name}"
    vpc_security_group_ids = ["${aws_security_group.jenkins.id}"]
    iam_instance_profile = "${aws_iam_instance_profile.jenkins.id}"
    subnet_id = "${aws_subnet.public-1.id}"
    tags { Name = "jenkins" }
    user_data = <<EOF
#!/bin/bash
set -euf -o pipefail
exec 1> >(logger -s -t $(basename $0)) 2>&1
# Install Git and set CodeComit connection settings
# (required for access via IAM roles)
yum -y install git
git config --system credential.helper '!aws codecommit credential-helper $@'
git config --system credential.UseHttpPath true
# Clone the Salt repository
git clone https://git-codecommit.us-east-1.amazonaws.com/v1/repos/salt /srv/salt; chmod 700 /srv/salt
# Install SaltStack
yum -y install https://repo.saltstack.com/yum/amazon/salt-amzn-repo-latest-1.ami.noarch.rpm
yum clean expire-cache; yum -y install salt-minion; chkconfig salt-minion off
# Put custom minion config in place (for enabling masterless mode)
cp -r /srv/salt/minion.d /etc/salt/
## Trigger a full Salt run
salt-call state.apply
EOF

    lifecycle { create_before_destroy = true }
}

resource "aws_eip" "jenkins" {
  instance = "${aws_instance.jenkins.id}"
  vpc      = true
}
