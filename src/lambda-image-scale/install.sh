#!/bin/bash
#
# This scripts builds a lambda image
# following directory structure:
#
#   _lambda
#   ├── lambda.py
#   ├── install.sh
#   ├── requirements.txt
#   └── Dockerfile
#

AWS_ECR_REPROSITORY_URL=$1
AWS_ACCOUNT_ID=$2
AWS_REGION=${3:-$AWS_DEFAULT_REGION}

function usage {
  echo "Usage : $0 <AWS_ECR_REPROSITORY_URL> <AWS_ACCOUNT_ID> [<AWS_REGION>]"
  echo "Error : $2"
}

if [ -z "$1" ]; then
    usage $0 "No AWS_ECR_REPROSITORY_URL supplied"
    exit -1
fi

if [ -z "$2" ]; then
    usage $0 "No AWS_ACCOUNT_ID supplied"
    exit -2
fi

if [ -z "$3" ]; then
    echo "No AWS_REGION supplied - using default region: $AWS_DEFAULT_REGION"
fi

echo "ecr_image_url: $AWS_ECR_REPROSITORY_URL, account: $AWS_ACCOUNT_ID, region: $AWS_REGION"

BASEDIR=$(dirname "$0")
echo "Running from $BASEDIR"

pushd $BASEDIR

#
# Copy layers into lambda directory for Dockerfile to find
# Notice: Docker can not access files in parent direcotry, so need to copy and cleanup external code
#
cp -R -v ../artifacts/lambda_layers/lambda-utils-aws-lambda-layer-python3.11.zip .

aws ecr get-login-password --region $AWS_REGION \
    | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker build -t $AWS_ECR_REPROSITORY_URL .
echo "pushing to ecr may take a long time 😱 -- go get ☕"
docker push     $AWS_ECR_REPROSITORY_URL

# record digest
DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $AWS_ECR_REPROSITORY_URL)
PARTS=(${DIGEST//:/ })
echo ${PARTS[1]} > sha256.digest

# clean up
docker system prune -f
rm *.zip

popd # we are back in the callers working-dir

# pass errors to caller
exit $?
