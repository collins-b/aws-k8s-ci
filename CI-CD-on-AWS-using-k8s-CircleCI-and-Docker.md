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
5. Kubernetes
6. Testing

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
As I'll be using CircleCI 2.0, the configuration file will be under a `.circleci` folder. You can check [here](https://circleci.com/docs/2.0/configuration-reference/) to read more about how to configure CircleCI.

The final configuration is shown below:

```
version: 2
jobs:
  build:
    docker:
      - image: wecs/aws-k8s:1.0.0
    working_directory: ~/workspace
    environment:
      DEPLOYMENT_NAME: demo
      CONTAINER_NAME: demo
      KOPS_STATE_STORE: cd.k8s.local

    steps:
      - checkout
      - setup_remote_docker
      - restore_cache:
          keys:
          - v1-dependencies-{{ checksum "package.json" }}
          - v1-dependencies-

      - run:
          name: Install node packages
          command: |
            yarn install
      
      - run:
          name: Start app
          command: |
            yarn start &
      - run:
          name: Run tests
          command: |
            yarn test

      - restore_cache:
          keys:
          - v1-dependencies-{{ checksum "package.json" }}
          - v1-dependencies-

      - save_cache:
          paths:
            - node_modules
          key: v1-dependencies-{{ checksum "package.json" }}
      
      - run:
          name: Build and Deploy
          command: |
            if [ "${CIRCLE_BRANCH}" == "master" ]; then
              sudo chmod +x ./deployment.sh && ./deployment.sh
            fi  
```
 Let me briefly explain the above file.
 
 `version: 2`- Specifies the CircleCI version that I'm using, which is 2.0.
 
 `jobs`- Specifies jobs that are intended to be run. For my case, I only have a single job, called `build`.
 
 `image: wecs/aws-k8s:1.0.0`. I created this image to be used as a high level environment. The image has Python, Kops, K8s and AWS CLI installed. The Dockerfile for this image is as shown below:
 
```
FROM circleci/node:7.10
RUN sudo apt-get update && sudo apt-get install gettext docker python-pip python-setuptools wget
RUN sudo apt-get install python-dev
RUN sudo wget -q https://storage.googleapis.com/kubernetes-release/release/v1.6.1/bin/linux/amd64/kubectl && sudo chmod +x kubectl && sudo mv kubectl /usr/bin
RUN sudo wget -q https://github.com/kubernetes/kops/releases/download/1.9.0/kops-linux-amd64 && sudo chmod +x kops-linux-amd64 && sudo mv kops-linux-amd64 /usr/bin/kops
RUN sudo pip install awscli

```
`environment`, specifies the necessary environment variables that I'm going to use.

The `steps` are self explanatory. 

Please note the `deployment.sh` script file. This hosts various commands for building and updating the deployment, automatically.

```
# !/bin/bash

set -e
docker build -t wecs/demo:$CIRCLE_SHA1 .

docker login -u="$HUB_USER" -p="$HUB_PASS" docker.io  && docker push wecs/demo:$CIRCLE_SHA1
export KOPS_STATE_STORE=s3://delan
echo $KOPS_STATE_STORE
NAME=cd.k8s.local
kops export kubecfg ${NAME}

export PASSWORD=`kops get secrets kube --type secret -oplaintext`

sudo kubectl --insecure-skip-tls-verify=true --username=$USERNAME --password=$PASSWORD --server https://api-cd-k8s-local-con0b0-610798260.us-west-2.elb.amazonaws.com set image deployment/${DEPLOYMENT_NAME} ${CONTAINER_NAME}=wecs/demo:$CIRCLE_SHA1

echo "✓ Successful..."
```
`$HUB_USER` and `$HUB_PASS` - This is docker-hub's username and password respectively, set as environment variables in CircleCi.
You can set using your account details.

`KOPS_STATE_STORE` - Provide the name of the S3 bucket you created while provisioning kops. I prefer setting it as an environment variable. I called mine `KOPS_STORE`.

```
CLUSTER_NAME=cd.k8s.local
kops export kubecfg ${CLUSTER_NAME}
```
This specify and sets a cluster. For this case, context is set to a cluster called `cd.k8s.local`. You can use the cluster you created during the provisioning of kops.

`$USERNAME` and `$PASSWORD` - Cluster username and password respectively. I have set the username as an environment variable.

`$MASTER_SERVER` - This is the address of master, which can be found by running, `kubectl cluster-info`. It's also good to set this as an environment variable.

**NOTE:**

Remember to set up AWS permissions, by providing `Access key ID` and `Secret access key`. You can get these two on the AWS console, or from the file you downloaded during creation of the IAM user. Otherwise you'll face permission issues. These two keys will be used for authenticating against AWS services during the builds.

### Kubernetes

As we are going to use Kubernetes as an orchestration tool, we'll have to define its artifacts. The file below is a basic YAML file defining the K8s deployment and service. This should be very familiar if you have some experience working with k8s:

```
apiVersion: v1
kind: Service
metadata:
  name: demo
  labels:
    app: demo
spec:
  type: LoadBalancer
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: demo
  selector:
    app: demo
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: demo
  labels:
    app: demo
spec:
  selector:
    matchLabels:
      app: demo
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - image: wecs/demo:latest
        name: demo
        ports:
        - containerPort: 3000
         name: demo
```