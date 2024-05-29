#!/bin/bash

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null
then
    echo "AWS CLI could not be found. Please install it first."
    exit 1
fi

# Fetch the list of Lambda functions
lambda_functions=$(aws lambda list-functions --query 'Functions[*].FunctionName' --output text)

# Check if the list is empty
if [ -z "$lambda_functions" ]; then
    echo "No Lambda functions found."
    exit 1
fi

# Convert the list to an array
IFS=$'\t' read -r -a function_array <<< "$lambda_functions"

# Display the list of Lambda functions with numbers
echo "List of Lambda functions:"
for i in "${!function_array[@]}"; do
    echo "$((i+1)). ${function_array[$i]}"
done

# Prompt the user to enter a number
read -p "Enter the number of the Lambda function to invoke: " number

# Validate the input
if ! [[ "$number" =~ ^[0-9]+$ ]] || [ "$number" -lt 1 ] || [ "$number" -gt "${#function_array[@]}" ]; then
    echo "Invalid input. Please enter a valid number between 1 and ${#function_array[@]}."
    exit 1
fi

# Get the function name based on the user's input
selected_function=${function_array[$((number-1))]}

# Invoke the selected Lambda function
invoke_response=$(aws lambda invoke --function-name "$selected_function" --payload '{}' response.json)

# Check if the invocation was successful
if [ $? -eq 0 ]; then
    echo "Lambda function '$selected_function' invoked successfully."
    cat response.json
else
    echo "Error invoking Lambda function '$selected_function'."
fi

# Clean up the response file
rm -f response.json
