# !/bin/bash

set -e

docker build -t wecs/demo:$CIRCLE_SHA1 .

sudo  docker -- push wecs/demo:$CIRCLE_SHA1

sudo kubectl set image deployment/${DEPLOYMENT_NAME} ${CONTAINER_NAME}=wecs/demo:$CIRCLE_SHA1
