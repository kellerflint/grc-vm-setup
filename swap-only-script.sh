# Create and activate the 2GB file (for current session)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile > /dev/null 2>&1
sudo swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null 2>&1

# Adjust memory settings (for current session)
sudo sysctl vm.swappiness=10 > /dev/null 2>&1
sudo sysctl vm.vfs_cache_pressure=50 > /dev/null 2>&1

# Make memory settings permanent
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
