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

THIS_DIR = Path(__file__).parent
USER_DATA_SH_TEMPLATE_FPATH = (THIS_DIR / "./user-data.template.sh").resolve()


class ZenMLControlPlaneStack(Stack):
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
        super().__init__(scope, construct_id, **kwargs)

        _vpc = ec2.Vpc.from_lookup(scope=self, id="DefaultVpc", is_default=True)

        # set up security group to allow inbound traffic on port 25565 for anyone
        _sg = ec2.SecurityGroup(
            scope=self,
            id="ZenMLServerSecurityGroup",
            vpc=_vpc,
            allow_all_outbound=True,
        )
        _sg.add_ingress_rule(
            peer=ec2.Peer.any_ipv4(),
            connection=ec2.Port.tcp(8080),
            description="Allow inbound traffic on port 8080",
        )
        _sg.add_ingress_rule(
            peer=ec2.Peer.any_ipv4(),
            connection=ec2.Port.tcp(22),
            description="Allow inbound traffic on port 22",
        )
        # allow all outbound traffic
        _sg.add_egress_rule(
            peer=ec2.Peer.any_ipv4(),
            connection=ec2.Port.all_traffic(),
            description="Allow all outbound traffic",
        )

        # create iam role for ec2 instance using AmazonSSMManagedInstanceCore
        _iam_role = iam.Role(
            scope=self,
            id="ZenMLServerIamRole",
            assumed_by=iam.ServicePrincipal("ec2.amazonaws.com"),
        )
        _iam_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMManagedInstanceCore")
        )

        # fill in user data script
        _user_data_script = ec2.UserData.custom(
            render_user_data_script(
                aws_account_id=self.account,
                aws_region=self.region,
            )
        )

        _ec2 = ec2.Instance(
            scope=self,
            id="ZenMLServerInstance",
            vpc=_vpc,
            instance_type=ec2.InstanceType(ec2_instance_type),
            machine_image=ec2.MachineImage.latest_amazon_linux2(),
            user_data=_user_data_script,
            user_data_causes_replacement=True,
            role=_iam_role,
            security_group=_sg,
            key_name=ssh_key_pair_name,
        )

        if custom_top_level_domain_name:
            a_record: route53.ARecord = add_custom_subdomain_to_ec2_ip(
                scope=self,
                instance=_ec2,
                custom_top_level_domain_name=custom_top_level_domain_name,
            )

            cdk.CfnOutput(
                scope=self,
                id="ZenMLServerDomainName",
                value=a_record.domain_name,
                description="The domain name of the ZenML server",
            )

        # add stack output for ip address of the ec2 instance
        cdk.CfnOutput(
            scope=self,
            id="ZenMLServerIp",
            value=_ec2.instance_public_ip,
            description="The public IP address of the ZenML server",
        )

        add_alarms_to_stack(scope=self, ec2_instance_id=_ec2.instance_id)


def grant_ecr_pull_access(ecr_repo_arn: str, role: iam.Role, repo_construct_id: str):
    """Grant the given role access to pull docker images from the given ECR repo."""
    ecr_repo = ecr.Repository.from_repository_arn(scope=role, id=repo_construct_id, repository_arn=ecr_repo_arn)
    ecr_repo.grant_pull(role)


def render_user_data_script(
    aws_account_id: str,
    aws_region: str,
) -> str:
    """Render the user data script for the EC2 instance.

    :param minecraft_semantic_version: The semantic version of the ZenML server to install.
    :param backup_service_docker_image_uri: The URI of the Docker image in ECR for the backup service.
    """
    return Template(USER_DATA_SH_TEMPLATE_FPATH.read_text()).substitute(
        {
            "AWS_ACCOUNT_ID": aws_account_id,
            "AWS_REGION": aws_region,
        }
    )


def grant_s3_read_write_access(bucket_name: str, role: iam.Role, bucket_construct_id: str):
    """Grant the given role read/write access to the given S3 bucket."""
    bucket = s3.Bucket.from_bucket_name(scope=role, id=bucket_construct_id, bucket_name=bucket_name)
    bucket.grant_read_write(role)


def add_alarms_to_stack(scope: Construct, ec2_instance_id: str) -> None:
    """Add alarms to the stack.

    Parameters
    ----------
    scope : Construct
        The scope of the stack.
    ec2_instance_id : str
        The ID of the EC2 instance to monitor.

    Returns
    -------
    None
    """
    cloudwatch.Alarm(
        scope=scope,
        id="ZenMLServerCpuAlarm",
        metric=cloudwatch.Metric(
            namespace="AWS/EC2",
            metric_name="CPUUtilization",
            dimensions_map={"InstanceId": ec2_instance_id},
            statistic="Average",
            period=cdk.Duration.minutes(1),
        ),
        comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
        threshold=80,
        evaluation_periods=1,
        treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
        alarm_description="Alarm if CPU usage is greater than 80% for 1 minute",
    )

    cloudwatch.Alarm(
        scope=scope,
        id="ZenMLServerMemoryAlarm",
        metric=cloudwatch.Metric(
            namespace="System/Linux",
            metric_name="MemoryUtilization",
            dimensions_map={"InstanceId": ec2_instance_id},
            statistic="Average",
            period=cdk.Duration.minutes(1),
        ),
        comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
        threshold=80,
        evaluation_periods=1,
        treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
        alarm_description="Alarm if memory usage is greater than 80% for 1 minute",
    )

    cloudwatch.Alarm(
        scope=scope,
        id="ZenMLServerDiskAlarm",
        metric=cloudwatch.Metric(
            namespace="System/Linux",
            metric_name="DiskSpaceUtilization",
            dimensions_map={"InstanceId": ec2_instance_id},
            statistic="Average",
            period=cdk.Duration.minutes(1),
        ),
        comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
        threshold=80,
        evaluation_periods=1,
        treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
        alarm_description="Alarm if disk usage is greater than 80% for 1 minute",
    )

    cloudwatch.Alarm(
        scope=scope,
        id="ZenMLServerNetworkAlarm",
        metric=cloudwatch.Metric(
            namespace="System/Linux",
            metric_name="NetworkIn",
            dimensions_map={"InstanceId": ec2_instance_id},
            statistic="Average",
            period=cdk.Duration.minutes(1),
        ),
        comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
        threshold=80,
        evaluation_periods=1,
        treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
        alarm_description="Alarm if network usage is greater than 80% for 1 minute",
    )

    cloudwatch.Alarm(
        scope=scope,
        id="ZenMLServerOpenConnectionsAlarm",
        metric=cloudwatch.Metric(
            namespace="System/Linux",
            metric_name="NetworkIn",
            dimensions_map={"InstanceId": ec2_instance_id},
            statistic="Average",
            period=cdk.Duration.minutes(1),
        ),
        comparison_operator=cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
        threshold=80,
        evaluation_periods=1,
        treat_missing_data=cloudwatch.TreatMissingData.NOT_BREACHING,
        alarm_description="Alarm if number of open connections is greater than 80% for 1 minute",
    )


def add_custom_subdomain_to_ec2_ip(
    scope: Construct,
    instance: ec2.Instance,
    custom_top_level_domain_name: str,
) -> route53.ARecord:
    hosted_zone = route53.HostedZone.from_lookup(
        scope=scope,
        id=f"{scope.node.id}HostedZone",
        domain_name=custom_top_level_domain_name,
    )

    return route53.ARecord(
        scope=scope,
        id=f"{scope.node.id}ARecord",
        zone=hosted_zone,
        target=route53.RecordTarget.from_ip_addresses(instance.instance_public_ip),
        record_name=f"server.minecraft-paas.{hosted_zone.zone_name}",
    )

if __name__ == "__main__":
    print(
        render_user_data_script(
            minecraft_semantic_version="1.16.5",
            backup_service_docker_image_uri="some-image-uri",
            minecraft_server_backups_bucket_name="some-bucket-name",
            restore_from_most_recent_backup=True,
            aws_account_id="some-aws-account-id",
            aws_region="some-aws-region",
        )
    )