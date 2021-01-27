resource "aws_iam_instance_profile" "consul" {
  name = "consul-${var.env}"
  role = aws_iam_role.consul.name
}

resource "aws_iam_role" "consul" {
  name = "consul-${var.env}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "consul" {
  name = "consul-${var.env}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "consul" {
  role       = aws_iam_role.consul.name
  policy_arn = aws_iam_policy.consul.arn
}

resource "aws_iam_instance_profile" "nomad" {
  name = "nomad-${var.env}"
  role = aws_iam_role.nomad.name
}

resource "aws_iam_role" "nomad" {
  name = "nomad-${var.env}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "nomad" {
  name = "nomad-${var.env}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "nomad" {
  role       = aws_iam_role.nomad.name
  policy_arn = aws_iam_policy.nomad.arn
}
