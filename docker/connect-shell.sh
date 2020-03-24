#!/bin/bash
curr_dir="$(dirname "$0")"
source $curr_dir/settings.sh
if [ $(docker ps | grep $CONTAINER_NAME | wc -l) -gt 0 ]
then 
    docker exec -ti $CONTAINER_NAME sh
else
    docker run --name $CONTAINER_NAME -e POSTGRES_PASSWORD=pass -d -p 5432:5432 $IMAGE_NAME
fi
