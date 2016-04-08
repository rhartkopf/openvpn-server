variable "access_key" {}
variable "secret_key" {}
variable "region" {
  default = "us-east-1"
}
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}
variable "amis" {
  default = {
    us-east-1 = "ami-08111162"
  }
}

###################################
###          Instances          ###
###################################

resource "aws_instance" "vpn-server" {
  ami = "${lookup(var.amis, var.region)}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.vpn-server.id}"
  key_name = "${aws_key_pair.deployer.key_name}"
  vpc_security_group_ids = ["${aws_security_group.vpn-server.id}"]
  root_block_device = {
    volume_type = "gp2"
    volume_size = 8
  }
  tags {
    Name = "saveme.ryanhartkopf.com"
  }
}
resource "aws_eip" "web01" {
  instance = "${aws_instance.vpn-server.id}"
  vpc = true
}

###################################
###          Security           ###
###################################

resource "aws_security_group" "ssh-access" {
  name = "all-servers"
  description = "Global firewall rules"
  vpc_id = "${aws_vpc.main.id}"
}
resource "aws_security_group_rule" "ssh-access-in-1" {
  security_group_id = "${aws_security_group.ssh-access.id}"
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["50.183.194.24/32"]
}

resource "aws_security_group" "vpn-server" {
  name = "vpn-server"
  description = "VPN server"
  vpc_id = "${aws_vpc.main.id}"
}
resource "aws_security_group_rule" "vpn-server-in-1" {
  security_group_id = "${aws_security_group.vpn-server.id}"
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["50.183.194.24/32"]
}
resource "aws_security_group_rule" "vpn-server-in-2" {
  security_group_id = "${aws_security_group.vpn-server.id}"
  type = "ingress"
  from_port = 1194
  to_port = 1194
  protocol = "udp"
  cidr_blocks = ["0.0.0.0/0"]
}

###################################
###           Subnet            ###
###################################

resource "aws_subnet" "vpn-clients" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.0.0/24"
  availability_zone = "${var.region}a"
  tags {
    Name = "vpn-clients"
    Description = "Reserved for VPN traffic. Please do not launch hosts into this subnet."
  }
}

resource "aws_subnet" "vpn-server" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  tags {
    Name = "vpn-server"
  }
}

###################################
###            Keys             ###
###################################

resource "aws_key_pair" "deployer" {
  key_name = "deployer-key"
  public_key = "${file(\"ssh/insecure-deployer.pub\")}"
}

###################################
###             VPC             ###
###################################

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags {
    Name = "personal"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
  tags {
    Name = "${aws_vpc.main.tags.Name}"
  }
}

