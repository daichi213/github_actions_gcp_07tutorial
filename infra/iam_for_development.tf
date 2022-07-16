# ====================
#
# IAM Group
#
# ====================
resource "aws_iam_group" "developers" {
  name = "developers"
}
# ====================
#
# IAM Groop Policy
#
# ====================
resource "aws_iam_group_policy" "my_developer_policy" {
  name  = "my_developer_policy"
  group = aws_iam_group.developers.name

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = file("./policies/instance_policy.json")
}

# ====================
#
# IAM User
#
# ====================
resource "aws_iam_user" "developer1" {
  name = "developer1"
  path = "/system/"

  tags = {
    tag-key = "developer1"
  }
}

resource "aws_iam_access_key" "developer1_access_key" {
  user = aws_iam_user.developer1.name
}
