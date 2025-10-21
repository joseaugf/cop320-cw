#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CLUSTER_NAME="petshop-demo-eks"

echo -e "${YELLOW}=== Cleaning Up IAM Resources ===${NC}"
echo -e "${YELLOW}This will delete IAM roles and policies created by previous deployments${NC}"
echo ""

echo -e "${RED}WARNING: This will delete the following IAM resources:${NC}"
echo "  - IAM Role: ${CLUSTER_NAME}-cluster-role"
echo "  - IAM Role: ${CLUSTER_NAME}-node-role"
echo "  - IAM Policy: ${CLUSTER_NAME}-adot-collector-policy"
echo ""

read -p "Are you sure you want to continue? (yes/no) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""

# Function to detach policies from role
detach_policies_from_role() {
    local role_name=$1
    echo -e "${YELLOW}Detaching policies from role: ${role_name}${NC}"
    
    # Get attached managed policies
    POLICIES=$(aws iam list-attached-role-policies --role-name $role_name --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
    
    if [ -n "$POLICIES" ]; then
        for policy_arn in $POLICIES; do
            echo "  Detaching policy: $policy_arn"
            aws iam detach-role-policy --role-name $role_name --policy-arn $policy_arn 2>/dev/null || true
        done
    fi
    
    # Get inline policies
    INLINE_POLICIES=$(aws iam list-role-policies --role-name $role_name --query 'PolicyNames[]' --output text 2>/dev/null || echo "")
    
    if [ -n "$INLINE_POLICIES" ]; then
        for policy_name in $INLINE_POLICIES; do
            echo "  Deleting inline policy: $policy_name"
            aws iam delete-role-policy --role-name $role_name --policy-name $policy_name 2>/dev/null || true
        done
    fi
}

# Delete EKS Cluster Role
echo -e "${YELLOW}Step 1: Deleting EKS Cluster Role...${NC}"
CLUSTER_ROLE="${CLUSTER_NAME}-cluster-role"
if aws iam get-role --role-name $CLUSTER_ROLE >/dev/null 2>&1; then
    detach_policies_from_role $CLUSTER_ROLE
    aws iam delete-role --role-name $CLUSTER_ROLE
    echo -e "${GREEN}✓ Deleted role: ${CLUSTER_ROLE}${NC}"
else
    echo -e "${YELLOW}Role ${CLUSTER_ROLE} does not exist${NC}"
fi
echo ""

# Delete EKS Node Role
echo -e "${YELLOW}Step 2: Deleting EKS Node Role...${NC}"
NODE_ROLE="${CLUSTER_NAME}-node-role"
if aws iam get-role --role-name $NODE_ROLE >/dev/null 2>&1; then
    detach_policies_from_role $NODE_ROLE
    
    # Remove role from instance profiles
    INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role --role-name $NODE_ROLE --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null || echo "")
    if [ -n "$INSTANCE_PROFILES" ]; then
        for profile in $INSTANCE_PROFILES; do
            echo "  Removing role from instance profile: $profile"
            aws iam remove-role-from-instance-profile --instance-profile-name $profile --role-name $NODE_ROLE 2>/dev/null || true
        done
    fi
    
    aws iam delete-role --role-name $NODE_ROLE
    echo -e "${GREEN}✓ Deleted role: ${NODE_ROLE}${NC}"
else
    echo -e "${YELLOW}Role ${NODE_ROLE} does not exist${NC}"
fi
echo ""

# Delete ADOT Collector Policy
echo -e "${YELLOW}Step 3: Deleting ADOT Collector Policy...${NC}"
POLICY_NAME="${CLUSTER_NAME}-adot-collector-policy"

# Find the policy ARN
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text 2>/dev/null || echo "")

if [ -n "$POLICY_ARN" ]; then
    # Detach from all roles
    ATTACHED_ROLES=$(aws iam list-entities-for-policy --policy-arn $POLICY_ARN --query 'PolicyRoles[].RoleName' --output text 2>/dev/null || echo "")
    if [ -n "$ATTACHED_ROLES" ]; then
        for role in $ATTACHED_ROLES; do
            echo "  Detaching policy from role: $role"
            aws iam detach-role-policy --role-name $role --policy-arn $POLICY_ARN 2>/dev/null || true
        done
    fi
    
    # Delete all policy versions except default
    VERSIONS=$(aws iam list-policy-versions --policy-arn $POLICY_ARN --query 'Versions[?!IsDefaultVersion].VersionId' --output text 2>/dev/null || echo "")
    if [ -n "$VERSIONS" ]; then
        for version in $VERSIONS; do
            echo "  Deleting policy version: $version"
            aws iam delete-policy-version --policy-arn $POLICY_ARN --version-id $version 2>/dev/null || true
        done
    fi
    
    # Delete the policy
    aws iam delete-policy --policy-arn $POLICY_ARN
    echo -e "${GREEN}✓ Deleted policy: ${POLICY_NAME}${NC}"
else
    echo -e "${YELLOW}Policy ${POLICY_NAME} does not exist${NC}"
fi
echo ""

echo -e "${GREEN}=== IAM Cleanup Complete ===${NC}"
echo -e "${GREEN}You can now run ./deploy.sh in a different region${NC}"
echo ""
