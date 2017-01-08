# 
# Copyright 2017 Sergey Rudyshin. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

vm_shell () {
    ssh -o ConnectTimeout=120  "$VM_SSH" "bash -s"
}

build_and_upload () {
    FN=$(bash gtbuild-master/gtbuild.sh "gtbuild_ora_template-master/build.gts")
    scp -o ConnectTimeout=120  $FN "$VM_SSH:~/" &>/dev/null
    echo "rm -rf ~/release; mkdir ~/release; cd ~/release; tar -zxf ../${FN##*/} --warning=no-timestamp ;" | vm_shell
}

vm_sqlplus () {
    (
    echo "source ~/.bash_profile";
    echo "cd ~/release";
    echo 'sqlplus -S gtbuild/gtbuild';
    cat;
    ) | ssh -o ConnectTimeout=120  "$VM_SSH" "bash -s"
}

vm_state () {
    echo "@gtbuild_ora_template-master/state.sql GTBUILD" | vm_sqlplus
    scp -o ConnectTimeout=120  "$VM_SSH:~/release/state.sql.out" ../tmp/$1 &>/dev/null
}

vm_sqlplus_install () {
    (
    echo "source ~/.bash_profile";
    echo "cd ~/release";
    echo 'export THE_USER=GTBUILD';
    echo 'export THE_USER_PASSWORD=gtbuild';
    echo "cat gtbuild_ora_template-master/parameters.sqlplus.tmpl | bash gtbuild_ora_template-master/install_sqlplus.sh $1";
    ) | ssh -o ConnectTimeout=120  "$VM_SSH" "bash -s"
}

vm_reset () {
    "$VBM" controlvm "$VM_NAME" poweroff &>/dev/null
    "$VBM" snapshot "$VM_NAME" restore "$1" &>/dev/null
    "$VBM" startvm  "$VM_NAME" --type  headless &>/dev/null
}

vm_snap_take () {
    "$VBM" snapshot "$VM_NAME" take "$1" &>/dev/null
}

vm_snap_delete () {
    echo "deleting snapshot $1"
    "$VBM" controlvm "$VM_NAME" poweroff &>/dev/null
    "$VBM" snapshot "$VM_NAME" delete "$1" &>/dev/null
}

vm_create_user () {
cat <<EOF | vm_shell &>/dev/null
source ~/.bash_profile
sqlplus -S \/ as sysdba
create user gtbuild identified by gtbuild;
grant dba to gtbuild;
EOF
}

git_reset () {
    git reset --hard HEAD &>/dev/null
    git checkout "$1" &>/dev/null
}

git_commit () {
    git add .
    git commit -am "$1" &>/dev/null
}


prn_header () {
echo 
echo ---------------------------------------------------------------------------
echo "$1"
echo ---------------------------------------------------------------------------
}

