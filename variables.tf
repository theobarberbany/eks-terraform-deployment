variable "reigon" {
        default = "us-west-2"
}

variable "vpc-name" {
        default = "eks-vpc"
}

variable "cluster-name" {
        default = "tf-k8s"
}

variable "nodegroup-file" {
        default = "amazon-eks-nodegroup.yaml"
}

variable "key-name" {
        default="tb15-ssh"
}

variable "nodegroup-name" {
        default = "worker-nodes" 
}

variable "node-instance-type" {
        default = "m4.xlarge"
}

variable "desired-node-size" {
        default = 1
}

variable "max-spot-bid" {
        default = 0.1
}

variable "amis" {
        type = "map"
        default = {
          "us-east-1" = "ami-dea4d5a1"
          "us-west-2" = "ami-73a6e20b"
        }
}
