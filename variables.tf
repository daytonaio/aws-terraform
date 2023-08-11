variable "region" {
  description = "AWS region"
  type        = string
}

variable "profile" {
  description = "AWS profile"
  type        = string
}

variable "base_domain" {
  type    = string
}

variable "app_node_group_instance_type" {
  description = "Application node group instance type"
  type        = string
  default     = "m4.large"
}

variable "longhorn_node_group_instance_type" {
  description = "Longhorn node group instance type"
  type        = string
  default     = "m4.large"
}

variable "longhorn_node_group_size" {
  description = "Longhorn node group number of instances"
  type        = number
  default     = 3
}

variable "longhorn_ebs_size" {
  description = "Disk size for Longhorn nodes"
  type        = number
  default     = 1000
}

variable "workload_node_group_instance_type" {
  description = "Workload node instance type"
  type        = string
  default     = "m4.4xlarge"
}

variable "workload_node_group_min_size" {
  description = "Workload node minimal number of instances"
  type        = number
  default     = 1
}

variable "workload_node_group_desired_size" {
  description = "Workload node desired number of instances"
  type        = number
  default     = 1
}

variable "workload_node_group_max_size" {
  description = "Workload node maximum number of instances"
  type        = number
  default     = 3
}

variable "allow_longhorn_remove" {
  description = "Allow Longhorn to be removed from the cluster automatically. Set to false if production cluster."
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "RDS deletion protection. Set to true if production cluster."
  type        = bool
  default     = false
}
