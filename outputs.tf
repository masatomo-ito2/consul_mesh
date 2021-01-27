output "aws_consul_public_ip" {
  value = module.aws-consul-primary.aws_consul_public_ip
}

output "aws_mgw_public_ip" {
  value = module.aws-consul-primary.aws_mgw_public_ip
}

output "useful_logs" {
  value = <<EOF
Login to consul server:
	ssh ubuntu@${module.aws-consul-primary.aws_consul_public_ip}

Login to MGW:
	ssh ubuntu@${module.aws-consul-primary.aws_mgw_public_ip}
EOF
}



