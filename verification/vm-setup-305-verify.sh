#!/bin/bash

FAILURES=0
REPORT=""

pass() {
    REPORT+="PASS: $1\n"
}

fail() {
    REPORT+="FAIL: $1\n"
    FAILURES=1
}

# [System Memory]
REPORT+="\n[System Memory]\n"
if grep -q "/swapfile" /proc/swaps; then pass "Swap is ACTIVE"; else fail "Swap is NOT active"; fi

if [ "$(sysctl -n vm.swappiness)" -eq 10 ]; then pass "vm.swappiness is 10"; else fail "vm.swappiness is $(sysctl -n vm.swappiness) (expected 10)"; fi

if [ "$(sysctl -n vm.vfs_cache_pressure)" -eq 50 ]; then pass "vm.vfs_cache_pressure is 50"; else fail "vm.vfs_cache_pressure is $(sysctl -n vm.vfs_cache_pressure) (expected 50)"; fi

# [MySQL Configuration]
REPORT+="\n[MySQL Configuration]\n"
if systemctl is-active --quiet mysql; then pass "Service: MySQL is RUNNING"; else fail "Service: MySQL is DOWN"; fi

if grep -q "bind-address = 0.0.0.0" "/etc/mysql/mysql.conf.d/mysqld.cnf"; then 
    pass "Config: External Connections enabled (0.0.0.0)"; 
else 
    fail "Config: bind-address incorrect"; 
fi

if grep -q "performance_schema = OFF" "/etc/mysql/mysql.conf.d/mysqld.cnf"; then pass "Config: Performance Schema disabled"; else fail "Config: Performance Schema enabled"; fi

if grep -q "innodb_buffer_pool_size = 16M" "/etc/mysql/mysql.conf.d/mysqld.cnf"; then pass "Config: Buffer Pool Size set to 16M"; else fail "Config: Buffer Pool Size incorrect"; fi

# [Docker]
REPORT+="\n[Docker]\n"
if command -v docker &> /dev/null && sudo docker info > /dev/null 2>&1; then 
    pass "Docker installed and daemon running"
else 
    fail "Docker missing or daemon not responding"
fi

# [Node & PM2]
REPORT+="\n[Node & PM2]\n"
# Load fnm manually for CI context
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --use-on-cd --shell bash)" 2>/dev/null

if command -v node &> /dev/null; then pass "Node installed ($(node -v))"; else fail "Node not found"; fi

if command -v pm2 &> /dev/null && pm2 list &> /dev/null; then 
    pass "PM2 installed and active"
else 
    fail "PM2 missing or not running"
fi

# Final Report
echo "==================================="
echo "       VERIFICATION REPORT         "
echo "==================================="
echo -e "$REPORT"
echo "==================================="

# System Resources
echo ""
echo "[System Resources]"
echo "--- Memory Usage ---"
free -h
echo ""
echo "--- Top 5 Memory Consumers ---"
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 6
echo "==================================="

if [ $FAILURES -eq 0 ]; then
    exit 0
else
    exit 1
fi