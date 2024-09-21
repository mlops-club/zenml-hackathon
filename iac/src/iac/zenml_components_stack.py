from pathlib import Path
from string import Template
from typing import Optional

import aws_cdk as cdk
from aws_cdk import Stack
from aws_cdk import aws_cloudwatch as cloudwatch
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_ecr as ecr
from aws_cdk import aws_iam as iam
from aws_cdk import aws_route53 as route53
from aws_cdk import aws_s3 as s3
from constructs import Construct

class ZenMLComponents(Stack):
    """Stack responsible for creating the running minecraft server on AWS.

    :param scope: The scope of the stack.
    :param construct_id: The ID of the stack.
    :param minecraft_server_version: The semantic version of the ZenML server to install.
    :param backup_service_ecr_repo_arn: The ARN of the ECR repository for the backup service.
    :param backup_service_docker_image_uri: The URI of the Docker image in ECR for the backup service.
    :param minecraft_server_backups_bucket_name: The name of the S3 bucket to store backups in.
    :param ssh_key_pair_name: The name of the SSH key pair to use for the EC2 instance.
    """

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        ssh_key_pair_name: Optional[str] = None,
        custom_top_level_domain_name: Optional[str] = None,
        ec2_instance_type: Optional[str] = "t3.medium",
        **kwargs,
    ) -> None:
        
        ...