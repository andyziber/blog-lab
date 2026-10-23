variable "region" {
  type    = string
  default = "us-west-2"
}

variable "name_prefix" {
  type    = string
  default = "blog-lab"
}

variable "vpc_cidr" {
  type    = string
  default = "10.50.0.0/16"
}

variable "client_instance_type" {
  type        = string
  default     = "t3.small"
  description = "Runs Zeek, Suricata, tcpdump and mitmproxy. t3.micro runs out of memory once Suricata loads the ET Open rules."
}

variable "c2_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "monthly_budget_usd" {
  type    = number
  default = 20
}

variable "alert_email" {
  type        = string
  description = "Set in terraform.tfvars (gitignored). Never commit an address."
}
