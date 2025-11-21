# RCA: MySQL Failure with High VM CPU Usage

## Presenting Issue:
Student was unable to connect to MySQL database via Workbench.

## Investigation & Troubleshooting Steps:
* Verified VM connectivity via SSH. DigitalOcean monitoring showed CPU usage had been pegged at 100% for approximately 16 hours.
* Attempts to run `mysql` failed with a socket connection error, indicating the service was down or unresponsive.
* `htop` confirmed 100% CPU usage and RAM shortage.
* Enabling Kernel Threads in `htop` (`Shift + K`) revealed `kswapd0` was consuming 40%+ CPU.
* **Diagnosis:** The system was "thrashing." `kswapd0` was aggressively trying to reclaim memory for the OS, but because DigitalOcean Droplets do not come with Swap configured by default (to preserve SSD health), and physical RAM was exhausted, the process entered an infinite loop.
* **Initial Fix:** Configured MySQL to run in low-memory mode (`performance_schema = OFF`, `innodb_buffer_pool_size = 16M`).
* **Secondary Failure:** While this resolved the resource exhaustion, MySQL failed to restart. Status showed `"Server upgrade in progress"`, but it was hanging indefinitely.
* **Root Cause Speculation:** System logs show that an automatic unattended-upgrade for MySQL (specifically v8.0.43 to v8.0.44) occurred during the low-memory event. The OOM (Out of Memory) Killer may have terminated the MySQL process mid-write during this upgrade, causing corruption of the System Dictionary Information (SDI) files. MySQL logs seemed to indicate corruption of this file.

## Mitigation:
Student VMs should not contain unrecoverable data (all code can be easily pulled again from GitHub), so the easiest solution is to reprovision the VM and run an updated setup script with the new memory settings.

## Corrective Actions:
* **Updated VM Setup Script:**
    * **Swap Configured:** Added a 1GB Swap file with low swappiness (`vm.swappiness=10`). This respects DigitalOcean’s hardware concerns by making Swap a last-resort safety net to prevent this type of OOM crash.
    * **MySQL Tuning:** Adjusted MySQL configuration to reduce RAM footprint by more than 70%. This creates significanly more space for system updates and student applications.
* **Process Management:** Each running node app in pm2 uses approximately 30-50MB of RAM. Advise students to use `pm2` to stop unused Node.js applications from time to time. Stacking six or more of these processes can easily exceed the 1GB RAM limit on the current tier.
