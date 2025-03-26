# Terraform-3tier-WebApplication-AWS

This module contains terraform code to deploy 3 tier architecture in AWS Cloud provider

It creates a VPC with 2 Public and 2 Private Subnets.

Web tier instances will be deployed in Public Subnet, 
App Tier instances will be deployed in Private Subnet 
And RDS Database instance tier will be deployed in other Private Subnet.

External Application Load Balancer routes the incoming traffic to Web tier instance.
Internal Application Load Balancer routes the incoming traffic to App tier instance.
In DB tier, the 2nd Private Subnet has Amazon Aurora installed with help of DB_subnet_group.
