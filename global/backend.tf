terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-name"  # replace with your bucket name
    key            = "path/to/my/key"                  # the path within the bucket where the state will be stored
    region         = "us-west-1"                       # the AWS region of the bucket
    dynamodb_table = "my-lock-table"                   # replace with your DynamoDB table name
    encrypt        = true
  }
}
