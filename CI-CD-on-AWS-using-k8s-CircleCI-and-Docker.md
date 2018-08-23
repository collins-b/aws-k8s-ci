# CI/CD on AWS using Kubernetes, CircleCI and Docker


## Introduction

This article aims at providing a step by step guide of creating a CI/CD pipeline in AWS, using CircleCI, Kubernetes and Docker.

[CircleCI](https://circleci.com/) is a continuous integration tool, used to build, test and deploy applications easier and faster.

[Kubernetes(k8s)](https://kubernetes.io/), is an orchestration that is used in managing containerized workloads and services.

[Docker](https://www.docker.com/), is a tool that is used to create, deploy, and run applications by using containers.

*Note*: I'll that assume you have basic understanding of the above tools. I won't go into depth explaining what each tool is.

## Outline
1. AWS Setup
2. Kubernetes on AWS
3. Docker registry
4. CircleCI
5. Testing

### AWS Setup
If you don't have an AWS account, you can create one [here](https://aws.amazon.com/free/), and make use of the free tier services. I'm going to use a free tier account through out this tutorial.

Next, create an IAM user, who will be used for doing various administrative roles. We're going to create this user using the console. In the navigation pane, choose **Users**, then click on the **Add User** button. Select **Programmatic access** option, and remember to download the access keys for later reference.

Grant the user the following permissions:

```
AmazonEC2FullAccess
AmazonRoute53FullAccess
AmazonS3FullAccess
AmazonVPCFullAccess
```

Next, we are going to configure AWS using the CLI. So, install the CLI:

OSX - `brew install awscli`

Linux - `pip install awscli --upgrade --user`

Windows - Refer [here](https://docs.aws.amazon.com/cli/latest/userguide/awscli-install-windows.html)

If all went well in the above installlation steps, let us now configure the AWS CLI. You need to provide the Access Key, Secret Access Key and the AWS region that you want the K8s cluster to be installed. 

Run `aws configure`

Fill in the right credentials:

```
AWS Access Key ID [None]: AccessKeyValue
AWS Secret Access Key [None]: SecretAccessKeyValue
Default region name [None]: us-west-2
Default output format [None]:
```

To provision Kubernetes, we'll use kops, which expects an s3 bucket to persist its state. So, lets create the bucket:

```
aws s3api create-bucket --bucket awsk8s --create-bucket-configuration LocationConstraint=us-west-2

```
Then enable the versioning of the bucket, by running the following command:

``` 
aws s3api put-bucket-versioning --bucket awsk8s --versioning-configuration Status=Enabled
```

### Kubernetes on AWS

Let us now provision Kubernetes on AWS. First off, install kops:

OSX - `brew install kops`

Linux - 

```
curl -LO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64

```

`chmod +x kops-linux-amd64`

`sudo mv kops-linux-amd64 /usr/local/bin/kops`

Before creating let's set environment variables for the cluster.
Run the following in your terminal:

```
export KOPS_CLUSTER_NAME=k8s.aws.local
export KOPS_STATE_STORE=s3://awsk8s
export KOPS_NODE_COUNT=1
export KOPS_NODE_SIZE=t2.medium
export KOPS_NODE_ZONE=us-west-2a

```

Finally run:

```
kops create cluster --node-count=${KOPS_NODE_COUNT} --node-size=${KOPS_NODE_SIZE} --zones={KOPS_NODE_ZONE} --name=${KOPS_CLUSTER_NAME}
```
Note: If you are getting authorization errors, create an IAM group policy, with the following contents, and attach it to the IAM user group you created earlier.

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:AssociateIamInstanceProfile",
        "ec2:ReplaceIamInstanceProfileAssociation"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
```

Before actually creating the cluster, you can review the definition using the command below:

```
kops edit cluster --name ${KOPS_CLUSTER_NAME}
```

If everything looks good to you, create the cluster by running:

```
kops update cluster --name ${KOPS_CLUSTER_NAME} --yes
```
Finally validate the cluster:

`kops validate cluster` . Give it some time for the cluster to be up and running. You should get something similar to the output below, if the cluster is provisioned successfully:

```
Validating cluster cd.k8s.local

INSTANCE GROUPS
NAME			ROLE	MACHINETYPE	MIN	MAX	SUBNETS
master-us-west-2a	Master	m3.medium	1	1	us-west-2a
nodes			Node	t2.medium	1	1	us-west-2a

NODE STATUS
NAME						ROLE	READY
ip-172-20-36-229.us-west-2.compute.internal	master	True
ip-172-20-48-59.us-west-2.compute.internal	node	True

Your cluster cd.k8s.local is ready
```
Some people find it easy to use the K8s dashboard. So let's install the dashboard.

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
```
Confirm the dashboard pod is running:

```
kubectl get po -n kube-system
NAME                                                                  READY     STATUS    RESTARTS   AGE
kubernetes-dashboard-7d5dcdb6d9-fvm2c                                 1/1       Running   0          3h
```

To open the dashboard, on your terminal, type `kubectl proxy`. Then navigate to:

```
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
```

###  Docker Registry

I'll use [Docker hub](https://hub.docker.com/) as the registry, which will host the image we'll be using in this article. 
I pushed the image [here](https://hub.docker.com/r/wecs/demo/).

### CircleCI
