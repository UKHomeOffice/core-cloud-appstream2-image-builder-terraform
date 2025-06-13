# IAM Role for Step Functions
resource "aws_iam_role" "step_function_role" {
  name = "${var.project_name}-step-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "step_function_policy" {
  name = "${var.project_name}-step-function-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appstream:CreateImageBuilder",
          "appstream:DeleteImageBuilder",
          "appstream:DescribeImageBuilders",
          "appstream:CreateImage",
          "appstream:DescribeImages",
          "appstream:UpdateImagePermissions",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:DescribeInstanceInformation",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "step_function_policy_attachment" {
  role       = aws_iam_role.step_function_role.name
  policy_arn = aws_iam_policy.step_function_policy.arn
}

# IAM Role for AppStream Image Builder
resource "aws_iam_role" "appstream_instance_role" {
  name = "${var.project_name}-appstream-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "appstream_instance_policy" {
  name = "${var.project_name}-appstream-instance-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssm:SendCommand",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "appstream_instance_policy_attachment" {
  role       = aws_iam_role.appstream_instance_role.name
  policy_arn = aws_iam_policy.appstream_instance_policy.arn
}

resource "aws_iam_role_policy_attachment" "appstream_ssm_managed_policy" {
  role       = aws_iam_role.appstream_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "appstream_instance_profile" {
  name = "${var.project_name}-appstream-instance-profile"
  role = aws_iam_role.appstream_instance_role.name
}

# SSM Document for package installation
resource "aws_ssm_document" "appstream_setup" {
  name          = "${var.project_name}-setup-document"
  document_type = "Automation"
  content       = file(var.doc_source)
  document_format = "JSON"
}

# Step Function State Machine
resource "aws_sfn_state_machine" "appstream_automation" {
  name       = "${var.project_name}-state-machine"
  role_arn   = aws_iam_role.step_function_role.arn
  definition = file(var.stepfn_definition_file)
}
