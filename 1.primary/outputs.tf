output "region" {
  value = var.region
}

output "vault_namespace" {
  value = var.vault_namespace
}

output "vault_addr" {
  value = var.vault_addr
}

output "env" {
  value = var.env
}

output "azure_consul_user_assigned_identity_id" {
  value = module.iam.azure_consul_user_assigned_identity_id
}

output "aws_consul_public_ip" {
  value = module.aws-consul-primary.aws_consul_public_ip
}

output "aws_consul_client_public_ip" {
  value = module.aws-consul-primary.aws_consul_client_public_ip
}

output "aws_mgw_public_ip" {
  value = module.aws-consul-primary.aws_mgw_public_ip
}

output "useful_logs" {
  value = <<EOF

Master Token: 
	export CONSUL_HTTP_TOKEN=${data.terraform_remote_state.vault_state.outputs.master_token}

=== AWS ===
SSH to consul server:
	ssh ubuntu@${module.aws-consul-primary.aws_consul_public_ip}

SSH to consul client:
	ssh ubuntu@${module.aws-consul-primary.aws_consul_client_public_ip}

SSH to MGW:
	ssh ubuntu@${module.aws-consul-primary.aws_mgw_public_ip}

Consul UI:
	http://${module.aws-consul-primary.aws_consul_public_ip}:8500
		

EOF
}
