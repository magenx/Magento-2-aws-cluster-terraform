


/////////////////////////////////////////////////////[ CODEPIPELINE IAM ]/////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeDeploy role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "codedeploy" {
  name = "${local.project}-codedeploy-role"
  description  = "Allows CodeDeploy to call AWS services on your behalf."
  path = "/service-role/"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codedeploy.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = {
     Name = "${local.project}-codedeploy-role"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for CodeDeploy role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_policy" "codedeploy" {
  name = "${local.project}-codedeploy-policy"
  path = "/service-role/"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCodeDeploySNSAlertTrigger",
            "Effect": "Allow",
            "Action": "sns:Publish",
            "Resource": "${aws_sns_topic.default.arn}"
        }
    ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policy for CodeDeploy role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "codedeploy" {
  policy_arn = aws_iam_policy.codedeploy.arn
  role       = aws_iam_role.codedeploy.id
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeBuild role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "codebuild" {
  name = "${local.project}-codebuild-role"
  description = "Allows CodeBuild to call AWS services on your behalf."
  path = "/service-role/"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codebuild.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = {
     Name = "${local.project}-codebuild-role"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for CodeBuild role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_policy" "codebuild" {
  name = "${local.project}-codebuild-policy"
  path = "/service-role/"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
      "Sid": "AllowCodeBuildGitPullActions",
      "Effect": "Allow",
      "Action": [
        "codecommit:GitPull"
      ],
      "Resource": "${aws_codecommit_repository.app.arn}"
    },
    {
      "Sid": "AllowCodeBuildEC2Actions",
      "Effect": "Allow",
      "Action": [
                "ec2:DescribeDhcpOptions",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeVpcs",
                "ec2:DeleteNetworkInterface",
                "ec2:CreateNetworkInterface",
                "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowCodeBuildGitPushActions",
      "Effect": "Allow",
      "Action": [
        "codecommit:GitPush"
      ],
      "Resource": "${aws_codecommit_repository.app.arn}",
      "Condition": {
                "StringEqualsIfExists": {
                    "codecommit:References": [
                        "refs/heads/build"
                     ]
                }
          }
    },
    {
      "Sid": "AllowCodeStarConnectionActions",
      "Effect": "Allow",
      "Action": [
        "codestar-connections:UseConnection"
       ],
      "Resource": "${aws_codestarconnections_connection.github.arn}"
    },
    {
      "Sid": "AllowCodeBuildGetParameters",
      "Effect": "Allow",
      "Action": [
	"ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/*"
    },
    {
      "Sid": "AllowCodebuildCreateLogs",
      "Effect": "Allow",
      "Action": [
         "logs:PutLogEvents",
         "logs:CreateLogStream"
      ],
      "Resource": "${aws_cloudwatch_log_group.codebuild.arn}:*"
     }
  ]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policy for CodeBuild role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "codebuild" {
  policy_arn = aws_iam_policy.codebuild.arn
  role       = aws_iam_role.codebuild.id
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodePipeline role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "codepipeline" {
  name = "${local.project}-codepipeline-role"
  description = "Allows CodePipeline to call AWS services on your behalf."
  path = "/service-role/"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codepipeline.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = {
     Name = "${local.project}-codepipeline-role"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create policy for CodePipeline role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_policy" "codepipeline" {
  name = "${local.project}-codepipeline-policy"
  path = "/service-role/"
  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [{
			"Sid": "AllowCodeCommitActions",
			"Effect": "Allow",
			"Action": [
				"codecommit:GetCommit",
				"codecommit:GetRepository",
				"codecommit:GetBranch"
			],
			"Resource": "${aws_codecommit_repository.app.arn}"
		},
                {
                        "Action": [
                                "sns:Publish"
                        ],
                        "Effect": "Allow",
                        "Resource": "${aws_sns_topic.default.arn}",
                        "Sid": "AllowSNSPublish"
                },
		{
			"Sid": "AllowCodeStarConnectionActions",
			"Effect": "Allow",
			"Action": [
				"codestar-connections:UseConnection"
			],
			"Resource": "${aws_codestarconnections_connection.github.arn}"
		},
		{
			"Sid": "AllowCodeBuildActions",
			"Effect": "Allow",
			"Action": [
				"codebuild:StartBuild",
				"codebuild:StartBuildBatch",
				"codebuild:BatchGetBuilds",
				"codebuild:BatchGetBuildBatches"
			],
			"Resource": [
				"${aws_codebuild_project.this.arn}",
				"${aws_codebuild_project.install.arn}"
			]
		}
	]
}
EOF
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Attach policy for CodePipeline role
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role_policy_attachment" "codepipeline" {
  policy_arn = aws_iam_policy.codepipeline.arn
  role       = aws_iam_role.codepipeline.id
}
