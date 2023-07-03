# Api
resource "aws_ecr_repository" "api" {
  name                 = "api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "api_app_lifecycle_policy" {
  repository = "${aws_ecr_repository.api.name}"

  policy = <<EOF
  {
    "rules": [
      {
        "rulePriority": 1,
        "description": "Delete images when count is more than 500",
        "selection": {
          "tagStatus": "any",
          "countType": "imageCountMoreThan",
          "countNumber": 500
        },
        "action": {
          "type": "expire"
        }
      }
    ]
  }
EOF
}

# User to access ecr
resource "aws_iam_user" "cicd" {
  name = "cicd-user"
  path = "/system/" 
}

resource "aws_iam_access_key" "cicd" {
  user = aws_iam_user.cicd.name
}

resource "aws_iam_user_policy" "cicd" {
  name = "cicd-policy"
  user = aws_iam_user.cicd.name

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
               "ecr-public:GetAuthorizationToken",
              "sts:GetServiceBearerToken",
              "ecr-public:BatchCheckLayerAvailability",
              "ecr-public:GetRepositoryPolicy",
              "ecr-public:DescribeRepositories",
              "ecr-public:DescribeRegistries",
              "ecr-public:DescribeImages",
              "ecr-public:DescribeImageTags",
              "ecr-public:GetRepositoryCatalogData",
              "ecr-public:GetRegistryCatalogData",
              "ecr-public:InitiateLayerUpload",
              "ecr-public:UploadLayerPart",
              "ecr-public:CompleteLayerUpload",
              "ecr-public:PutImage"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
    ]
  })  
}

resource "aws_iam_user_login_profile" "cicd" {
  user    = aws_iam_user.cicd.name
  pgp_key = file("../gpg.pubkey")
}