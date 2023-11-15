#!/bin/bash

CURRENT_USER_NAME=$(whoami)
CURRENT_USER_ID=$(id -u)
echo "User name: $CURRENT_USER_NAME"
echo "User   id: $CURRENT_USER_ID"

TORRUST_INDEX_GUI_USER_UID=$CURRENT_USER_ID
USER_ID=$CURRENT_USER_ID
TORRUST_TRACKER_USER_UID=$CURRENT_USER_ID
export TORRUST_INDEX_GUI_USER_UID
export USER_ID
export TORRUST_TRACKER_USER_UID

wait_for_container_to_be_healthy() {
    local container_name="$1"
    local max_retries="$2"
    local retry_interval="$3"
    local retry_count=0

    while [ $retry_count -lt "$max_retries" ]; do
        container_health="$(docker inspect --format='{{json .State.Health}}' "$container_name")"
        if [ "$container_health" != "{}" ]; then
            container_status="$(echo "$container_health" | jq -r '.Status')"
            if [ "$container_status" == "healthy" ]; then
                echo "Container $container_name is healthy"
                return 0
            fi
        fi

        retry_count=$((retry_count + 1))
        echo "Waiting for container $container_name to become healthy (attempt $retry_count of $max_retries)..."
        sleep "$retry_interval"
    done

    echo "Timeout reached, container $container_name is not healthy"
    return 1
}

./docker/bin/e2e-env-install.sh || exit 1

# Start E2E testing environment
./docker/bin/e2e-env-up.sh || exit 1

wait_for_container_to_be_healthy torrust-mysql-1 10 3
# todo: implement healthchecks for tracker and backend and wait until they are healthy
#wait_for_container torrust-tracker-1 10 3
#wait_for_container torrust-idx-back-1 10 3
#wait_for_container torrust-idx-front-1 10 3
sleep 20s

# Just to make sure that everything is up and running
docker ps

# Run E2E tests with shared app instance
npm run cypress:run || exit 1

# Stop E2E testing environment
./docker/bin/e2e-env-down.sh
