output "useful_logs" {
  value = <<EOF
Master Token: 
	export CONSUL_HTTP_TOKEN=${data.terraform_remote_state.primary.outputs.consul_master_tokend}

=== AWS ===
SSH to consul server:
	ssh ubuntu@${data.terraform_remote_state.primary.outputs.aws_consul_public_ip}

SSH to MGW:
	ssh ubuntu@${data.terraform_remote_state.primary.outputs.aws_mgw_public_ip}

Consul UI:
	http://${data.terraform_remote_state.primary.outputs.aws_consul_public_ip}:8500
		

=== Azure ===
SSH to consul server:
	ssh ubuntu@${module.azure-consul-secondary.azure_consul_public_ip}

SSH to MGW:
	ssh ubuntu@${module.azure-consul-secondary.azure_mgw_public_ip}

Consul UI:
	http://${module.azure-consul-secondary.azure_consul_public_ip}:8500
		
EOF
}

