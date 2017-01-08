#!/bin/bash

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

VM_SSH="${1:-oracle@192.168.56.15}"
VBM="${2:-VBoxManage}"

source helper.sh

# ssh-copy-id oracle@192.168.56.15
#VM_SSH="oracle@[fe80::a00:27ff:fe16:cc6d]"
#VBM="/c/Program \Files/Oracle/VirtualBox/VBoxManage"

VM_NAME=gtbuildvm

echo ---------------------------------------------------------------------------
echo Create temporary directory
echo download gtbuild and gtbuild_ora_template
echo initializing git repository
echo ---------------------------------------------------------------------------

rm -rf gtbuild.tmp
mkdir -p gtbuild.tmp/tmp gtbuild.tmp/src

cd gtbuild.tmp/src

curl -s -L -o gtbuild.zip              https://github.com/SergeyRudyshin/gtbuild/archive/master.zip
curl -s -L -o gtbuild_ora_template.zip https://github.com/SergeyRudyshin/gtbuild_ora_template/archive/master.zip

unzip -q gtbuild.zip 
unzip -q gtbuild_ora_template.zip

rm gtbuild.zip gtbuild_ora_template.zip

git init &>/dev/null


# ------------------------------------------------------------------------------
prn_header "add a table, insert a record, create an index
create a snapshot of the VM"

git checkout -b first_version &>/dev/null

sed -i -e 's|#component_a|component_a|' -e 's|#patches|patches|' gtbuild_ora_template-master/build.gts

mkdir patches component_a
touch patches/.gitignore

cat <<EOF > component_a/planets.tab
create table planets (
    name varchar2 (100)
);
EOF

cat <<EOF > component_a/planets.dat
-- @depends on: component_a/planets.tab
insert into planets (name) values ('Earth');
commit;
EOF

cat <<EOF > component_a/planets.idx
-- @depends on: component_a/planets.dat
create index planets_name_idx on planets (name);
EOF

git_commit "first_version"

git tag -a -m "first_version_tag" "first_version_tag"

vm_reset "Init"
vm_create_user
build_and_upload
vm_sqlplus_install "full.sql"
vm_snap_take "first_version"


# ------------------------------------------------------------------------------
prn_header "add a new column and check a diff between the full and patch files"

git_reset "first_version"
git checkout -b new_column_correct &>/dev/null

echo "alter table planets add radius number;" > patches/cr_001.sql

cat <<EOF > component_a/planets.tab
create table planets (
    name varchar2 (100),
    radius number
);
EOF

git_commit "new_column_correct"

build_and_upload
vm_sqlplus_install "patch.sql"
vm_state "patch.state"

vm_reset "Init"
vm_create_user
build_and_upload
vm_sqlplus_install "full.sql"
vm_state "full.state"

diff ../tmp/patch.state ../tmp/full.state


# ------------------------------------------------------------------------------
prn_header "simulate situation when the patch is not in sync with the full file"

git_reset "first_version"

git checkout -b new_column_incorrect &>/dev/null

cat <<EOF > component_a/planets.tab
create table planets (
    name varchar2 (100),
    radius number
);
EOF

echo "alter table planets add radius number (1);" > patches/cr_001.sql

git_commit "new_column_incorrect"

vm_reset "first_version"
build_and_upload
vm_sqlplus_install "patch.sql"
vm_state "patch.state"

vm_reset "Init"
vm_create_user
build_and_upload
vm_sqlplus_install "full.sql"
vm_state "full.state"


diff ../tmp/patch.state ../tmp/full.state


# ------------------------------------------------------------------------------
prn_header "simulate invalid object"

git_reset "first_version"

git checkout -b invalid_object &>/dev/null

cat <<EOF > component_a/planets.vw
-- @depends on: component_a/planets.tab
create or replace force view planets_vw
as select id from planets
/
EOF

git_commit "invalid_object"

vm_reset "first_version"
build_and_upload
vm_sqlplus_install "patch.sql" > ../tmp/invalid_object.log

echo "..."
tail ../tmp/invalid_object.log


# ------------------------------------------------------------------------------
prn_header "simulate a conflict on indexes, which would not be catched without the full-file"

git_reset "first_version"

git checkout -b feature_unique_idx &>/dev/null

(echo "drop index planets_name_idx;";
echo "create unique index planets_name_idx on planets (name);") > patches/feature_unique_idx.sql

cat <<EOF > component_a/planets.idx
-- @depends on: component_a/planets.dat
create unique index planets_name_idx on planets (name);
EOF

git_commit "unique_idx"

git_reset "first_version"

git checkout -b feature_new_column_idx &>/dev/null

(echo "drop index planets_name_idx;";
echo "create index planets_name_idx on planets (name, radius);") > patches/feature_new_column_idx.sql

cat <<EOF > component_a/planets.idx
-- @depends on: component_a/planets.dat
create index planets_name_idx on planets (name, radius);
EOF

git_commit "new_column_idx"
git_reset "first_version"
git checkout -b idx_conflict &>/dev/null
git merge feature_new_column_idx
git merge feature_unique_idx


vm_snap_delete "first_version"
