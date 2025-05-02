output "alb_dns_name" {
  value = aws_lb.ecs_alb.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}
