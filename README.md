# Walkthrough of a sample project

This is a walkthrough of a database development process of a sample project.
During the development the tool [GTBuild] (https://github.com/SergeyRudyshin/gtbuild) and its [template for Oracle database] (https://github.com/SergeyRudyshin/gtbuild_ora_template) are used.

### Prerequisites 
* Oracle VirtualBox is installed
* A virutal machine with Oracle Database is setup
* Unix utilities (such as bash, awk, grep) are avalible

### Run

``` shell
$> bash gtbuild_ora_walkthrough "oracle@192.168.56.15" "/usr/bin/VBoxManage"
```

### Description

The walkthrough is composed in a form of the shell script gtbuild_ora_walkthrough.sh and consists of the following steps:

* Create temporary directory; download gtbuild and gtbuild_ora_template; initializing git repository
* add a table, insert a record, create an index; create a snapshot of the VM
* add a new column and check a diff between the full and patch files
* simulate situation when the patch is not in sync with the full file
* simulate invalid object
* simulate a conflict on indexes, which would not be catched without the full-file

### Demo

This demo was tested under the Windows OS with a pre-built virtual machine. 

Here are exact steps:

1. install VirtualBox https://www.virtualbox.org/wiki/Downloads
    * setup a host-only adapter (go to File->Preferences->Network->Host-Only Networks->Add (and specify 192.168.56.1 for the ip4address))
2. download the VM image http://www.oracle.com/technetwork/middleware/data-integrator/odi-demo-2032565.html
    * import it into the VirtualBox
    * take a snapshot and give it a name "imported"
    * modify the settings of the VM
        * change the name to gtbuildvm
        * reduce RAM to 2600
        * Network->"Adapter 1"->"attached to" change to "Host-Only adapter"
    * start the VM (Normal start with GUI)
    * inside VM run shell (all the passwords are "oracle")
        * check that the oracle instance is running (sqlplus / as sysdba)
        * under the root user (su - root) run the command for a configuring the network interface (see [Network setup] (#network-setup))
3. On Windows machine install Git Client https://git-scm.com/downloads
4. in the Windows Explorer in the context menu run "Git Bash Here" and then
    * ssh-keygen -t rsa
    * ssh-copy-id oracle@192.168.56.15
    * verify that conectioin is working without a password
        * ssh oracle@192.168.56.15
5. go to the VM Manager, take a snapshot and give it a name "Init"
6. Run the demo 
    * in the Windows Explorer run "Git Bash Here" then
    * git clone https://github.com/SergeyRudyshin/gtbuild_ora_walkthrough.git
    * cd gtbuild_ora_walkthrough
    * bash gtbuild_ora_walkthrough.sh "oracle@192.168.56.15" "/c/Program Files/Oracle/VirtualBox/VBoxManage"

#### Network setup

``` shell
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
NM_CONTROLLED=no
BOOTPROTO=none
ONBOOT=yes
IPADDR=192.168.56.15
NETMASK=255.255.255.0
DEVICE=eth0
PEERDNS=no
EOF
```
