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

# Create NAT
resource "aws_eip" "nat-eip" {
  vpc = true
}

resource "aws_nat_gateway" "terraform-nat" {
  allocation_id = "${aws_eip.nat-eip.id}"
  subnet_id = "${aws_subnet.public-1.id}"
  depends_on = ["aws_internet_gateway.terraform-igw"]
}

# Create public and private route tables
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

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.terraform-nat.id}"
  }

  tags {
    Name = "Private"
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

resource "aws_subnet" "public-2" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"
  cidr_block = "${cidrsubnet(var.vpc-cidr, 8, 3)}"
  availability_zone = "${element(split(",",var.aws-availability-zones), count.index + 1)}"
  map_public_ip_on_launch = true

  tags {
    Name = "Public"
  }
}

resource "aws_route_table_association" "public-2" {
  subnet_id = "${aws_subnet.public-2.id}"
  route_table_id = "${aws_route_table.public.id}"
}

# Create and associate private subnets with a route table
resource "aws_subnet" "private-1" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"
  cidr_block = "${cidrsubnet(var.vpc-cidr, 8, 2)}"
  availability_zone = "${element(split(",",var.aws-availability-zones), count.index)}"
  map_public_ip_on_launch = false

  tags {
    Name = "Private"
  }
}

resource "aws_route_table_association" "private-1" {
  subnet_id = "${aws_subnet.private-1.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_subnet" "private-2" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"
  cidr_block = "${cidrsubnet(var.vpc-cidr, 8, 4)}"
  availability_zone = "${element(split(",",var.aws-availability-zones), count.index +1)}"
  map_public_ip_on_launch = false

  tags {
    Name = "Private"
  }
}

resource "aws_route_table_association" "private-2" {
  subnet_id = "${aws_subnet.private-2.id}"
  route_table_id = "${aws_route_table.private.id}"
}

### IAM ###

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

resource "aws_iam_role" "demo-app" {
    name = "demo-app"
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

resource "aws_iam_instance_profile" "jenkins" {
    name = "jenkins"
    roles = ["${aws_iam_role.jenkins.name}"]
}

resource "aws_iam_instance_profile" "demo-app" {
    name = "demo-app"
    roles = ["${aws_iam_role.demo-app.name}"]
}

resource "aws_iam_policy" "common" {
    name = "common"
    path = "/"
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

resource "aws_iam_policy" "jenkins" {
    name = "jenkins"
    path = "/"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ec2:AttachVolume",
           "ec2:CreateVolume",
           "ec2:DeleteVolume",
           "ec2:CreateKeypair",
           "ec2:DeleteKeypair",
           "ec2:DescribeSubnets",
           "ec2:CreateSecurityGroup",
           "ec2:DeleteSecurityGroup",
           "ec2:AuthorizeSecurityGroupIngress",
           "ec2:CreateImage",
           "ec2:CopyImage",
           "ec2:RunInstances",
           "ec2:DescribeVolumes",
           "ec2:DetachVolume",
           "ec2:DescribeInstances",
           "ec2:CreateSnapshot",
           "ec2:DeleteSnapshot",
           "ec2:DescribeSnapshots",
           "ec2:DescribeImages",
           "ec2:RegisterImage",
           "ec2:CreateTags",
           "ec2:StopInstances",
           "ec2:TerminateInstances",
           "ec2:ModifyImageAttribute"
         ],
         "Resource": "*"
       },
       {
         "Effect": "Allow",
         "Action": "iam:PassRole",
         "Resource": ["${aws_iam_role.demo-app.arn}"]
}
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "common" {
    name = "common"
    policy_arn = "${aws_iam_policy.common.arn}"
    roles = [
              "${aws_iam_role.jenkins.name}",
              "${aws_iam_role.demo-app.name}"
            ]
}

resource "aws_iam_policy_attachment" "jenkins" {
    name = "jenkins"
    policy_arn = "${aws_iam_policy.jenkins.arn}"
    roles = ["${aws_iam_role.jenkins.name}"]
}

### ELB ###

resource "aws_security_group" "demo-app-elb" {
  name = "demo-app-elb"
  description = "ELB security group"
  vpc_id = "${aws_vpc.terraform-vpc.id}"

  ingress {
    from_port = "80"
    to_port = "80"
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

resource "aws_elb" "demo-app-elb" {
  name = "demo-app-elb"
  security_groups = ["${aws_security_group.demo-app-elb.id}"]
  subnets = ["${aws_subnet.public-1.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  tags {
    Name = "demo-app-elb"
  }
}

resource "aws_security_group" "demo-app-elb-prod" {
  name = "demo-app-elb-prod"
  description = "ELB security group"
  vpc_id = "${aws_vpc.terraform-vpc.id}"

  ingress {
    from_port = "80"
    to_port = "80"
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

resource "aws_elb" "demo-app-elb-prod" {
  name = "demo-app-elb-prod"
  security_groups = ["${aws_security_group.demo-app-elb-prod.id}"]
  subnets = ["${aws_subnet.public-1.id}", "${aws_subnet.public-2.id}"]
  cross_zone_load_balancing = true
  connection_draining = true
  connection_draining_timeout = 30

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  tags {
    Name = "demo-app-elb-prod"
  }
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

resource "aws_security_group" "demo-app" {
  name = "demo-app"
  description = "ec2 instance security group"
  vpc_id = "${aws_vpc.terraform-vpc.id}"

  ingress {
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    security_groups = ["${aws_security_group.demo-app-elb.id}", "${aws_security_group.demo-app-elb-prod.id}"]
  }

  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    security_groups = ["${aws_security_group.jenkins.id}"]
  }


  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
echo -e 'grains:\n roles:\n  - jenkins' > /etc/salt/minion.d/grains.conf
## Trigger a full Salt run
salt-call state.apply
EOF

    lifecycle { create_before_destroy = true }
}

resource "aws_eip" "jenkins" {
  instance = "${aws_instance.jenkins.id}"
  vpc      = true
}

resource "aws_launch_configuration" "demo-app-lcfg" {
    name = "placeholder_launch_config"
    image_id = "${var.jenkins-ami-id}"
    instance_type = "${var.jenkins-instance-type}"
    iam_instance_profile = "${aws_iam_instance_profile.demo-app.id}"
    security_groups = ["${aws_security_group.demo-app.id}"]
}

resource "aws_autoscaling_group" "demo-app-blue" {
  name = "demo-app-blue"
  launch_configuration = "${aws_launch_configuration.demo-app-lcfg.id}"
  vpc_zone_identifier = ["${aws_subnet.private-1.id}", "${aws_subnet.private-2.id}"]
  min_size = 0
  max_size = 0

  tag {
    key = "ASG"
    value = "demo-app-blue"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "demo-app-green" {
  name = "demo-app-green"
  launch_configuration = "${aws_launch_configuration.demo-app-lcfg.id}"
  vpc_zone_identifier = ["${aws_subnet.private-1.id}", "${aws_subnet.private-2.id}"]
  min_size = 0
  max_size = 0

  tag {
    key = "ASG"
    value = "demo-app-green"
    propagate_at_launch = true
  }
}
