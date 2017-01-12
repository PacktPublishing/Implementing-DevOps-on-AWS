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
  availability_zone = "${element(split(",",var.aws-availability-zones), count.index + 1)}"
  map_public_ip_on_launch = false

  tags {
    Name = "Private"
  }
}

resource "aws_route_table_association" "private-2" {
  subnet_id = "${aws_subnet.private-2.id}"
  route_table_id = "${aws_route_table.private.id}"
}


### RDS ###

resource "aws_security_group" "terraform-rds" {
  name = "terraform-rds"
  description = "RDS security group"
  vpc_id = "${aws_vpc.terraform-vpc.id}"

  ingress {
    from_port = "${var.rds-port}"
    to_port = "${var.rds-port}"
    protocol = "tcp"
    security_groups = ["${aws_security_group.terraform-ec2.id}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "rds" {
  name = "rds_subnet_group"
  description = "RDS subnet group"
  subnet_ids = ["${aws_subnet.private-1.id}", "${aws_subnet.private-2.id}"]
}

resource "aws_db_instance" "terraform" {
  identifier = "${var.rds-identifier}"
  allocated_storage = "${var.rds-storage-size}"
  storage_type= "${var.rds-storage-type}"
  engine = "${var.rds-engine}"
  engine_version = "${var.rds-engine-version}"
  instance_class = "${var.rds-instance-class}"
  username = "${var.rds-username}"
  password = "${var.rds-password}"
  port = "${var.rds-port}"
  vpc_security_group_ids = ["${aws_security_group.terraform-rds.id}"]
  db_subnet_group_name = "${aws_db_subnet_group.rds.id}"
}


### ELB ###

resource "aws_security_group" "terraform-elb" {
  name = "terraform-elb"
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

resource "aws_elb" "terraform-elb" {
  name = "terraform-elb"
  security_groups = ["${aws_security_group.terraform-elb.id}"]
  subnets = ["${aws_subnet.public-1.id}", "${aws_subnet.public-2.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  tags {
    Name = "terraform-elb"
  }
}


### EC2 ###

resource "aws_security_group" "terraform-ec2" {
  name = "terraform-ec2"
  description = "ec2 instance security group"
  vpc_id = "${aws_vpc.terraform-vpc.id}"

  ingress {
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    security_groups = ["${aws_security_group.terraform-elb.id}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_launch_configuration" "terraform-lcfg" {
    image_id = "${var.autoscaling-group-image-id}"
    instance_type = "${var.autoscaling-group-instance-type}"
    key_name = "${var.autoscaling-group-key-name}"
    security_groups = ["${aws_security_group.terraform-ec2.id}"]
    user_data = "#!/bin/bash \n set -euf -o pipefail \n exec 1> >(logger -s -t $(basename $0)) 2>&1 \n yum -y install nginx; chkconfig nginx on; service nginx start"

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "terraform-asg" {
  name = "terraform"
  launch_configuration = "${aws_launch_configuration.terraform-lcfg.id}"
  vpc_zone_identifier = ["${aws_subnet.private-1.id}", "${aws_subnet.private-2.id}"]
  min_size = "${var.autoscaling-group-minsize}"
  max_size = "${var.autoscaling-group-maxsize}"
  load_balancers = ["${aws_elb.terraform-elb.name}"]
  depends_on = ["aws_db_instance.terraform"]

  tag {
    key = "Name"
    value = "terraform"
    propagate_at_launch = true
  }
}
