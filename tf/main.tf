terraform {  
  
  # backend "s3" {  
  #   bucket       = "quasar-backend-state-locking"  
  #   key          = "terraform.tfstate"  
  #   region       = "us-east-1"  
  #   # encrypt      = true  
  #   # use_lockfile = true  #S3 native locking
  # }  
}

provider "aws" {
  region = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  depends_on = [aws_vpc.main]
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  depends_on = [aws_vpc.main, aws_subnet.public_a]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_subnet.public_a, aws_subnet.public_b]
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  depends_on = [aws_route.internet_access]
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.rt.id
  depends_on = [aws_route_table_association.a]
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.rt.id
  depends_on = [aws_route_table_association.b]
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [aws_subnet.public_a,aws_subnet.public_b]
}

resource "aws_security_group" "ecs_sg" {
  name   = "ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 1337
    to_port         = 1337
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [aws_subnet.public_a,aws_subnet.public_b]
}

resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb_sg.id]
  depends_on = [aws_security_group.alb_sg]
}

resource "aws_lb_target_group" "ecs_tg" {
  name     = "ecs-tg"
  port     = 1337
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/admin"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
  depends_on = [aws_lb.ecs_alb]
}

resource "aws_lb_listener" "ecs_listener_80" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.strapi_tg.arn
  }
}


resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = 1337
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
  depends_on = [aws_lb_target_group.ecs_tg]
}

resource "aws_ecs_cluster" "main" {
  name = "ecs-cluster"
  depends_on = [aws_vpc.main]
}

resource "aws_iam_role" "new_quasar_ecs_task_execution_role" {
  name = "new_quasar_ecsTaskExecutionRole8"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
  # depends_on = [aws_iam_role.ecs_task_execution_role]
}

resource "aws_iam_role_policy_attachment" "quasar_ecs_task_execution_policy" {
  role       = aws_iam_role.new_quasar_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# resource "aws_cloudwatch_log_group" "ecs_logs" {
#   name              = "/ecs/quasar-my-service"
#   retention_in_days = 7
# }


resource "aws_ecs_task_definition" "web" {
  family                   = "fargate-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "4096"
  execution_role_arn       = aws_iam_role.new_quasar_ecs_task_execution_role.arn

  container_definitions = jsonencode([
  {
    name      = "web",
    image     = var.image,
    essential = true,
    portMappings = [
      {
        containerPort = 1337,
        hostPort      = 1337,
        protocol      = "tcp"
      }
    ]
    # logConfiguration = {
    #   logDriver = "awslogs",
    #   options = {
    #     awslogs-group         = "/ecs/my-service",
    #     awslogs-region        = "us-east-1",
    #     awslogs-stream-prefix = "ecs"
    #   }
    # }
  }
])
}

resource "aws_ecs_service" "web" {
  name            = "web-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "web"
    container_port   = 1337
  }

  depends_on = [aws_lb_listener.ecs_listener]
}
