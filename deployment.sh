# !/bin/bash

set -e
docker build -t wecs/demo:$CIRCLE_SHA1 .

docker login -u="$HUB_USER" -p="$HUB_PASS" docker.io  && docker push wecs/demo:$CIRCLE_SHA1
export KOPS_STATE_STORE=s3://delan
echo $KOPS_STATE_STORE
NAME=cd.k8s.local
kops export kubecfg ${NAME}
# kubectl version

echo "✓"

sudo kubectl --server https://api-cd-k8s-local-con0b0-610798260.us-west-2.elb.amazonaws.com set image deployment/${DEPLOYMENT_NAME} ${CONTAINER_NAME}=wecs/demo:$CIRCLE_SHA1
