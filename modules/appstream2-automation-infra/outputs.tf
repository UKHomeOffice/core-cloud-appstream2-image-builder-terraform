# Outputs
output "state_machine_arn" {
  description = "ARN of the Step Function state machine"
  value       = aws_sfn_state_machine.appstream_automation.arn
}

output "ssm_document_name" {
  description = "Name of the SSM document"
  value       = aws_ssm_document.appstream_setup.name
}

output "base_image_name" {
  description = "Base image name"
  value       = var.base_image_name
}
