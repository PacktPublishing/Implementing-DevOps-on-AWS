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

### RDS ###
variable "rds-identifier" {
  type = "string"
  description = "RDS instance identifier"
}
variable "rds-storage-size" {
  type = "string"
  description = "Storage size in GB"
}
variable "rds-storage-type" {
  type = "string"
  description = "Storage type"
}
variable "rds-engine" {
  type = "string"
  description = "RDS type"
}
variable "rds-engine-version" {
  type = "string"
  description = "RDS version"
}
variable "rds-instance-class" {
  type = "string"
  description = "RDS instance class"
}
variable "rds-username" {
  type = "string"
  description = "RDS username"
}
variable "rds-password" {
  type = "string"
  description = "RDS password"
}
variable "rds-port" {
  type = "string"
  description = "RDS port number"
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
