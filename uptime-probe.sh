#!/usr/bin/env bash

# Define worker endpoints for the NodePort service
# OrbStack directly routes traffic to worker VM IPs
WORKER_1_IP="192.168.139.142"
WORKER_2_IP="192.168.139.169"
PORT="30080"

TARGET_URL="http://${WORKER_1_IP}:${PORT}"

TOTAL=0
SUCCESS=0
FAILED=0

echo "=========================================================="
echo " Starting Zero-Downtime Traffic Harness"
echo " Target: ${TARGET_URL}"
echo " Polling Interval: ~100ms"
echo " Press [CTRL+C] at any time to stop and view final report"
echo "=========================================================="
echo ""

# Handle graceful exit when user hits Ctrl+C
trap summary EXIT

function summary() {
    echo ""
    echo "==================== HARNESS SUMMARY ===================="
    echo "Total Requests Sent : ${TOTAL}"
    echo "Successful (200 OK) : ${SUCCESS}"
    echo "Failed Requests     : ${FAILED}"
    if [ ${TOTAL} -gt 0 ]; then
        AVAILABILITY=$(awk -v s="${SUCCESS}" -v t="${TOTAL}" 'BEGIN { printf "%.4f", (s/t)*100 }')
        echo "Calculated Uptime   : ${AVAILABILITY}%"
    fi
    echo "========================================================="
}

while true; do
    TOTAL=$((TOTAL + 1))
    TIMESTAMP=$(date +"%T.%3N")

    # Perform request: capture HTTP code and response time in seconds
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" --connect-timeout 1 -m 2 "${TARGET_URL}")
    HTTP_CODE=$(echo "${RESPONSE}" | awk '{print $1}')
    TIME_TOTAL=$(echo "${RESPONSE}" | awk '{print $2}')
    TIME_MS=$(awk -v t="${TIME_TOTAL}" 'BEGIN { printf "%.1f", t*1000 }')

    if [ "${HTTP_CODE}" == "200" ]; then
        SUCCESS=$((SUCCESS + 1))
        # Print a dot every 20 successful requests to avoid log flooding, or print live line
        if (( TOTAL % 10 == 0 )); then
            printf "\r[%s] Total: %d | OK: %d (100%%) | Last Latency: %sms " "${TIMESTAMP}" "${TOTAL}" "${SUCCESS}" "${TIME_MS}"
        fi
    else
        FAILED=$((FAILED + 1))
        printf "\n\033[0;31m[%s] ALERT: REQUEST FAILED! Status: %s | Latency: %sms\033[0m\n" "${TIMESTAMP}" "${HTTP_CODE}" "${TIME_MS}"
    fi

    # Small delay to keep continuous ~10 requests per second
    sleep 0.1
done
