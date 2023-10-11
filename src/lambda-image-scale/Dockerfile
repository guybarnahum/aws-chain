FROM public.ecr.aws/lambda/python:3.11

# Install the function's dependencies using file requirements.txt
# from your project folder.

COPY requirements.txt  .

RUN  yum groupinstall -y "Development Tools"  --setopt=group_package_types=mandatory,default
RUN  pip3 install --upgrade pip
RUN  pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy function code
COPY lambda.py ${LAMBDA_TASK_ROOT}

# Copy function layers
RUN mkdir -p /opt
COPY lambda-utils-aws-lambda-layer-python3.11.zip .
RUN unzip lambda-utils-aws-lambda-layer-python3.11.zip -d /opt

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda.lambda_handler" ]
