az aks create \
  --resource-group alramz-dev-rg \
  --name alramz-dev-aks \
  --location uaenorth \
  --tier free \
  --node-count 1 \
  --node-vm-size Standard_B2s_v2 \
  --os-sku AzureLinux \
  --generate-ssh-keys