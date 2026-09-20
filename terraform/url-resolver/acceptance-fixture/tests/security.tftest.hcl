mock_provider "aws" {
  mock_resource "aws_instance" {
    defaults = { iam_instance_profile = "", key_name = "" }
  }
}
variables {
  vpc_id               = "vpc-00000000000000001"
  subnet_id            = "subnet-00000000000000001"
  resolver_egress_ipv4 = "203.0.113.5"
  ami_id               = "ami-00000000000000001"
  user_data            = "#!/bin/sh\ntrue\n"
}
run "restricted_disposable_fixture" {
  command = apply
  assert {
    condition = (
      aws_instance.fixture.iam_instance_profile == "" &&
      aws_instance.fixture.key_name == "" &&
      aws_instance.fixture.metadata_options[0].http_tokens == "required" &&
      aws_instance.fixture.metadata_options[0].http_put_response_hop_limit == 1 &&
      aws_instance.fixture.instance_type == "t4g.nano" &&
      aws_instance.fixture.instance_initiated_shutdown_behavior == "terminate" &&
      alltrue([for rule in aws_security_group.fixture.ingress : rule.from_port == 80 && rule.to_port == 80 && rule.cidr_blocks == tolist(["203.0.113.5/32"])]) &&
      length(aws_security_group.fixture.ingress) == 1
    )
    error_message = "The disposable fixture must have no IAM credentials or SSH, require IMDSv2 for bootstrap, and only accept the resolver's exact egress IP."
  }
}

run "disable_metadata_after_bootstrap" {
  command = plan
  variables { bootstrap_metadata_enabled = false }
  assert {
    condition     = aws_instance.fixture.metadata_options[0].http_endpoint == "disabled"
    error_message = "Metadata must be disableable after cloud-init retrieves user-data."
  }
}
run "no_broad_ingress_input" {
  command = plan
  variables { resolver_egress_ipv4 = "0.0.0.0/0" }
  expect_failures = [var.resolver_egress_ipv4]
}
