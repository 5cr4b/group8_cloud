variable "frontend_bucket_name" {
  description = "Name of the S3 bucket for the frontend"
  type        = string
}

variable "backend_zip" {
  description = "Path to the backend ZIP file"
  type        = string
  default     = "backend.zip"
}

variable "db_host" {
  description = "PostgreSQL database host"
  type        = string
}

variable "db_port" {
  description = "PostgreSQL database port"
  type        = string
  default     = "5432"
}

variable "db_user" {
  description = "PostgreSQL database user"
  type        = string
}

variable "db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
}

variable "alert_email" {
  description = "Email for AWS budget alerts"
  type        = string
}

variable "secret_key" {
  description = "Secret key for JWT authentication"
  type        = string
  sensitive   = true
}