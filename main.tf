resource "aws_iam_role" "eks_serviceworker" {
  name = "eks-worker"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}



resource "aws_iam_role_policy_attachment" "attach-eks-cluster-policy" {
  role = "${aws_iam_role.eks_serviceworker.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "attach-eks-service-policy" {
  role = "${aws_iam_role.eks_serviceworker.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_cloudformation_stack" "eks-vpc" {
  name = "${var.vpc-name}"
  template_url = "https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/amazon-eks-vpc-sample.yaml"
}

resource "aws_eks_cluster" "master-cluster" {
  name = "${var.cluster-name}"
  role_arn = "${aws_iam_role.eks_serviceworker.arn}"
  
  vpc_config {
    security_group_ids = ["${aws_cloudformation_stack.eks-vpc.outputs["SecurityGroups"]}"]
    subnet_ids = ["${split(",",aws_cloudformation_stack.eks-vpc.outputs["SubnetIds"])}"]
  }

  depends_on = [
     "aws_iam_role_policy_attachment.attach-eks-cluster-policy",
     "aws_iam_role_policy_attachment.attach-eks-service-policy",
  ]
}


locals {
  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.master-cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.master-cluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: heptio-authenticator-aws
      args:
        - "token"
        - "-i"
        - "${var.cluster-name}"
KUBECONFIG
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}

resource "local_file" "kubeconfig" {
  content     = "${local.kubeconfig}"
  filename = "${path.cwd}/kubeconfig"
}

resource "aws_cloudformation_stack" "eks-nodegroup" {
  name = "${format("%s-%s", var.cluster-name,var.nodegroup-name)}"
  capabilities = ["CAPABILITY_IAM"]
  parameters {
    KeyName = "${var.key-name}",
    NodeImageId = "${var.amis[var.reigon]}",
    ClusterName = "${var.cluster-name}",
    VpcId = "${aws_cloudformation_stack.eks-vpc.outputs["VpcId"]}",
    Subnets = "${aws_cloudformation_stack.eks-vpc.outputs["SubnetIds"]}",
    NodeGroupName = "spot-worker",
    DesiredNodeSize = "${var.desired-node-size}",
    NodeInstanceType = "${var.node-instance-type}",
    MaxSpotBid = "${var.max-spot-bid}",
    ClusterControlPlaneSecurityGroup = "${aws_cloudformation_stack.eks-vpc.outputs["SecurityGroups"]}",
    
  }
  template_body = "${file(var.nodegroup-file)}"
  depends_on = ["aws_eks_cluster.master-cluster"]
}

locals {
  config-map-aws-auth = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_cloudformation_stack.eks-nodegroup.outputs["NodeInstanceRole"]}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}

output "config-map-aws-auth" {
  value = "${local.config-map-aws-auth}"
}

resource "local_file" "configmap-aws-auth" {
  content = "${local.config-map-aws-auth}"
  filename = "${path.cwd}/configmap.yaml"
}
