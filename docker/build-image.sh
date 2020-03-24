#!/bin/bash
curr_dir="$(dirname "$0")"
source $curr_dir/settings.sh

docker build -t $IMAGE_NAME .