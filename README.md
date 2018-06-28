# eks-terraform-deployment
Deploy the [Getting Started](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html) EKS Cluster using terraform. 

1. Run `terraform init`
2. Modify variables.tf (key name must exist)
3. Run `terraform apply`
4. `export KUBECONFIG=`pwd`/kubeconfig`
5. Check everything's working `kubectl version`
6. `kubectl apply -f configmap.yaml`

Done! 
