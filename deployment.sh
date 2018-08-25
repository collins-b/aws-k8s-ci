# !/bin/bash

set -e
aws --version
docker build -t wecs/demo:$CIRCLE_SHA1 .

docker login -u="$HUB_USER" -p="$HUB_PASS" docker.io  && docker push wecs/demo:$CIRCLE_SHA1

sudo kubectl set image deployment/${DEPLOYMENT_NAME} ${CONTAINER_NAME}=wecs/demo:$CIRCLE_SHA1
