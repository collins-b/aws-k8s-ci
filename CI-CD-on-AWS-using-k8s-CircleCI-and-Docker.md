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

Next, create an IAM user, who will be used for doing various administrative roles. We're going to create this user using the console. In the navigation pane, choose **Users**, then click on the **Add User** button.