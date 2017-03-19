// AWS Region

provider "aws" {
  region     = "${var.region}"
}

//
// EFS - Elastic File System
//
resource "aws_efs_file_system" "es-data" {
  creation_token = "es-persistent-data"
  performance_mode = "generalPurpose"

  tags {
    Name = "elasticsearch-data"
  }
}

resource "aws_efs_mount_target" "elasticsearch" {
  file_system_id = "${aws_efs_file_system.es-data.id}"
  subnet_id      = "${element(split(",", var.private_subnet_ids), count.index )}"
}

//
// ECS - elasticsearch
//

resource "aws_ecs_cluster" "elasticsearch" {
    name = "${var.name}"
}

# User data template that specifies how to bootstrap each instance
data "template_file" "user_data" {
  template = "${file("${path.module}/user-data.tpl")}"

  vars {
    ecs_name = "${var.name}"
    efs_file_system_id = "${aws_efs_file_system.es-data.id}"
  }
}

resource "aws_instance" "ecs-elasticsearch" {
    ami                    = "${var.instance_ami}"
    instance_type          = "${var.instance_type}"

    count = "${var.instance_count}"

    availability_zone      = "${element(split(",", var.availability_zones), count.index )}"
    subnet_id              = "${element(split(",", var.private_subnet_ids), count.index )}"
    vpc_security_group_ids = [ "${aws_security_group.elasticsearch.id}" ]

    iam_instance_profile   = "${aws_iam_instance_profile.elasticsearch.name}"
    key_name               = "${var.key_name}"

    user_data = "${data.template_file.user_data.rendered}"

    tags {
        Name = "ecs/${var.name}-${count.index}"
    }

}

resource "aws_cloudwatch_log_group" "ecs-elasticsearch" {
    name = "ecs-${var.name}"
    retention_in_days = 7
}


resource "aws_ecs_service" "elasticsearch" {
    name = "${var.name}"

    desired_count = "${var.service_desired_count}"

    cluster = "${aws_ecs_cluster.elasticsearch.id}"
    task_definition = "${aws_ecs_task_definition.elasticsearch.arn}"

    iam_role = "${aws_iam_role.elasticsearch.name}"

    load_balancer {
        elb_name = "${aws_elb.elasticsearch.name}"
        container_name = "${var.name}"
        container_port = 9200
    }
}


resource "aws_ecs_task_definition" "elasticsearch" {
    family = "${var.name}"

    container_definitions = <<EOF
[
    {
        "name": "${var.name}",
        "image": "${var.image_elasticsearch}",
        "essential": true,
        "memory": ${var.task_memory},
        "environment" : [
            { "name" : "ES_HEAP_SIZE", "value" : "${ format( "%d", var.task_memory / 2 ) }m" }
        ],
        "command": [
            "elasticsearch",
            "-Des.discovery.type=ec2",
            "-Des.discovery.ec2.groups=${var.name}",
            "-Des.discovery.ec2.availability_zones=${var.availability_zones}",
            "-Des.cloud.aws.region=${var.region}"
        ],
        "MountPoints": [
            {
                "ContainerPath": "/usr/share/elasticsearch/data",
                "SourceVolume": "efs-es-data"
            }
        ],
        "portMappings": [
            {
                "containerPort": 9200,
                "hostPort": 9200
            },
            {
                "containerPort": 9300,
                "hostPort": 9300
            }
        ],
        "logConfiguration" : {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "ecs-${var.name}",
                "awslogs-region": "${var.region}"
            }
        }
    }
]
EOF

    volume {
        name = "efs-es-data"
        host_path = "/mnt/efs/esdata"
    }

}


resource "aws_elb" "elasticsearch" {
    name = "${var.name}"

    instances = ["${aws_instance.ecs-elasticsearch.*.id}"]

    subnets = [ "${split(",", var.private_subnet_ids)}" ]
    internal = true

    listener {
        lb_port = 9200
        lb_protocol = "http"
        instance_port = 9200
        instance_protocol = "http"
    }

    listener {
        lb_port = 9300
        lb_protocol = "tcp"
        instance_port = 9300
        instance_protocol = "tcp"
    }

    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        target = "TCP:9200"
        interval = 10
    }

    security_groups = [ "${aws_security_group.elasticsearch.id}" ]

    tags {
        Name = "${var.name}-01"
    }
}

# resource "aws_route53_record" "elasticsearch-local" {
#    zone_id = "${var.route53_zone_id_env}"
#    name = "${var.name}"
#    type = "CNAME"
#    ttl = "5"
#    records = [ "${aws_elb.elasticsearch.dns_name}" ]
# }


//
// security groups
//

resource "aws_security_group" "elasticsearch" {
    name = "${var.name}"
    description = "${var.name}"

    vpc_id = "${var.vpc_id}"

    ingress {
        from_port = "0"
        to_port = "0"
        protocol = "-1"
        cidr_blocks = [ "${var.vpc_cidr}" ]
    }

    egress {
        from_port = "0"
        to_port = "0"
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags {
        Name = "${var.name}"
    }
}


//
// iam
//

resource "aws_iam_role" "elasticsearch" {
    name = "${var.name}"
    assume_role_policy = <<EOH
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Principal": {
            "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
    },
    {
        "Effect": "Allow",
        "Principal": {
            "Service": "ecs.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
    }
  ]
}
EOH
}

resource "aws_iam_instance_profile" "elasticsearch" {
    name = "${var.name}"
    roles = [ "${aws_iam_role.elasticsearch.name}" ]
}

resource "aws_iam_role_policy" "elasticsearch" {
    name = "${var.name}"
    role = "${aws_iam_role.elasticsearch.id}"
    policy = <<EOH
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:Describe*",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:Describe*",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:Submit*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:CreateLogGroup",
        "logs:DescribeLogStreams",
        "elasticfilesystem:*"
      ],
      "Resource": "*"
    }
  ]
}
EOH
}
