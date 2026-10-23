output "client_instance_id" {
  value = aws_instance.client.id
}

output "c2_instance_id" {
  value = aws_instance.c2.id
}

output "c2_private_ip" {
  value       = aws_instance.c2.private_ip
  description = "Beacon target. Also written to /etc/profile.d/blog-lab.sh on the client as C2_IP."
}

output "connect_client" {
  value = "aws ssm start-session --region ${var.region} --target ${aws_instance.client.id}"
}

output "connect_c2" {
  value = "aws ssm start-session --region ${var.region} --target ${aws_instance.c2.id}"
}

output "stop_all" {
  value       = "aws ec2 stop-instances --region ${var.region} --instance-ids ${aws_instance.client.id} ${aws_instance.c2.id}"
  description = "Run at the end of every session. Stopped instances only bill for EBS."
}

output "start_all" {
  value = "aws ec2 start-instances --region ${var.region} --instance-ids ${aws_instance.client.id} ${aws_instance.c2.id}"
}
