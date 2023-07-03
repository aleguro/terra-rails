/* ------------------------------------ Networking ------------------------------------ */

resource "aws_vpc" "vpc" {
  cidr_block  = "${var.vpc_cidr}"
 
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = "${var.environment}"
  }

  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_security_group" "default" {
  name        = "${var.environment}-default-sg"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = "${aws_vpc.vpc.id}"
  depends_on  = [aws_vpc.vpc]

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3002
    to_port     = 3002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "${var.environment}"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name        = "${var.environment}-igw"
    Environment = "${var.environment}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = "${var.environment}"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.ig.id}"
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  count                   = "${length(var.public_subnets_cidr)}"
  cidr_block              = "${element(var.public_subnets_cidr, count.index)}"
  availability_zone       = "${element(var.availability_zones, count.index)}"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-${element(var.availability_zones, count.index)}-public-subnet"
    Environment = "${var.environment}"
  }
}

resource "aws_route_table_association" "public" {
  count          = "${length(var.public_subnets_cidr)}"
  subnet_id      = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

/* ------------------------------------ Load balancer ------------------------------------ */

resource "aws_alb" "alb" {
  name             = "${var.environment}-alb"
  subnets          = aws_subnet.public_subnet.*.id
  security_groups  = ["${aws_security_group.default.id}"]
  
  tags = {
    Name        = "${var.environment}-alb"
    Environment = "${var.environment}"
  }
}

/* ------------------------------------ SSH key file ------------------------------------ */

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = "${var.environment}-bastion-key"
  public_key = tls_private_key.key.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.key.private_key_pem}' > ./${var.environment}.key.pem"
  }
}

/* ------------------------------------ Cloud Watch ------------------------------------ */

resource "aws_cloudwatch_log_group" "api" {
  name = "${var.environment}-cloudwatch-api"

  tags = {
    Environment = "${var.environment}"
    Application = "Api"
  }
}

/* ------------------------------------ Instance ------------------------------------ */

resource "aws_iam_policy" "policies" {
  name        = "${var.environment}-cloudwatch-access-policy-dev"
  description = "Provides permission to access cloudwatch"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:CreateLogGroup",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:UpdateApplication",
                "codedeploy:CreateApplication",
                "codedeploy:GetOnPremisesInstance",
                "codedeploy:GetDeploymentInstance"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Resource": "*"
            "Effect": "Allow",
            "Action": [
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:CompleteLayerUpload",
                "ecr:GetDownloadUrlForLayer",
                "ecr:InitiateLayerUpload",
                "ecr:PutImage",
                "ecr:UploadLayerPart",
                "ecr:DescribeImages",
                "ecr:GetAuthorizationToken",
                "ecr:ListImages"
            ]
        },
        {
            "Resource": "*"
            "Effect": "Allow",
            "Action": [
              "ec2:DescribeInstances", 
              "ec2:DescribeImages",
              "ec2:DescribeTags", 
              "ec2:DescribeSnapshots"
            ]
        }
    ]
  })
}

resource "aws_iam_role" "ec2-role" {
  name = "${var.environment}-dev-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "RoleForEC2"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
       "Sid": "",
       "Effect": "Allow",
       "Principal": {
         "Service": [
           "codedeploy.amazonaws.com"
         ]
       },
       "Action": "sts:AssumeRole"
     },
    ]
  })
}

resource "aws_iam_policy_attachment" "dev-profile-policy-attach" {
  name       = "${var.environment}-dev-policy-attachment"
  roles      = [aws_iam_role.ec2-role.name]
  policy_arn = aws_iam_policy.policies.arn
}

resource "aws_iam_instance_profile" "dev-profile" {
  name = "${var.environment}-dev-profile"
  role = aws_iam_role.ec2-role.name
}

resource "aws_instance" "dev_instance" {
  instance_type         = var.instance_type
  ami                   = var.ami
  key_name              = aws_key_pair.key_pair.key_name
  iam_instance_profile  = aws_iam_instance_profile.dev-profile.name
  user_data             = templatefile("${path.module}/files/instance.tpl", {
    AwsAccessKey            = var.aws_access_key
    AwsAccessSecret         = var.aws_access_secret
    EcrHost                 = var.ecr_repository_url
    RailsEnv                = var.rails_env
    RailsSecret             = var.rails_secret
    Environment             = var.environment
    EnvironmentPrefix       = var.environment_prefix
    SmtpUser                = var.smtp_user
    SmtpPassword            = var.smtp_password    
    ApiCloudWatchGroup      = "${var.environment}-cloudwatch-api"
  })

  tags = {
    Name = "${var.environment}-server"
  }

  vpc_security_group_ids = [ "${aws_security_group.default.id}" ]
  subnet_id = aws_subnet.public_subnet[0].id
  
  root_block_device {
    volume_size = 20
  }
}

/* ------------------------------------ ALB / Instance ------------------------------------ */

resource "aws_eip" "dev_instance" {
  vpc      = true
  instance = aws_instance.dev_instance.id
}

resource "aws_eip_association" "eip_association" {
  instance_id   = aws_instance.dev_instance.id
  allocation_id = aws_eip.dev_instance.id
}


resource "aws_alb_target_group" "alb_target_group_api" {
  name     = "${var.environment}-alb-api-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "instance"

  health_check {
    interval            = 30
    path                = "/healthcheck"
    port                = "3000"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 4
    matcher             = 200
  }
}

resource "aws_alb_target_group_attachment" "target_group_attachment_api" {
  target_group_arn = aws_alb_target_group.alb_target_group_api.arn
  target_id        = aws_instance.dev_instance.id
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  depends_on        = [aws_instance.dev_instance]
  certificate_arn   = "${var.certificate_arn}"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.alb_target_group_ui.arn
  }
}

resource "aws_lb_listener_rule" "api" {
 
 listener_arn = aws_alb_listener.alb_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.alb_target_group_api.arn
  }

  condition {
    host_header {
      values = [ "${var.environment_prefix}-api.${var.domain}"]
    }
  }
}

/* ------------------------------------ DNS Records  ------------------------------------ */


resource "aws_route53_record" "development_api_record" {
  zone_id = "${var.zone_id}"
  name    = "${var.environment_prefix}-api"
  type    = "CNAME"
  ttl     = 60
  records = [ "${aws_alb.alb.dns_name}" ]
}

/* ------------------------------------ Secrets  ------------------------------------ */

/* Keys */
resource "aws_secretsmanager_secret" "ssh_host" {
  name  = "${var.environment}_SSH_HOST"
}

resource "aws_secretsmanager_secret" "ssh_key" {
  name  = "${var.environment}_SSH_KEY"
}

resource "aws_secretsmanager_secret" "ecr_url" {
  name  = "${var.environment}_ECR_URL"
}

/* Values */

resource "aws_secretsmanager_secret_version" "ssh_host" {
  secret_id     = aws_secretsmanager_secret.ssh_host.id
  secret_string = aws_instance.dev_instance.public_ip
}

resource "aws_secretsmanager_secret_version" "ssh_key" {
  secret_id     = aws_secretsmanager_secret.ssh_key.id
  secret_string = "${tls_private_key.key.private_key_pem}"
}

resource "aws_secretsmanager_secret_version" "ecr_url" {
  secret_id     = aws_secretsmanager_secret.ecr_url.id
  secret_string = var.ecr_repository_url
}

resource "aws_secretsmanager_secret_version" "slack_webhook" {
  secret_id     = aws_secretsmanager_secret.slack_webhook.id
  secret_string = var.web_hook
}

/* ------------------------------------ Sns Topic ------------------------------------ */

locals {
  emails = ["alejandro.gurovich@gmail.com"]
}

resource "aws_sns_topic" "alarms_topic" {
  name            = "${var.environment}-alarms-topic"
  delivery_policy = jsonencode({
    "http" : {
      "defaultHealthyRetryPolicy" : {
        "minDelayTarget" : 20,
        "maxDelayTarget" : 20,
        "numRetries" : 3,
        "numMaxDelayRetries" : 0,
        "numNoDelayRetries" : 0,
        "numMinDelayRetries" : 0,
        "backoffFunction" : "linear"
      },
      "disableSubscriptionOverrides" : false,
      "defaultThrottlePolicy" : {
        "maxReceivesPerSecond" : 1
      }
    }
  })
}

resource "aws_sns_topic_subscription" "alarms_topic_email_subscription" {
  count     = length(local.emails)
  topic_arn = aws_sns_topic.alarms_topic.arn
  protocol  = "email"
  endpoint  = local.emails[count.index]
}

/* ------------------------------------ Alarms ------------------------------------ */

resource "aws_cloudwatch_metric_alarm" "target-healthy-count" {
  alarm_name          = "${var.environment}-${replace(aws_alb_target_group.alb_target_group_api.arn_suffix,"/(targetgroup/)|(/\\w+$)/","")}-Healthy-Count"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"

  dimensions = {
    LoadBalancer = "${aws_alb.alb.arn_suffix}"
    TargetGroup  = "${aws_alb_target_group.alb_target_group_api.arn_suffix}"
  }

  alarm_description  = "Trigger an alert when ${aws_alb_target_group.alb_target_group_api.arn_suffix} has 1 or more unhealthy hosts"
  alarm_actions      = ["${aws_sns_topic.alarms_topic.arn}"]
  ok_actions         = ["${aws_sns_topic.alarms_topic.arn}"]
  treat_missing_data = "breaching"
}