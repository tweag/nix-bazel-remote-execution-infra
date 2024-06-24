## Deployment

### Tools

The following CLI tools are needed for the deployment. Available also through `flake.nix`,
run `nix develop` to enter an environment with these tools installed.

- [Terraform](https://developer.hashicorp.com/terraform/downloads?product_intent=terraform)
- [aws-cli](https://aws.amazon.com/cli/)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helmfile](https://github.com/helmfile/helmfile)
- [Helm](https://helm.sh/docs/intro/install/)

## Steps

The guide assumes that the user is in a shell session at root of the repository
at every step.

### Create an S3 bucket for Terraform state

Manually create an S3 bucket on AWS in the appropriate region to store the
Terraform state. In this example we will name it `my-terraform-state`.

### Create your custom configuration

Create the following configuration files under `buildbarn/terraform`: A
`backend.tf` file with your terraform backend configuration and place the
module configuration into the `variables.tfvars` file. E.g.

```bash
$ cd buildbarn/terraform

$ cat backend.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "buildbarn/terraform.tfstate"
    region = "<AWS_REGION>"
  }
}

$ cat variables.tfvars
aws_account_id = "<AWS_ACCOUNT_ID>"

region = "<AWS_REGION>

tags = {
 terraform = "true"
 env       = "buildbarn-nix"
 project   = "bazel-nix"
}

prefix = "my-buildbarn-env"
ami    = "ami-01dd271720c1ba44f"

domain_name = "example.org"
zone_id     = "<YOUR_ZONE_ID>"

public_ssh_key = "your-public-ssh-key"
```

Review the `variables.tf` file for all the available configuration options that you can override.

### Create the AWS resources through terraform

```bash
# Ensure the AWS credentials are loaded into the environment.
cd buildbarn/terraform
terraform init
terraform plan -var-file=variables.tfvars
terraform apply -var-file=variables.tfvars
```

This will create the following resources:
- An EC2 instance that will function as the Nix server.
- An empty Kubernetes cluster.
- A TLS certificate that will be used to expose the buildbarn services through a Kubernetes ingress.
- IAM roles necessary for the Kubernetes services.

###  Use Ansible to provision the nix server

We only need to setup the Nix server to make it export `/nix/store` as an NFS share. Update the
placeholders with your own values.

First we need to create an inventory file to point ansible to our server:

```bash
$ cat ansible/hosts
[nix_server]
<public-ip-of-nix-server> # Taken from the terraform output.
```

And then we can apply the playbook:

```bash
cd ansible
ansible-playbook -i hosts --extra-vars "ansible_user=ubuntu vpc_cidr=<VPC_CIDR>" --private-key <SSH_PRIVATE_KEY_PATH> nix-server.yml
```

### Access the Kubernetes cluster

```bash
$ aws eks list-clusters --region <AWS_REGION>
{
    "clusters": [
        "buildbarn-cluster"
    ]
}

$ aws eks update-kubeconfig --name buildbarn-cluster --alias buildbarn-cluster --region <AWS_REGION>
```

### Provision the cluster with the Helm charts

Create a directory named `local` under `buildbarn/kubernetes` to hold the specific configuration, for
the `cluster-autoscaler`, `external-dns` and `ingress-nginx` Helm charts. Below are the templates
that can you use and update with your actual values accordingly.

For the deployment of BuildBarn components, a Helm chart has been developed based on the [upstream
manifests][buildbarn_manifests] provided by the project. This Helm chart makes it easier to
parameterize the configuration files.

```bash
$ cd buildbarn/terraform

$ cat local/cluster-autoscaler.yaml

awsRegion: <AWS_REGION>

rbac:
  create: true
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: <CLUSTER_AUTOSCALER_IAM_ROLE> # Available as a terraform output
    create: true
    name: cluster-autoscaler
```

```bash
$ cat local/external-dns.yaml

aws:
  region: <AWS_REGION>

serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: <EXTERNAL_DNS_IAM_ROLE> # Available as a terraform output

txtOwnerId: <txtownerid>
txtPrefix: extdns-
domainFilters:
  - <YOUR_DOMAIN>
zoneIdFilters:
  - <YOUR_ROUTE53_ZONE_ID>
```

```bash
$ cat local/ingress-nginx.yaml

controller:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: <AWS_ACM_CERT_ARN> # Available as a terraform output
```

```bash
$ cat local/buildbarn.yaml

browser:
  host: bb-browser.example.org

scheduler:
  host: bb-scheduler.example.org

nix:
  ip: 10.0.0.1 # Update with actual private IP of the nix server from the terraform output.
  path: /nix/store
```

The following command will install the necessary system services with the Helm package manager.

```bash
cd buildbarn/kubernetes
helmfile --concurrency=1 apply -i
```

### Validate that the pods and services are working

List all pods on the `buildbarn` namespace and check for any failures.

```bash
kubectl get pods -n buildbarn
NAME                                    READY   STATUS    RESTARTS   AGE
browser-6b696cb8bd-d2qzm                1/1     Running   0          2d23h
browser-6b696cb8bd-tt75l                1/1     Running   0          2d23h
browser-6b696cb8bd-x527q                1/1     Running   0          2d23h
frontend-5c895bdfd7-g99bg               1/1     Running   0          2d22h
frontend-5c895bdfd7-h4wz5               1/1     Running   0          2d22h
frontend-5c895bdfd7-k5fms               1/1     Running   0          2d22h
scheduler-ubuntu22-04-699d9c658-fnxtn   1/1     Running   0          2d23h
storage-0                               1/1     Running   0          2d23h
storage-1                               1/1     Running   0          2d23h
worker-ubuntu22-04-8d6c5d6ff-p6729      2/2     Running   0          2d23h
```

List all the ingress endpoints on the `buildbarn` namespace and ensure that they are accessible.

```bash
$ kubectl get ingress -n buildbarn
NAME        CLASS   HOSTS                       ADDRESS                                                                   PORTS   AGE
browser     nginx   bb-browser.bazelnix.net     af06a8018c91145e89999e0fb55192fe-1992479129.eu-west-1.elb.amazonaws.com   80      2d23h
scheduler   nginx   bb-scheduler.bazelnix.net   af06a8018c91145e89999e0fb55192fe-1992479129.eu-west-1.elb.amazonaws.com   80      2d23h
```

List the service endpoint for the GRPC API end ensure it's accessible.

```bash
$ kubectl get service -n buildbarn
NAME        TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)                      AGE
browser     ClusterIP      172.20.240.175   <none>                                                                    7984/TCP                     2d23h
frontend    LoadBalancer   172.20.142.109   add0b523b70aa45c183e59e674383777-1490091402.eu-west-1.elb.amazonaws.com   8980:31809/TCP               2d23h
scheduler   ClusterIP      172.20.51.144    <none>                                                                    8982/TCP,8983/TCP,7982/TCP   2d23h
storage     ClusterIP      None             <none>                                                                    8981/TCP                     2d23h

$ nc -v add0b523b70aa45c183e59e674383777-1490091402.eu-west-1.elb.amazonaws.com 8980
Ncat: Version 7.93 ( https://nmap.org/ncat )
Ncat: Connected to 34.241.215.173:8980.
```

[buildbarn_manifests]: https://github.com/buildbarn/bb-deployments/tree/1f221b54c99b57e3953865a75069a84245d96b56/kubernetes
