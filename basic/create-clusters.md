# How to create 3 AKS clusters?

```bash
cd tools

export SUBSCRIPTION=2b03bfb8-e885-4566-a62a-909a11d71692
export NAME_PREFIX=caravel-demo

# Set up two clusters in one vnet.
setup.sh ${SUBSCRIPTION} ${NAME_PREFIX}

# Set up one cluster in another vnet and same region.
./setup-vnet2.sh ${SUBSCRIPTION} ${NAME_PREFIX}

# Set up one cluster in another vnet in another region.
./setup-vnet3.sh ${SUBSCRIPTION} ${NAME_PREFIX}
```