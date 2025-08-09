module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "support-portal"

  engine            = "postgres"
  engine_version    = "14"
  instance_class    = "db.t4g.micro"
  allocated_storage = 10

  db_name  = "supportportal"
  username = "postgres"
  port     = "5432"

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = {
    Test = local.name
  }

  # DB subnet group
  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  # DB parameter group
  family = "postgres14" # DB parameter group

  # DB option group
  major_engine_version = "14"

  skip_final_snapshot = true

}

resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "DB security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Test = local.name
  }
}

output "db_instance_address" {
  value = module.db.db_instance_address
}

output "db_instance_port" {
  value = module.db.db_instance_port
}

output "db_instance_master_user_secret_arn" {
  value = module.db.db_instance_master_user_secret_arn
}

output "db_instance_name" {
  value = module.db.db_instance_name
}
