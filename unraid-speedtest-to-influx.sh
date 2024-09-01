#!/usr/bin/bash

result=$(/root/speedtest/speedtest --format=json 2>/dev/null)

# Parse JSON and sanitize the values
timestamp=$(jq -r '.timestamp' <<< "$result")
ping_jitter=$(jq -r '.ping.jitter' <<< "$result")
ping_latency=$(jq -r '.ping.latency' <<< "$result")
ping_ms=$(awk "BEGIN {printf \"%.1f\", $ping_latency}")

# Convert download_bandwidth from bytes per second to megabits per second with two decimal places
download_bandwidth=$(jq -r '.download.bandwidth' <<< "$result")
download_mbps=$(awk "BEGIN {printf \"%.2f\", $download_bandwidth * 8 / 1000000}")

# Convert upload_bandwidth from bytes per second to megabits per second with two decimal places
upload_bandwidth=$(jq -r '.upload.bandwidth' <<< "$result")
upload_mbps=$(awk "BEGIN {printf \"%.2f\", $upload_bandwidth * 8 / 1000000}")

packet_loss=$(jq -r '.packetLoss' <<< "$result")
client_isp=$(echo $result | jq -r '.isp' | sed 's/ /\\ /g' | sed 's/,/\\,/g')
internal_ip=$(jq -r '.interface.internalIp' <<< "$result")
external_ip=$(jq -r '.interface.externalIp' <<< "$result")

# Server Information
server_id=$(echo $result | jq -r '.server.id')
server_host=$(echo $result | jq -r '.server.host' | sed 's/ /\\ /g' | sed 's/,/\\,/g')
server_port=$(jq -r '.server.port' <<< "$result")
server_name=$(echo $result | jq -r '.server.name' | sed 's/ /\\ /g' | sed 's/,/\\,/g')
server_location=$(echo $result | jq -r '.server.location' | sed 's/ /\\ /g' | sed 's/,/\\,/g')
server_country=$(echo $result | jq -r '.server.country' | sed 's/ /\\ /g' | sed 's/,/\\,/g')
server_ip=$(jq -r '.server.ip' <<< "$result")

# Convert the timestamp to nanoseconds (InfluxDB requires nanosecond precision)
timestamp_ns=$(date -d "$timestamp" +"%s%N")

# Create the InfluxDB line protocol string without `result_id` and `result_url`
data="speedtest,host=$internal_ip,client_isp=$client_isp,server_id=$server_id,server_host=$server_host,server_port=$server_port,server_name=$server_name,server_location=$server_location,server_country=$server_country,server_ip=$server_ip ping_jitter=$ping_jitter,ping_ms=$ping_ms,download_mbps=$download_mbps,upload_mbps=$upload_mbps,packet_loss=$packet_loss $timestamp_ns"

# Send data to InfluxDB
curl -i -XPOST "http://192.168.1.200:8086/write?db=speedtest" --data-binary "$data"
