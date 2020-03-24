#!/bin/bash
curr_dir="$(dirname "$0")"
source $curr_dir/settings.sh

docker run --name $CONTAINER_NAME -e POSTGRES_PASSWORD=mysecretpassword -p 5432:5432 -d mdillon/postgis