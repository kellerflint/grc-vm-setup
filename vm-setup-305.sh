#!/bin/bash

#configuration
nodeVer=23

#helper functions
function genPassword() {
    password=""
    for i in {1..8}
    do 
        randIndex=$(getDigit 2)
        if [ $randIndex -eq 0 ]
        then 
            digit=$(getDigit 10)
            password="$digit$password"
        else 
            letter=$(getLetter)
            password="$letter$password"
        fi
    done 
    echo $password
}

function getMySQLCompatibleSymbols() {
    symbols=("#" "!" "~" "%" "^" "_" "-" "+" "=" "{" "}" "(" ")" "<" ">" "|" "." "," ";")
    randIndex=$(getDigit 20)
    symbol=${symbols[randIndex]}
    echo $symbol 
}

function getLetter() {
    letters=("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z" "A" "B" "C" "D" "E" "F" "G" "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R" "S" "T" "U" "V" "W" "X" "Y" "Z")
    randIndex=$(getDigit 51)
    letter=${letters[randIndex]}
    echo $letter
}

function getDigit() {
  echo $((RANDOM % $1)) 
}

#steps 
function updateApt() {
    sudo apt -y update 2>&1 | tee -a ./install.log
    yes | sudo DEBIAN_FRONTEND=noninteractive apt-get -yqq upgrade
}

function installDocker() {
    sudo apt -y install ca-certificates curl > /dev/null 2>&1
    sudo install -m 0755 -d /etc/apt/keyrings > /dev/null 2>&1
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc > /dev/null 2>&1
    sudo chmod a+r /etc/apt/keyrings/docker.asc > /dev/null 2>&1
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1
    sudo apt -y update > /dev/null 2>&1

    sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
}

function installGit() {
    sudo apt -y install git > /dev/null 2>&1
}

function installMySQLServer() {
    sudo apt -y install mysql-server > /dev/null 2>&1

    sudo systemctl enable mysql > /dev/null 2>&1
    sudo systemctl start mysql > /dev/null 2>&1
    sudo systemctl status mysql >> ./install.log 

    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$rootPassword'; FLUSH PRIVILEGES;" > /dev/null 2>&1
}

function installPhpMyAdmin() {
    pmaPort=8081

    echo "# Installing Apache and PHP" >> ./install.log
    sudo apt -y install apache2 php php-cli php-mbstring unzip > /dev/null 2>&1

    # Pre-configure phpMyAdmin installation to avoid interactive prompts
    echo "# Pre-configuring phpMyAdmin installation" >> ./install.log
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password $rootPassword" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password $rootPassword" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password $rootPassword" | sudo debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | sudo debconf-set-selections

    # Install phpMyAdmin non-interactively
    echo "# Installing phpMyAdmin without prompts" >> ./install.log
    sudo apt -y install phpmyadmin > /dev/null 2>&1

    # Ensure Apache serves phpMyAdmin from the correct location
    echo "# Configuring Apache virtual host for phpMyAdmin on port $pmaPort" >> ./install.log
    sudo tee /etc/apache2/sites-available/phpmyadmin.conf > /dev/null <<EOL
    <VirtualHost *:$pmaPort>
        DocumentRoot /usr/share/phpmyadmin
        DirectoryIndex index.php
        <Directory /usr/share/phpmyadmin>
            Require all granted
            AllowOverride All
            Options +FollowSymLinks
        </Directory>
        <FilesMatch \.php$>
            SetHandler application/x-httpd-php
        </FilesMatch>
    </VirtualHost>
EOL

    # Enable site and port
    sudo a2ensite phpmyadmin.conf > /dev/null 2>&1
    sudo sed -i "/^Listen 80$/a Listen $pmaPort" /etc/apache2/ports.conf

    # Restart Apache to apply changes
    echo "# Restarting Apache" >> ./install.log
    sudo systemctl restart apache2

    echo "# phpMyAdmin setup complete!" >> ./install.log
}

function installNode() {
    sudo apt -y install unzip > /dev/null 2>&1
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/share/fnm" > /dev/null 2>&1

    # Load fnm into the shell environment
    echo 'export PATH="$HOME/.local/share/fnm:$PATH"' >> ~/.bashrc
    echo 'eval "$(fnm env --use-on-cd --shell bash)"' >> ~/.bashrc 
    source ./.bashrc > /dev/null 2>&1

    # Apply the changes immediately
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env --use-on-cd --shell bash)"

    echo "Installing Node - v$nodeVer" >> ./install.log
    fnm install $nodeVer >> ./install.log > /dev/null 2>&1
    fnm use $nodeVer >> ./install.log > /dev/null 2>&1
}

function generateReadme() {
    echo "Next Steps:" > readme.txt
    echo "" >> readme.txt
    echo "1. To change the Node.js version using fnm:" >> readme.txt
    echo "   fnm list (shows installed versions)" >> readme.txt
    echo "   fnm install <version> (installs a new version - eg. fnm install 23)" >> readme.txt
    echo "   fnm use <version> (switches to the specified version - eg. fnm use 23)" >> readme.txt
    echo "" >> readme.txt
    echo "2. To connect to the MySQL database using the root password:" >> readme.txt
    echo "   mysql -h localhost -P 3306 -u root -p" >> readme.txt
    echo "   When prompted, enter the root password: - '$rootPassword'" >> readme.txt
    echo "" >> readme.txt
    echo "3. Using Git to manage project files:" >> readme.txt
    echo "   - Clone a repository:" >> readme.txt
    echo "     git clone <repository_url>" >> readme.txt
    echo "     cd <repository_folder>" >> readme.txt
    echo "" >> readme.txt
    echo "   - Pull the latest changes from the repository:" >> readme.txt
    echo "     git pull origin master" >> readme.txt
    echo "" >> readme.txt
    echo "   - Make changes to project files, then add and commit them:" >> readme.txt
    echo "     (Modify project files as needed, then stage changes)" >> readme.txt
    echo "     git add <file1> <file2>  # Add specific files" >> readme.txt
    echo "     git add .                # Add all modified files" >> readme.txt
    echo "     git commit -m 'Describe your changes here'" >> readme.txt
    echo "" >> readme.txt
    echo "   - Push your changes to the remote repository:" >> readme.txt
    echo "     git push origin master" >> readme.txt
    echo "" >> readme.txt
    echo "4. Ports being used:" >> readme.txt
    echo "   - MySQL is running on port 3306." >> readme.txt
    echo "   - PhpMyAdmin is running on port 8081 (access at http://<your-vm-ip>:8081)" >> readme.txt
    echo "" >> readme.txt
    echo "5. Getting help on commands:" >> readme.txt
    echo "   - Use 'git help' for Git commands." >> readme.txt
    echo "   - Use 'docker --help' for Docker commands." >> readme.txt
    echo "   - Use 'mysql --help' for MySQL commands." >> readme.txt
    echo "" >> readme.txt
    echo "6. Checking installed versions of tools:" >> readme.txt
    echo "   - Git: git --version" >> readme.txt
    echo "   - Docker: docker -v" >> readme.txt
    echo "   - MySQL: mysql --version" >> readme.txt
    echo "   - Node.js: node -v" >> readme.txt
    echo "   - NPM: npm -v" >> readme.txt
    echo "" >> readme.txt
    echo "7. Running Node.js apps with PM2 (auto-restart):" >> readme.txt
    echo "   cd /home/projects/your-app" >> readme.txt
    echo "   pm2 start app.js --name 'my-app'" >> readme.txt
    echo "" >> readme.txt
    echo "   PM2 will automatically:" >> readme.txt
    echo "   - Restart your app if it crashes" >> readme.txt
    echo "   - Start your app when server reboots" >> readme.txt
    echo "" >> readme.txt
    echo "   Useful PM2 commands:" >> readme.txt
    echo "   pm2 list          # Show running apps" >> readme.txt
    echo "   pm2 logs          # Show app logs" >> readme.txt
    echo "   pm2 restart my-app # Restart app" >> readme.txt
    echo "   pm2 stop my-app   # Stop app" >> readme.txt
}

function configureMySQL() {
    # Allow external connections
    sudo sed -i 's/bind-address.*= 127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
    
    # Configure memory saving
    sudo sed -i '/^\[mysqld\]/a performance_schema = OFF\ninnodb_buffer_pool_size = 16M' /etc/mysql/mysql.conf.d/mysqld.cnf

    # Restart MySQL first
    sudo systemctl restart mysql > /dev/null 2>&1
    
    # Run each MySQL command separately with password
    sudo mysql -u root -p"$rootPassword" -e "DROP USER IF EXISTS 'root'@'%';" > /dev/null 2>&1
    sudo mysql -u root -p"$rootPassword" -e "CREATE USER 'root'@'%' IDENTIFIED BY '$rootPassword';" > /dev/null 2>&1
    sudo mysql -u root -p"$rootPassword" -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;" > /dev/null 2>&1
    sudo mysql -u root -p"$rootPassword" -e "FLUSH PRIVILEGES;" > /dev/null 2>&1
    
    # Open firewall port
    sudo ufw allow 3306 > /dev/null 2>&1
}

function installPM2() {
    # Install PM2 globally
    npm install -g pm2 > /dev/null 2>&1
    
    # Generate startup script for automatic boot restart
    pm2 startup > /dev/null 2>&1 || true
}

function runStep() {
    stepNum=$1
    stepText=$2
    stepFunction=$3

    echo -n "#$stepNum $stepText" | tee -a ./install.log
    start=$(date +%s)
    
    $stepFunction
    
    end=$(date +%s)
    elapsed=$(($end - $start))
    
    printf " (%d seconds)\n" "$elapsed" | tee -a ./install.log
}

#install steps
rootPassword=$(genPassword) # used in steps 4, 5, 8
echo "Executing 9 steps" | tee -a ./install.log

totalStart=$(date +%s)
runStep 1 "Updating apt index" updateApt
runStep 2 "Installing docker" installDocker
runStep 3 "Installing git" installGit
runStep 4 "Installing MySQL Server" installMySQLServer
runStep 5 "Installing PhpMyAdmin" installPhpMyAdmin
runStep 6 "Installing Node" installNode
runStep 7 "Generating readme.txt file" generateReadme
runStep 8 "Configuring MySQL external access" configureMySQL
runStep 9 "Installing PM2" installPM2
totalEnd=$(date +%s)

totalElapsed=$((totalEnd - totalStart))
minutes=$((totalElapsed / 60))
seconds=$((totalElapsed % 60))

echo "Done! (${minutes}m ${seconds}s)" | tee -a ./install.log