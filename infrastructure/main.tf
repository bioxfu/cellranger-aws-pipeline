provider "aws" {
  region  = "us-east-1"
  version = "~> 2.15"
}

# BEGIN COMPUTE ENVIRONMENT RESOURCES

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_role" {
  name = "ecsInstanceRole"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role" "pipeline" {
  name        = "cellranger-pipeline"
  description = "Allow ECS containers to read input and write output to S3."
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
        },
      ]
    }
  )
}

resource "aws_iam_role" "aws_batch_service_role" {
  name               = "AWSBatchServiceRole"
  path               = "/service-role/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Effect": "Allow",
            "Principal": {
                "Service": "batch.amazonaws.com"
            }
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role = aws_iam_role.aws_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# BEGIN VPC

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "cellranger-pipeline"
  }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.this.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_security_group" "all_outbound" {
  name = "all-inbound"
  vpc_id = aws_vpc.this.id
}

resource "aws_security_group_rule" "allow_all_outbound" {
  # this rule is necessary because batch won't be able to launch
  # containers without it. see
  # https://aws.amazon.com/premiumsupport/knowledge-center/batch-job-stuck-runnable-status/
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "all"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.all_outbound.id
}

# END VPC

resource "aws_batch_compute_environment" "cellranger_pipeline" {
  compute_environment_name = "${var.environment}-cellranger-pipeline"
  type = "MANAGED"

  compute_resources {
    image_id = "ami-000f5114abc141b76"

    instance_role = aws_iam_instance_profile.ecs_instance_role.arn
    instance_type = ["r5.4xlarge"]

    max_vcpus = 256
    min_vcpus = 0

    security_group_ids = [aws_security_group.all_outbound.id]

    subnets = [aws_subnet.public.id]

    tags = {
      "Name" = "${var.environment}-cellranger-pipeline"
    }

    type = "EC2"
  }

  service_role = aws_iam_role.aws_batch_service_role.arn
  depends_on = ["aws_iam_role_policy_attachment.aws_batch_service_role"]
}

# END COMPUTE ENVIRONMENT RESOURCES

resource "aws_batch_job_queue" "this" {
  name = "${var.environment}-cellranger-pipeline"
  state = "ENABLED"
  priority = 10
  compute_environments = [aws_batch_compute_environment.cellranger_pipeline.arn]
}

resource "aws_batch_job_definition" "main" {
  count = length(var.cellranger_bcl2fastq_version_pairs)

  name = format(
    "%s-%s-%s",
    "${var.environment}-cellranger-pipeline",
    "cellranger-${replace(element(var.cellranger_bcl2fastq_version_pairs, count.index)["cellranger_version"], ".", "_")}",
    "bcl2fastq-${replace(element(var.cellranger_bcl2fastq_version_pairs, count.index)["bcl2fastq_version"], ".", "_")}"
  )
  type = "container"

  retry_strategy {
    attempts = 1
  }

  timeout {
    attempt_duration_seconds = 129600
  }

  container_properties = jsonencode(
    {
      command = [
        "Ref::command",
        "Ref::configuration",
      ]
      environment = [
        {
          name = "DEBUG"
          value = "false"
        },
      ]
      image = format(
        "402084680610.dkr.ecr.us-east-1.amazonaws.com/cellranger-%s-bcl2fastq-%s",
        element(var.cellranger_bcl2fastq_version_pairs, count.index)["cellranger_version"],
        element(var.cellranger_bcl2fastq_version_pairs, count.index)["bcl2fastq_version"]
      )

      jobRoleArn = aws_iam_role.pipeline.arn
      memory = 126976
      mountPoints = [
        {
          containerPath = "/home/cellranger/scratch"
          sourceVolume = "scratch"
        },
      ]
      ulimits = []
      vcpus = 16
      volumes = [
        {
          host = {
            sourcePath = "/docker_scratch"
          }
          name = "scratch"
        },
      ]
    }
  )
}

resource "aws_ecr_repository" "main" {
  count = length(var.cellranger_bcl2fastq_version_pairs)

  name = format(
    "cellranger-%s-bcl2fastq-%s",
    element(var.cellranger_bcl2fastq_version_pairs, count.index)["cellranger_version"],
    element(var.cellranger_bcl2fastq_version_pairs, count.index)["bcl2fastq_version"]
  )
}
