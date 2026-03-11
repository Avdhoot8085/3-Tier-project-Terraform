output "public-ip" {
  value = aws_instance.jume.elastic_ip[0].public_ip
}