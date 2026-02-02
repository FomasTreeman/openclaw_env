from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, Lambda
from diagrams.aws.network import CloudFront, VPC, Route53
from diagrams.aws.security import WAF, SecretsManager, IAMRole, Inspector, Detective
from diagrams.aws.management import SystemsManager, Cloudwatch
from diagrams.aws.integration import Eventbridge
from diagrams.onprem.client import User
from diagrams.onprem.container import Docker
from diagrams.programming.language import Python

# Note: Using Detective icon as placeholder for GuardDuty
# (GuardDuty may not be available in all diagrams versions)

graph_attr = {
    "fontsize": "16",
    "bgcolor": "white",
    "splines": "ortho"
}

with Diagram("OpenClaw Security Architecture", show=False, direction="TB", graph_attr=graph_attr):

    user = User("User")

    with Cluster("AWS Cloud"):
        
        # Ingress Layer
        with Cluster("Ingress Layer"):
            waf = WAF("WAF\nRate Limit + Rules")
            cloudfront = CloudFront("CloudFront\nHTTPS Only")

        with Cluster("VPC"):
            
            # Egress Control
            dns_fw = Route53("DNS Firewall\nAllowlist Only")
            
            with Cluster("Private Subnet"):
                # Core Application
                ec2 = EC2("EC2\nOpenClaw Gateway")
                docker = Docker("Docker\nAgent Sandboxes")
                
                # Identity & Secrets
                iam = IAMRole("IAM Role\nLeast Privilege")
                secrets = SecretsManager("Secrets Mgr\nAPI Keys")

        # Monitoring Layer
        with Cluster("Security Monitoring"):
            inspector = Inspector("Inspector\nVuln Scanning")
            detective = Detective("GuardDuty\nThreat Detection")
            cloudwatch = Cloudwatch("CloudWatch\nAlarms + Logs")

        # Automation Layer
        with Cluster("Cloud Janitor"):
            ssm = SystemsManager("SSM\nPatch Manager")
            eventbridge = Eventbridge("EventBridge\nScheduler")
            janitor_lambda = Lambda("Lambda\nCleanup Tasks")

        # External APIs
        external = Python("External APIs\nOpenAI / Anthropic")

    # --- Data Flows ---

    # Ingress
    user >> Edge(label="HTTPS") >> waf >> cloudfront >> ec2

    # Application
    ec2 >> Edge(label="spawn") >> docker
    ec2 >> Edge(style="dotted") >> iam
    ec2 << Edge(color="darkgreen") << secrets

    # Egress
    docker >> dns_fw >> external

    # Monitoring
    ec2 >> Edge(style="dashed", color="gray") >> inspector
    ec2 >> Edge(style="dashed", color="gray") >> detective
    ec2 >> Edge(style="dashed", color="gray") >> cloudwatch

    # Automation
    eventbridge >> janitor_lambda
    ssm >> ec2
