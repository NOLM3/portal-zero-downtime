output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs de las subredes publicas"
  value       = aws_subnet.public[*].id
}
