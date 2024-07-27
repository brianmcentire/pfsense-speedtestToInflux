#!/bin/sh

# Function to log errors
log_error() {
    echo "$(date) - $1" >> /var/log/speedtest_error.log
}

# Retry mechanism
max_retries=3
retry_count=0
success=false
retry_interval=203  # 3 minutes and 23 seconds

while [ $retry_count -lt $max_retries ]; do
    # Run speedtest and capture the JSON output
    result=$(/usr/local/bin/speedtest-cli --json 2>/dev/null)

    if [ $? -eq 0 ]; then
        success=true
        break
    else
        log_error "Speedtest failed on attempt $((retry_count + 1))."
        retry_count=$((retry_count + 1))
        sleep $retry_interval  # Wait for 3 minutes and 23 seconds before retrying
    fi
done

# Set status based on success or failure
if [ "$success" = false ]; then
    log_error "Speedtest failed after $max_retries attempts."
    status="fail"
else
    status="success"
fi

# Extract fields from the JSON result if successful
if [ "$success" = true ]; then
    download=$(echo $result | jq .download)
    upload=$(echo $result | jq .upload)
    ping=$(echo $result | jq .ping)
    server_id=$(echo $result | jq .server.id | tr -d '"')
    server_name=$(echo $result | jq .server.name | tr -d '"' | sed 's/ /\\ /g' | sed 's/,/\\,/g')
    server_country=$(echo $result | jq .server.country | tr -d '"' | sed 's/ /\\ /g' | sed 's/,/\\,/g')
    server_sponsor=$(echo $result | jq .server.sponsor | tr -d '"' | sed 's/ /\\ /g' | sed 's/,/\\,/g')
    client_ip=$(echo $result | jq .client.ip | tr -d '"')
    client_isp=$(echo $result | jq .client.isp | tr -d '"' | sed 's/ /\\ /g' | sed 's/,/\\,/g')
    client_country=$(echo $result | jq .client.country | tr -d '"')

    # Convert download and upload speeds to Mbps with 2 decimal places
    download_mbps=$(echo "scale=2; $download / 1000000" | bc)
    upload_mbps=$(echo "scale=2; $upload / 1000000" | bc)

    # Format ping to 1 decimal place
    ping_formatted=$(printf "%.1f" $ping)

    # Format data for InfluxDB without timestamp
    data="speedtest,server_id=$server_id,server_name=$server_name,server_country=$server_country,server_sponsor=$server_sponsor,client_ip=$client_ip,client_isp=$client_isp,client_country=$client_country,status=$status download_mbps=$download_mbps,upload_mbps=$upload_mbps,ping_ms=$ping_formatted"
    
    # Debugging: print data to be sent to InfluxDB
    ##echo "$data"
else
    # Format data for InfluxDB without timestamp
    data="speedtest,status=$status download_mbps=0.00,upload_mbps=0.00,ping_ms=0.0"
    
    # Debugging: print data to be sent to InfluxDB
    ##echo "$data"
fi

# Function to handle curl response
handle_curl_response() {
    local response=$1
    local url=$2

    if echo "$response" | grep -q "HTTP/1.1 4\|HTTP/1.1 5"; then
        log_error "Failed to send data to InfluxDB at $url. Response: $response"
    fi
}

# Send data to the first InfluxDB host and log errors if curl fails
curl_response=$(curl -i -XPOST 'http://YOUR_INFLUXDB_HOST:INFLUXDB_PORT/write?db=speedtest' --data-binary "$data" 2>&1)
curl_status=$?
if [ $curl_status -ne 0 ]; then
    log_error "Failed to send data to InfluxDB at YOUR_INFLUXDB_HOST. Response: $curl_response"
else
    handle_curl_response "$curl_response" "YOUR_INFLUXDB_HOST"
fi

# Send data to the second InfluxDB host and log errors if curl fails, comment this section out if no redundancy
curl_response=$(curl -i -XPOST 'http://YOUR_INFLUXDB_HOST2:INFLUXDB_PORT/write?db=speedtest' --data-binary "$data" 2>&1)
curl_status=$?
if [ $curl_status -ne 0 ]; then
    log_error "Failed to send data to InfluxDB at YOUR_INFLUXDB_HOST2. Response: $curl_response"
else
    handle_curl_response "$curl_response" "YOUR_INFLUXDB_HOST2"
fi
