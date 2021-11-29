provider "aws" {
    shared_credentials_file="${var.shared_credentials_file}"
    region                  = "${var.region}"
  
}
resource "aws_security_group" "ec2_allow_rule" {
  vpc_id = "vpc-0fc248fc45ee4cfab"
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    description = "MYSQL/Aurora"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow ssh,http,https"
  }
}


# Security group for RDS
resource "aws_security_group" "RDS_allow_rule" {
  vpc_id = "vpc-0fc248fc45ee4cfab"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.ec2_allow_rule.id}"]
  }
  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow ec2"
  }

}

# Create RDS instance
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.example.id, aws_subnet.example2.id]

  tags = {
    Name = "My DB subnet group"
  }
}
resource "aws_db_instance" "wordpressdb" {
  name                 = "${var.database_name}"
  allocated_storage    = 20
  max_allocated_storage = 50
  engine               = "mysql"
  engine_version       = "8.0.23"
  instance_class       = "db.t3.micro"
  db_subnet_group_name = aws_db_subnet_group.default.name
  #kms_key_id           = "arn:aws:kms:ap-south-1:035825521573:key/f2caef0e-dc31-49f7-a600-205065c58722"
  #storage_encrypted    = "true"
  vpc_security_group_ids =["${aws_security_group.RDS_allow_rule.id}"]
  username             = "${var.database_user}"
  password             = "${var.database_password}"
  skip_final_snapshot  = true
  deletion_protection  = true
  multi_az = true

  tags = {
    created-by = "linker-siddharth"
    env = "hu19"
    manages = "terraform"

  }
}

# change USERDATA varible value after grabbing RDS endpoint info
data "template_file" "user_data" {
  template = "${file("${path.module}/user_data.tpl")}"
  vars = {
    db_username="${var.database_user}"
    db_user_password="${var.database_password}"
    db_name="${var.database_name}"
    db_RDS="${aws_db_instance.wordpressdb.endpoint}"
  }
}
data "aws_vpc" "selected" {
  id = "vpc-0fc248fc45ee4cfab"
}

resource "aws_subnet" "example" {
  vpc_id            = data.aws_vpc.selected.id
  availability_zone = "ap-south-1b"
  cidr_block        = "10.1.8.0/21"
}
resource "aws_subnet" "example2" {
  vpc_id            = data.aws_vpc.selected.id
  availability_zone = "ap-south-1a"
  cidr_block        = "10.1.236.0/22"
}

# Create EC2 ( only after RDS is provisioned)
resource "aws_instance" "wordpressec2" {
  ami="${var.ami}"
  instance_type="${var.instance_type}"
  subnet_id = aws_subnet.example.id
  security_groups=["${aws_security_group.ec2_allow_rule.name}"]
  user_data = "${data.template_file.user_data.rendered}"
  key_name="${var.key_name}"
  tags = {
    created-by = "linker-siddharth"
    env = "hu19"
    manages = "terraform"

  }

  # this will stop creating EC2 before RDS is provisioned
  depends_on = [aws_db_instance.wordpressdb]
}

