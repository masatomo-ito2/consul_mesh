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

output "consul_master_token" {
	value = module.vault.master_token
}

output "aws_consul_public_ip" {
  value = module.aws-consul-primary.aws_consul_public_ip
}

output "aws_mgw_public_ip" {
  value = module.aws-consul-primary.aws_mgw_public_ip
}

output "useful_logs" {
  value = <<EOF
AppRole for Consul on AWS:
	Role ID: ${module.vault.aws_consul_role_id}
	Secret ID for Consul server: ${module.vault.aws_consul_secret_id}
	Secret ID for Mesh Gateway : ${module.vault.aws_mgw_secret_id}

Master Token: 
	export CONSUL_HTTP_TOKEN=${module.vault.master_token}

=== AWS ===
SSH to consul server:
	ssh ubuntu@${module.aws-consul-primary.aws_consul_public_ip}

SSH to MGW:
	ssh ubuntu@${module.aws-consul-primary.aws_mgw_public_ip}

Consul UI:
	http://${module.aws-consul-primary.aws_consul_public_ip}:8500
		

EOF
}



