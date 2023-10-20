resource "aws_account_alternate_contact" "security" {
  alternate_contact_type = "SECURITY"

  name              = "Test Name"
  title             = "Test Title2"
  phone_number      = "+1234567890"
  email_address     = "testemail@test.com"
}
