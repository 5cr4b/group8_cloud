output "s3_website_endpoint" {
  value = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "api_gateway_url" {
  value = aws_api_gateway_deployment.api_deployment.invoke_url
}