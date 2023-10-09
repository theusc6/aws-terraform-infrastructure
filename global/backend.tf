terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-name"  # replace with your bucket name
    region         = "us-west-2"                       # the AWS region of the bucket
    dynamodb_table = "my-lock-table"                   # replace with your DynamoDB table name
    encrypt        = true
  }
}
