Keystone Quick Install & Setup
===============================

##Please run as root

#### Deploy Keystone with default data

    # Install git (if necessary)
    apt-get install -y git
        cd /root
        git clone https://github.com/swiftstack/keystone_install.git
        cd keystone_install
        ./install_keystone.sh $Your_Swift_API_IP


#### Deploy Keystone without default data

    # Install git (if necessary)
    apt-get install -y git
	cd /root
	git clone https://github.com/swiftstack/keystone_install.git
	cd keystone_install
	./install_keystone.sh


#### You can also pupolate DB with default data by:  
    ./default_keystone_config.sh


This is a quick keystone deploying script

The Keystone Version is Fixed to ``stable/Havana``
