output "vpc_id" {
  description = "VPC id."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Base CIDR, for security group rules scoped to the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet ids, one per AZ - internet-facing load balancers and the Jenkins host."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet ids, one per AZ - EKS nodes and RDS."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "AZs the subnets were placed in, in subnet order."
  value       = local.azs
}

output "nat_public_ips" {
  description = "Egress addresses, for allowlisting Gaku's outbound calls to Nominatim and Overpass."
  value       = aws_eip.nat[*].public_ip
}
