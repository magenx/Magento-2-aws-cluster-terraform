#!/bin/bash

if [[ -f "lock.lock" ]]; then
  echo "[!][ERROR] Lock exists. Something is wrong"
fi

echo "---"
echo "[!][INFO] First run - install terraform"
echo "---"
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform packer

## CHECK IF BACKEND CONFIG EXISTS
if [ ! -e "backend.tf" ]; then

AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].RegionName')

echo "---"
echo "[?][INPUT] Enter parameters for S3 backend config:"
echo "---"
read -e -p "[?] Enter the S3 bucket name: " -i "magenx-terraform-state-lock" STATE_BUCKET
read -e -p "[?] Enter the key: " -i "terraform.tfstate" OBJECT_KEY
read -e -p "[?] Enter the region: " -i "${AWS_REGION}" AWS_REGION
read -e -p "[?] Enter the DynamoDB table name: " -i "magenx-terraform-state-lock" DYNAMODB_TABLE
read -e -p "[?] Enter the workspace: " -i "production" WORKSPACE

echo "---"
echo "[!][INFO] Creating S3 bucket and dynamodb table"
echo "---"

# check bucket name on s3 storage
aws s3api head-bucket --bucket ${STATE_BUCKET}

if  [ $? -eq 0 ]; then
echo "[!][ERROR] S3 bucket ${STATE_BUCKET} exists. Something is wrong"
exit 1
fi

# create bucket
aws s3api create-bucket \
    --bucket ${STATE_BUCKET} \
    --region ${AWS_REGION} \
    --create-bucket-configuration LocationConstraint=${AWS_REGION}
	
# create bucket encription
aws s3api put-bucket-encryption \
    --bucket ${STATE_BUCKET} \
    --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

# enable versioning
aws s3api put-bucket-versioning \
    --bucket ${STATE_BUCKET} \
    --versioning-configuration Status=Enabled

# disable public access
aws s3api put-public-access-block \
    --bucket ${STATE_BUCKET} \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

aws s3api wait bucket-exists --bucket ${STATE_BUCKET}

# Define the bucket policy
STATE_BUCKET_POLICY=$(cat <<EOF
{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "dynamodb.amazonaws.com"
                },
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::${STATE_BUCKET}/*"
            }
        ]
}
EOF
)

# Apply bucket policy
echo "---"
echo "[!][INFO] Applying bucket policy to grant DynamoDB access to S3 bucket ${STATE_BUCKET}"
echo "---"
aws s3api put-bucket-policy --bucket "${STATE_BUCKET}" --policy "${STATE_BUCKET_POLICY}"

# create dynamodb table
aws dynamodb create-table \
    --table-name ${DYNAMODB_TABLE} \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --table-class STANDARD_INFREQUENT_ACCESS \
    --tags Key=Name,Value=${DYNAMODB_TABLE} \
    --deletion-protection-enabled

echo "---"
echo "[!][INFO] Waiting for DynamoDB tabe to become active ..."
echo "---"
aws dynamodb wait table-exists --table-name ${DYNAMODB_TABLE}
if  [ $? -ne 0 ]; then
exit 1
fi

echo "---"
echo "[!][INFO] Create the backend.tf file with the provided input"
echo "---"

cat <<EOF > backend.tf
terraform {
  backend "s3" {
    bucket          = "${STATE_BUCKET}"
    key             = "${OBJECT_KEY}"
    region          = "${AWS_REGION}"
    dynamodb_table  = "${DYNAMODB_TABLE}"
    workspace_key_prefix = "${AWS_REGION}/magenx"
  }
}
EOF

fi

terraform validate
if  [ $? -ne 0 ]; then
exit 1
fi

terraform init
if  [ $? -ne 0 ]; then
exit 1
fi

echo "---"
echo "[!][INFO] workspace set to ${WORKSPACE}"
echo "---"
terraform workspace new ${WORKSPACE}

echo
echo "[!][INFO] Running terraform plan to ${WORKSPACE}.plan.out"
terraform plan -out ${WORKSPACE}.plan.out -no-color 2>&1 > ${WORKSPACE}.plan.out.txt
ls -l ${WORKSPACE}.plan.out.txt

touch lock.lock
