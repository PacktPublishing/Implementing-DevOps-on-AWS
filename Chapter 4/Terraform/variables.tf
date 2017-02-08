### VPC ###
variable "aws-region" {
  type = "string"
  description = "AWS region"
}
variable "vpc-cidr" {
  type = "string"
  description = "VPC CIDR"
}
variable "vpc-name" {
  type = "string"
  description = "VPC name"
}
variable "aws-availability-zones" {
  type = "string"
  description = "AWS zones"
}

### EC2 ###
variable "jenkins-ami-id" {
  type="string"
  description = "EC2 AMI identifier"
}
variable "jenkins-instance-type" {
  type = "string"
  description = "EC2 instance type"
}
variable "jenkins-key-name" {
  type = "string"
  description = "EC2 ssh key name"
}
