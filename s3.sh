#!/bin/bash

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI could not be found. Please install it first."
    exit 1
fi

# Function to list folders in an S3 bucket folder
list_objects_in_folder() {
    local folder_path="$1"
    aws s3 ls "$folder_path" | awk '{print NR ". " $NF}'
}

# List the buckets and filter for 'metrics'
metrics_objects=$(aws s3 ls "s3://" --recursive | grep 'metrics')

# Check if any metrics buckets are found
if [ -z "$metrics_objects" ]; then
    echo "No S3 buckets containing 'metrics' found."
    exit 1
fi

# Convert the list to an array
IFS=$'\n' read -rd '' -a object_array <<<"$metrics_objects"

# Display the list of metrics objects with numbers and extract just the keys
echo "List of S3 buckets containing 'metrics':"
object_keys=()
for i in "${!object_array[@]}"; do
    echo "$((i+1)). ${object_array[$i]}"
    object_keys+=("$(echo "${object_array[$i]}" | awk '{print $4}')")
done

# Prompt the user to enter a number
read -p "Enter the number next to the S3 bucket to view more details: " number

# Validate the input
if ! [[ "$number" =~ ^[0-9]+$ ]] || [ "$number" -lt 1 ] || [ "$number" -gt "${#object_array[@]}" ]; then
    echo "Invalid input. Please enter a valid number between 1 and ${#object_array[@]}."
    exit 1
fi

# Get the selected object key based on the user's input
selected_key=${object_array[$((number-1))]}

# Remove date and time from selected key using sed
selected_key=$(echo "$selected_key" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} //')

# List folders/objects inside the selected bucket
folder_contents=$(list_objects_in_folder "s3://$selected_key")

# Check if any folders/objects are found in the bucket
if [ -z "$folder_contents" ]; then
    echo "Nothing is found in S3 bucket: $selected_key"
    exit 0
fi

# Prompt the user to select an object from the folder
echo "Folders/Objects inside $selected_key"
echo "$folder_contents"

# Prompt the user to enter a number
read -p "Enter the number next to the folder to view details: " object_number

# Validate the input
if ! [[ "$object_number" =~ ^[0-9]+$ ]] || [ "$object_number" -lt 1 ] || [ "$object_number" -gt "$(echo "$folder_contents" | wc -l)" ]; then
    echo "Invalid input. Please enter a valid number between 1 and $(echo "$folder_contents" | wc -l)."
    exit 1
fi

# Get the selected object name based on the user's input
selected_object=$(echo "$folder_contents" | sed -n "${object_number}p" | awk '{print $NF}')

# List objects inside the selected folder
object_contents=$(aws s3 ls "s3://$selected_key/$selected_object")

# Check if any objects are found in the folder
if [ -z "$object_contents" ]; then
    echo "No objects found in the selected $selected_object."
    exit 0
fi

# Convert the list to an array
IFS=$'\n' read -rd '' -a object_array <<<"$object_contents"

# Display the list of objects with numbers
echo "Objects inside the selected $selected_object:"
for i in "${!object_array[@]}"; do
    echo "$((i+1)). ${object_array[$i]}"
done

# Prompt the user to enter the numbers of the objects to download (e.g., 1,2,3 or press Enter to download everything)
read -p "Enter the numbers of the objects to download (e.g., 1,2,3 or press Enter to download everything): " object_numbers

# Function to download a single object
download_object() {
    local object_path="$1"
    aws s3 cp "s3://$selected_key/$selected_object$object_path" temp_dir
}

# Validate and process the user's input
if [[ -z "$object_numbers" ]]; then
    # Download all objects
    aws s3 cp "s3://$selected_key/$selected_object" temp_dir --recursive
else
    # Split the input into an array of numbers
    IFS=',' read -ra numbers_array <<< "$object_numbers"
    echo "e: $object_numbers"
    # Validate each number and download the corresponding object
    for number in "${numbers_array[@]}"; do
        if ! [[ "$number" =~ ^[0-9]+$ ]] || [ "$number" -lt 1 ] || [ "$number" -gt "${#object_array[@]}" ]; then
            echo "Invalid number: $number. Skipping."
        else
            object_name=$(echo "${object_array[$((number-1))]}" | awk '{print $NF}')
            download_object "$object_name"
        fi
    done
fi
zip -r temp.zip temp_dir
echo "Download complete."
