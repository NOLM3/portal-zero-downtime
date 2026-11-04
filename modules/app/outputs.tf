output "alb_dns_name" {
  description = "Direccion publica del ALB"
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "ARN del target group"
  value       = aws_lb_target_group.this.arn
}

output "web_sg_id" {
  description = "ID del security group de los servidores"
  value       = aws_security_group.web.id
}
