#!/usr/bin/env bash
set -euo pipefail

# Load resource file
source ./vpcs.env

# Step 1: Create the peering request
PCX_ID=$(aws ec2 create-vpc-peering-connection \
  --region "$REDPANDA_REGION" \
  --vpc-id "$REDPANDA_VPC_ID" \
  --peer-vpc-id "$BENCHMARK_VPC_ID" \
  --peer-region "$BENCHMARK_REGION" \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text)

echo "Created peering request: $PCX_ID"

# Step 2: Accept the peering request from the benchmark side
aws ec2 accept-vpc-peering-connection \
  --region "$BENCHMARK_REGION" \
  --vpc-peering-connection-id "$PCX_ID"

echo "Accepted peering request"

# Function to add/replace routes
add_routes() {
  local region=$1
  local vpc_id=$2
  local dest_cidr=$3
  local pcx_id=$4

  for rt in $(aws ec2 describe-route-tables \
      --region "$region" \
      --filters "Name=vpc-id,Values=$vpc_id" \
      --query 'RouteTables[].RouteTableId' \
      --output text); do
    echo "Updating route table $rt in $region for $dest_cidr"
    aws ec2 create-route \
      --region "$region" \
      --route-table-id "$rt" \
      --destination-cidr-block "$dest_cidr" \
      --vpc-peering-connection-id "$pcx_id" \
    || \
    aws ec2 replace-route \
      --region "$region" \
      --route-table-id "$rt" \
      --destination-cidr-block "$dest_cidr" \
      --vpc-peering-connection-id "$pcx_id"
  done
}

# Step 3: Add routes in both directions
add_routes "$REDPANDA_REGION" "$REDPANDA_VPC_ID" "$BENCHMARK_CIDR" "$PCX_ID"
add_routes "$BENCHMARK_REGION" "$BENCHMARK_VPC_ID" "$REDPANDA_CIDR" "$PCX_ID"

echo "VPC peering setup complete: $PCX_ID"
