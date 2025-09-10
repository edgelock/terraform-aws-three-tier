# ===================================================================================
# NETWORKING RESOURCES
# ===================================================================================

# --- Virtual Private Cloud (VPC) ---
resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "Main VPC"
  }
}

# --- Public Subnets ---
resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = "us-east-1${element(["a", "b"], count.index)}" # Spreads subnets across AZs

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

# --- Private Subnets for Database ---
resource "aws_subnet" "private_db_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = "us-east-1${element(["a", "b"], count.index)}"

  tags = {
    Name = "Private DB Subnet ${count.index + 1}"
  }
}

# --- Internet Gateway & Public Route Table ---
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "Main IGW"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Route for all outbound internet traffic
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

# --- Route Table Association ---
resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# ===================================================================================
# SECURITY GROUPS (FIREWALL RULES)
# ===================================================================================

# --- Web Server Security Group ---
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Allow HTTP, HTTPS, and SSH inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: For production, restrict this to your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web SG"
  }
}

# --- Database Security Group ---
resource "aws_security_group" "database_sg" {
  name        = "database-sg"
  description = "Allow inbound traffic from the application layer"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description     = "Allow MySQL traffic from Web SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database SG"
  }
}

# ===================================================================================
# KEY PAIR RESOURCES (FOR EC2 SSH ACCESS)
# ===================================================================================

# --- Generate a Private Key and Upload to AWS ---
# This creates a new key pair for EC2 SSH access and saves the private key
# locally as tests.pem.

resource "tls_private_key" "main_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "generated_key" {
  key_name   = "tests"
  public_key = tls_private_key.main_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.main_key.private_key_pem
  filename        = "tests.pem"
  file_permission = "0600"
}

# ===================================================================================
# COMPUTE RESOURCES (EC2 INSTANCES)
# ===================================================================================

# --- EC2 Web Server Instances ---
resource "aws_instance" "web_server" {
  count = 2
  ami                         = "ami-0023921b4fcd5382b" # Latest Amazon Linux 2 AMI
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.generated_key.key_name # Use the generated key
  subnet_id                   = aws_subnet.public_subnets[count.index].id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  user_data                   = fileexists("data.sh") ? file("data.sh") : null

  tags = {
    Name = "Web Server ${count.index + 1}"
  }
}

# ===================================================================================
# LOAD BALANCER RESOURCES
# ===================================================================================

# --- Application Load Balancer (ALB) ---
resource "aws_lb" "external_alb" {
  name               = "external-application-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  tags = {
    Name = "External ALB"
  }
}

# --- Target Group ---
resource "aws_lb_target_group" "web_app_tg" {
  name     = "web-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id
}

# --- Target Group Attachments ---
resource "aws_lb_target_group_attachment" "web_server_attachment" {
  count            = length(aws_instance.web_server)
  target_group_arn = aws_lb_target_group.web_app_tg.arn
  target_id        = aws_instance.web_server[count.index].id
  port             = 80
}

# --- ALB Listener ---
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_app_tg.arn
  }
}

# ===================================================================================
# DATABASE RESOURCES (RDS)
# ===================================================================================

# --- RDS Subnet Group ---
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "main-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private_db_subnets : subnet.id]

  tags = {
    Name = "Main DB Subnet Group"
  }
}

# --- RDS MySQL Instance ---
resource "aws_db_instance" "main_database" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "8.0.37" # Updated to a valid version
  instance_class         = "db.t3.micro"
  db_name                = "mydb"
  username               = "adminuser"
  password               = "YourSecurePassword123" # NOTE: Use a secrets manager in production
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database_sg.id]
  skip_final_snapshot    = true
}

# ===================================================================================
# OUTPUTS
# ===================================================================================

# --- Load Balancer DNS Name ---
output "load_balancer_dns" {
  description = "The public DNS name of the Application Load Balancer"
  value       = aws_lb.external_alb.dns_name
}