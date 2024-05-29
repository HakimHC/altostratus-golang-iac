variable "app_name" {
  description = "Name of the code deploy app"
  type        = string
}

variable "deployment_group_name" {
  description = "Name of the code deploy deployment group"
  type        = string
}

variable "service_role_arn" {
  description = "Name of the code deploy deployment group"
  type        = string
}

variable "deployment_config_name" {
  description = "Deployment strategy name"
  type        = string
  default     = "CodeDeployDefault.ECSAllAtOnce"
}

variable "termination_wait_time_in_minutes" {
  description = "Minutes to wait before terminating blue instances after deployment"
  type        = number
  default     = 5
}

variable "ecs_cluster_name" {
  description = "Name of the ecs cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ecs service"
  type        = string
}

variable "target_groups" {
  description = "Target groups to deploy to"
  type        = list(string)

  validation {
    condition     = length(var.target_groups) == 2
    error_message = "There must be exactly 2 target groups"
  }
}

variable "prod_listener_arn" {
  description = "ARN of the production alb listener."
  type        = string
}
