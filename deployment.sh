# !/bin/bash

set -e

sudo service docker start

docker build -t wecs/demo:$CIRCLE_SHA1 .

sudo  docker -- push wecs/demo:$CIRCLE_SHA1

sudo kubectl set image deployment/${DEPLOYMENT_NAME} ${CONTAINER_NAME}=wecs/demo:$CIRCLE_SHA1
