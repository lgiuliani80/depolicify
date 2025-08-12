#!/bin/bash
echo "🔐 Assigning permissions to managed identity on subscription 3c81b235-e5f1-4ca5-9f8a-8f6426adba37..."
EXISTING=$(az role assignment list --assignee-object-id "6175096a-f286-4297-a0c9-b91a17edc99b" --include-inherited --role "Contributor" --scope "subscriptions/3c81b235-e5f1-4ca5-9f8a-8f6426adba37" | jq length)
if [ $EXISTING gt 0 ]
then
    echo "✅ Assignment already existing!"
else
    if az role assignment create --assignee-object-id "6175096a-f286-4297-a0c9-b91a17edc99b" --assignee-principal-type ServicePrincipal --role "Contributor" --scope "subscriptions/3c81b235-e5f1-4ca5-9f8a-8f6426adba37"
    then
        echo "✅ Permissions assigned!"
    else
        echo -e "\033[0;31m❌ Role assignment failed!\033[0m"
    fi
fi
echo "🔐 Assigning permissions to managed identity on subscription 3005bdb8-47b7-4316-9277-a7a5e87f88e3..."
EXISTING=$(az role assignment list --assignee-object-id "6175096a-f286-4297-a0c9-b91a17edc99b" --include-inherited --role "Contributor" --scope "subscriptions/3005bdb8-47b7-4316-9277-a7a5e87f88e3" | jq length)
if [ $EXISTING gt 0 ]
then
    echo "✅ Assignment already existing!"
else
    if az role assignment create --assignee-object-id "6175096a-f286-4297-a0c9-b91a17edc99b" --assignee-principal-type ServicePrincipal --role "Contributor" --scope "subscriptions/3005bdb8-47b7-4316-9277-a7a5e87f88e3"
    then
        echo "✅ Permissions assigned!"
    else
        echo -e "\033[0;31m❌ Role assignment failed!\033[0m"
    fi
fi
