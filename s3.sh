#!/bin/bash

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null
then
    echo "AWS CLI could not be found. Please install it first."
    exit 1
fi

# List objects in the bucket and filter for 'metrics'
metrics_objects=$(aws s3 ls "s3://" --recursive | grep 'metrics')

# Check if any metrics objects are found
if [ -z "$metrics_objects" ]; then
    echo "No objects containing 'metrics' found."
    exit 1
fi

# Convert the list to an array
IFS=$'\n' read -rd '' -a object_array <<<"$metrics_objects"

# Display the list of metrics objects with numbers and extract just the keys
echo "List of objects containing 'metrics':"
object_keys=()
for i in "${!object_array[@]}"; do
    echo "$((i+1)). ${object_array[$i]}"
    object_keys+=("$(echo "${object_array[$i]}" | awk '{print $4}')")
done

# Prompt the user to enter a number
read -p "Enter the number of the object to view details: " number

# Validate the input
if ! [[ "$number" =~ ^[0-9]+$ ]] || [ "$number" -lt 1 ] || [ "$number" -gt "${#object_array[@]}" ]; then
    echo "Invalid input. Please enter a valid number between 1 and ${#object_array[@]}."
    exit 1
fi

# Get the selected object key based on the user's input
selected_key=${object_array[$((number-1))]}

# Remove date and time from selected key using sed
selected_key=$(echo "$selected_key" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} //')

# Display more details about the selected object
echo "Details of the selected object:"
echo "$selected_key"
aws s3 ls s3://$selected_key/
