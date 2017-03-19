
variable "name" { default = "rdaes" }

variable "image_elasticsearch" { default = "965717236348.dkr.ecr.eu-west-1.amazonaws.com/rda/es_1.7" }

variable "vpc_id" {}
variable "vpc_cidr" {}

variable "region" { default = "eu-west-1" }
variable "availability_zones" {}
variable "private_subnet_ids" {}

variable "key_name" {}

variable "instance_ami" { default = "ami-a7f2acc1" }
variable "instance_type" { default = "t2.micro" }
variable "instance_count" { default = 2 }

variable "service_desired_count"  { default = 1 }
# variable "service_iam_role_name" {}

variable "task_memory" { default = 300 }

# variable "route53_zone_id_env" {}

variable "ignore_changes" { default = "task_definition,container_definitions" }

