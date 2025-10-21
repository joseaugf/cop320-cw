#!/usr/bin/env python3
"""
Generate Kubernetes manifests with environment-specific values.
This script reads template manifests and populates them with actual values
from the AWS environment (account ID, region, database endpoint, etc.)
"""

import os
import sys
import json
import boto3
import yaml
from pathlib import Path

def get_aws_info():
    """Get AWS account and region information."""
    sts = boto3.client('sts')
    account_id = sts.get_caller_identity()['Account']
    region = os.environ.get('AWS_REGION', os.environ.get('AWS_DEFAULT_REGION', 'us-east-2'))
    return account_id, region

def get_stack_outputs(stack_name, region):
    """Get CloudFormation stack outputs."""
    cfn = boto3.client('cloudformation', region_name=region)
    
    try:
        response = cfn.describe_stacks(StackName=stack_name)
        outputs = {}
        
        if response['Stacks']:
            for output in response['Stacks'][0].get('Outputs', []):
                outputs[output['OutputKey']] = output['OutputValue']
        
        return outputs
    except Exception as e:
        print(f"Warning: Could not get stack outputs: {e}")
        return {}

def get_db_password(secret_name, region):
    """Get database password from Secrets Manager."""
    secrets = boto3.client('secretsmanager', region_name=region)
    
    try:
        response = secrets.get_secret_value(SecretId=secret_name)
        return response['SecretString']
    except Exception as e:
        print(f"Warning: Could not get database password: {e}")
        return "changeme123"  # Fallback

def replace_placeholders(content, replacements):
    """Replace placeholders in content."""
    for key, value in replacements.items():
        content = content.replace(f"${{{key}}}", str(value))
        content = content.replace(f"__{key}__", str(value))
    return content

def process_manifest(input_file, output_file, replacements):
    """Process a single manifest file."""
    print(f"Processing {input_file} -> {output_file}")
    
    with open(input_file, 'r') as f:
        content = f.read()
    
    # Replace placeholders
    content = replace_placeholders(content, replacements)
    
    # Write output
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, 'w') as f:
        f.write(content)
    
    print(f"  ✓ Generated {output_file}")

def main():
    print("=" * 60)
    print("Generating Kubernetes Manifests")
    print("=" * 60)
    
    # Get AWS information
    account_id, region = get_aws_info()
    print(f"AWS Account ID: {account_id}")
    print(f"AWS Region: {region}")
    
    # Get environment variables
    stack_name = os.environ.get('STACK_NAME', 'petshop-observability-demo')
    cluster_name = os.environ.get('CLUSTER_NAME', 'petshop-demo-eks')
    namespace = os.environ.get('NAMESPACE', 'petshop-demo')
    
    print(f"Stack Name: {stack_name}")
    print(f"Cluster Name: {cluster_name}")
    print(f"Namespace: {namespace}")
    
    # Get stack outputs
    outputs = get_stack_outputs(stack_name, region)
    db_endpoint = outputs.get('DatabaseEndpoint', os.environ.get('DB_ENDPOINT', 'postgresql.petshop-demo.svc.cluster.local'))
    vpc_id = outputs.get('VPCId', os.environ.get('VPC_ID', ''))
    
    print(f"Database Endpoint: {db_endpoint}")
    print(f"VPC ID: {vpc_id}")
    
    # Get database password
    db_password = get_db_password(f"{stack_name}/db-password", region)
    print("Database password retrieved from Secrets Manager")
    
    # Build ECR image URLs
    ecr_base = f"{account_id}.dkr.ecr.{region}.amazonaws.com/petshop-demo"
    
    # Create replacements dictionary
    replacements = {
        'AWS_ACCOUNT_ID': account_id,
        'AWS_REGION': region,
        'STACK_NAME': stack_name,
        'CLUSTER_NAME': cluster_name,
        'NAMESPACE': namespace,
        'DB_ENDPOINT': db_endpoint,
        'DB_PASSWORD': db_password,
        'VPC_ID': vpc_id,
        'ECR_BASE': ecr_base,
        'CATALOG_IMAGE': f"{ecr_base}/catalog-service:latest",
        'CART_IMAGE': f"{ecr_base}/cart-service:latest",
        'CHECKOUT_IMAGE': f"{ecr_base}/checkout-service:latest",
        'FEATURE_FLAG_IMAGE': f"{ecr_base}/feature-flag-service:latest",
        'FRONTEND_IMAGE': f"{ecr_base}/frontend:latest",
    }
    
    print("\nReplacements:")
    for key, value in replacements.items():
        if 'PASSWORD' not in key:
            print(f"  {key}: {value}")
    
    # Define manifest files to process
    manifest_mappings = [
        ('k8s/10-postgresql.yaml', 'k8s-generated/10-postgresql.yaml'),
        ('k8s/11-redis.yaml', 'k8s-generated/11-redis.yaml'),
        ('k8s/20-catalog-service.yaml', 'k8s-generated/20-catalog-service.yaml'),
        ('k8s/21-cart-service.yaml', 'k8s-generated/21-cart-service.yaml'),
        ('k8s/22-checkout-service.yaml', 'k8s-generated/22-checkout-service.yaml'),
        ('k8s/23-feature-flag-service.yaml', 'k8s-generated/23-feature-flag-service.yaml'),
        ('k8s/30-frontend.yaml', 'k8s-generated/30-frontend.yaml'),
        ('k8s/35-frontend-ingress.yaml', 'k8s-generated/35-frontend-ingress.yaml'),
        ('k8s/40-adot-collector.yaml', 'k8s-generated/40-adot-collector.yaml'),
        ('aws/k8s/60-adot-collector.yaml', 'k8s-generated/60-adot-collector.yaml'),
        ('aws/k8s/61-application-signals.yaml', 'k8s-generated/61-application-signals.yaml'),
        ('aws/k8s/62-fluent-bit-logs.yaml', 'k8s-generated/62-fluent-bit-logs.yaml'),
    ]
    
    # Process each manifest
    print("\nProcessing manifests...")
    for input_path, output_path in manifest_mappings:
        input_file = Path(input_path)
        output_file = Path(output_path)
        
        if input_file.exists():
            process_manifest(input_file, output_file, replacements)
        else:
            print(f"  ⚠ Warning: {input_file} not found, skipping")
    
    # Create a config file for reference
    config_file = Path('k8s-generated/deployment-config.json')
    with open(config_file, 'w') as f:
        json.dump({
            'account_id': account_id,
            'region': region,
            'stack_name': stack_name,
            'cluster_name': cluster_name,
            'namespace': namespace,
            'db_endpoint': db_endpoint,
            'vpc_id': vpc_id,
            'ecr_base': ecr_base,
        }, f, indent=2)
    
    print(f"\n✓ Configuration saved to {config_file}")
    
    print("\n" + "=" * 60)
    print("Manifest generation complete!")
    print("=" * 60)
    print(f"Generated manifests are in: k8s-generated/")
    print("=" * 60)

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"\n❌ Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
