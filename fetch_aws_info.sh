#!/usr/bin/bash

check_credentials() {
        if [ ! -f ~/.aws/credentials ] && { [ -z "$AWS_ACCESS_KEY_ID" ] || [ -Z "$AWS_SECRET_ACCESS_KEY" ]; }; then
                echo "Please configure your AWS Credentials by setting the AWS Access Key ID and the AWS Secret Access Key in ~/.aws/credentials. \
                Another way is to add them as Environment Variables."
                return 1
        fi
}

select_aws_profile () {
        profiles=$(grep -o "^\[[^]]*\]" ~/.aws/credentials | grep -v '\-source' |sed 's/\[\(.*\)\]/\1/')
        i=1
        echo "Select an AWS Profile:"
        for profile in $profiles; do
                echo "[$i] $profile"
                eval "awsProfiles_$i=$profile"
                i=$((i + 1))
        done

        while true; do
                printf "Enter number (1-%d): " "$((i - 1))"
                read -r number
                if [ "$number" -ge 1 ] 2>/dev/null && [ "$number" -lt "$i" ] 2>/dev/null; then
                        eval "AWS_PROFILE=\$awsProfiles_$number"
                        echo -e "Selected \033[32m$AWS_PROFILE\033[0m"
                        break
                else
                        echo -e "\033[31mInvalid selection..\033[0m"
                fi
        done
        export AWS_PROFILE
}

menu() {
        echo "[1] Connect to ECS Container"
        echo "[2] Fetch ECR Findings"
        echo "[3] Compare ECR Images [WIP]"
        echo "[4] Exit"
        printf "Select action: "
        read -r function
        case $function in
                1) connect_to_container;;
                2) ecr_findings;;
                4) exit 0;;
                *) echo "Invalid selection."; menu;;
        esac
}

banner() {
        echo -e "here\n"
}

connect_to_container() {
        echo "Fetching clusters.."
        clusters=$(aws-profile aws ecs --profile $AWS_PROFILE --region eu-west-2 list-clusters --output text | awk -F'/' '{print $2}')
        if [ -z "$clusters" ]; then
                echo "No clusters found.."
                return
        fi
        i=1
        echo "Select Cluster:"
        for cluster in $clusters; do
                echo "[$i] $cluster"
                eval "awsClusters_$i=$cluster"
                i=$((i + 1))
        done
        while true; do
                printf "Enter number (1-%d): " "$((i - 1))"
                read -r number
                if [ "$number" -ge 1 ] 2>/dev/null && [ "$number" -lt "$i" ] 2>/dev/null; then
                        eval "CLUSTER=\$awsClusters_$number"
                        echo -e "Selected \033[32m$CLUSTER\033[0m"
                        break
                else
                        echo -e "\033[31mInvalid selection..\033[0m"
                fi
        done
        echo "Fetching services.."
        services=$(aws-profile aws ecs --profile $AWS_PROFILE --region eu-west-2 list-services --cluster $CLUSTER --output text | awk -F'/' '{print $3}')
        if [ -z "$services" ]; then
                echo "No services found.."
                return
        fi
        i=1
        echo "Select Service:"
        for service in $services; do
                echo "[$i] $service"
                eval "awsServices_$i=$service"
                i=$((i + 1))
        done
        while true; do
                printf "Enter number (1-%d): " "$((i - 1))"
                read -r number
                if [ "$number" -ge 1 ] 2>/dev/null && [ "$number" -lt "$i" ] 2>/dev/null; then
                        eval "SERVICE=\$awsServices_$number"
                        echo -e "Selected \033[32m$SERVICE\033[0m"
                        break
                else
                        echo -e "\033[31mInvalid selection..\033[0m"
                fi
        done
        task=$(aws-profile aws ecs --profile $AWS_PROFILE --region eu-west-2 list-tasks --cluster $CLUSTER --service $SERVICE --output text | awk -F'/' '{print $3}' | head -n 1)
        aws-profile -p $AWS_PROFILE aws ecs execute-command --region eu-west-2 --cluster $CLUSTER --task $task --container $SERVICE --command "/bin/bash" --interactive
        menu
}

ecr_findings() {
        echo "Fetching repositories.."
        repositories=$(aws-profile -p $AWS_PROFILE aws ecr describe-repositories | jq -r '.repositories[].repositoryName')
        if [ -z "$repositories" ]; then
                echo "No repositories found.."
                return
        fi
        i=1
        echo "Select Repository:"
        for repo in $repositories; do
                echo "[$i] $repo"
                eval "awsRepositories_$i=$repo"
                i=$((i + 1))
        done
        while true; do
                printf "Enter number (1-%d): " "$((i - 1))"
                read -r number
                if [ "$number" -ge 1 ] 2>/dev/null && [ "$number" -lt "$i" ] 2>/dev/null; then
                        eval "REPO=\$awsRepositories_$number"
                        echo -e "Selected \033[32m$REPO\033[0m"
                        break
                else
                        echo -e "\033[31mInvalid selection..\033[0m"
                fi
        done
        imageId=$(aws-profile -p $AWS_PROFILE aws ecr describe-images --repository-name $REPO --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageDigest' | jq -r)
        aws-profile -p $AWS_PROFILE aws ecr describe-image-scan-findings --repository-name $REPO --image-id imageDigest=$imageId --query imageScanFindings.findings | jq '.[] | select(.severity == "CRITICAL") | {name: .name, description: .description}'
}

banner && check_credentials && select_aws_profile || exit 1
menu || exit 1
