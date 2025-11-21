#!/bin/bash

function configureSwap() {
    echo "--- Configuring Swap and System Memory ---"

    # Setup Swap File
    if [ ! -f /swapfile ]; then
        echo "Creating swapfile..."
        sudo fallocate -l 1G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile > /dev/null 2>&1
    else
        echo "Swapfile already exists. Skipping creation."
    fi

    # Activate swap
    sudo swapon /swapfile 2>/dev/null

    # Make Swap Permanent
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "Adding swap to fstab..."
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null 2>&1
    fi

    # 3. Adjust Memory Settings (Current Session)
    sudo sysctl vm.swappiness=10 > /dev/null 2>&1
    sudo sysctl vm.vfs_cache_pressure=50 > /dev/null 2>&1

    # 4. Make Memory Settings Permanent in sysctl.conf
    if ! grep -q "vm.swappiness=10" /etc/sysctl.conf; then
        echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
    fi
    
    if ! grep -q "vm.vfs_cache_pressure=50" /etc/sysctl.conf; then
        echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
    fi
    
    echo "Swap configuration complete."
}

function configureMySQL() {
    echo "--- Configuring MySQL Memory Settings ---"
    
    CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"

    if [ -f "$CONFIG_FILE" ]; then
        # Configure memory saving
        if ! grep -q "performance_schema = OFF" "$CONFIG_FILE"; then
            echo "Injecting memory settings into $CONFIG_FILE..."
            sudo sed -i '/^\[mysqld\]/a performance_schema = OFF\ninnodb_buffer_pool_size = 16M' "$CONFIG_FILE"
        else
            echo "MySQL memory settings already appear to be present."
        fi

        # Restart MySQL to apply changes
        echo "Restarting MySQL service..."
        sudo systemctl restart mysql
        
        echo "MySQL configuration complete."
    else
        echo "Error: MySQL config file ($CONFIG_FILE) not found. Is MySQL installed?"
    fi
}

function verifyConfig() {
    echo ""
    echo "==================================="
    echo "       VERIFICATION REPORT         "
    echo "==================================="

    # Verify Swap
    echo "[System Memory]"
    if [[ $(swapon --show) ]]; then
        echo "PASS: Swap is ACTIVE."
    else
        echo "FAIL: Swap is not active."
    fi

    # Verify Sysctl
    swappiness=$(sysctl vm.swappiness | awk '{print $3}')
    cache_pressure=$(sysctl vm.vfs_cache_pressure | awk '{print $3}')

    if [ "$swappiness" -eq "10" ]; then 
        echo "PASS: vm.swappiness is 10"
    else 
        echo "FAIL: vm.swappiness is $swappiness (Expected 10)"
    fi

    if [ "$cache_pressure" -eq "50" ]; then 
        echo "PASS: vm.vfs_cache_pressure is 50"
    else 
        echo "FAIL: vm.vfs_cache_pressure is $cache_pressure (Expected 50)"
    fi

    # Verify MySQL Config Content
    echo ""
    echo "[MySQL Configuration]"
    CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"
    
    if grep -q "performance_schema = OFF" "$CONFIG_FILE"; then
         echo "PASS: Config: Performance Schema disabled"
    else
         echo "FAIL: Config: Performance Schema not found in file"
    fi

    if grep -q "innodb_buffer_pool_size = 16M" "$CONFIG_FILE"; then
         echo "PASS: Config: Buffer Pool Size set to 16M"
    else
         echo "FAIL: Config: Buffer Pool Size not found in file"
    fi

    # 4. Verify MySQL Service Status
    if systemctl is-active --quiet mysql; then
        echo "PASS: Service: MySQL is RUNNING"
    else
        echo "FAIL: Service: MySQL is not running"
    fi
    echo "==================================="
}

# -----------------------------------------
# Execution
# -----------------------------------------

echo "Starting Configuration Update..."

# Run Steps
configureSwap
configureMySQL

# Run Verification
verifyConfig