### VPC ###
variable "aws-region" {
  type = "string"
  description = "AWS region"
}
variable "aws-availability-zones" {
  type = "string"
  description = "AWS zones"
}
variable "vpc-cidr" {
  type = "string"
  description = "VPC CIDR"
}
variable "vpc-name" {
  type = "string"
  description = "VPC name"
}

### EC2 ###
variable "autoscaling-group-minsize" {
  type = "string"
  description = "Min size of the ASG"
}
variable "autoscaling-group-maxsize" {
  type = "string"
  description = "Max size of the ASG"
}
variable "autoscaling-group-image-id" {
  type="string"
  description = "EC2 AMI identifier"
}
variable "autoscaling-group-instance-type" {
  type = "string"
  description = "EC2 instance type"
}
variable "autoscaling-group-key-name" {
  type = "string"
  description = "EC2 ssh key name"
}
