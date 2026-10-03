# AWS IoT Data Processing Pipeline

## Project Description

This project is an AWS-based IoT data processing pipeline
for Smart Agriculture.

IoT sensors collect soil moisture, temperature and humidity data.
The data is sent to AWS IoT Core, processed using AWS Lambda,
and stored in DynamoDB and Amazon S3.

## AWS Services

- AWS IoT Core
- AWS Lambda
- Amazon DynamoDB
- Amazon S3
- Amazon CloudWatch

## Git and GitHub

Git is used for version control and GitHub is used for
source code management and collaboration.

## Project Flow

IoT Sensors
↓
AWS IoT Core
↓
AWS Lambda
↓
DynamoDB + S3
↓
Dashboard
↓
Farmer/User

## Alert

If soil moisture falls below 30%, the system generates
a low moisture alert.
