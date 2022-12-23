#!/bin/bash
#
# Last update 11 November 2020 by Peter Schmiedeskamp and Ido Michael
# Based on earlier work by Tom Zeng

set -x -e

# Desired R release version
rver=4.0.3

# Desired R Studio package
rspkg=rstudio-server-rhel-1.3.1093-x86_64.rpm

# Password for R Studio user "hadoop"
rspasswd=hadoop

# Check whether we're running on the main node
main_node=false
if grep isMaster /mnt/var/lib/info/instance.json | grep true;
then
main_node=true
fi

# install some additional R and R package dependencies
sudo yum install -y bzip2-devel cairo-devel \
gcc gcc-c++ gcc-gfortran libXt-devel \
libcurl-devel libjpeg-devel libpng-devel \
libtiff-devel pcre2-devel readline-devel \
texinfo texlive-collection-fontsrecommended

# Compile R from source; install to /usr/local/*
mkdir /tmp/R-build
cd /tmp/R-build
curl -OL https://cran.r-project.org/src/base/R-4/R-$rver.tar.gz
tar -xzf R-$rver.tar.gz
cd R-$rver
./configure --with-readline=yes --enable-R-profiling=no --enable-memory-profiling=no --enable-R-shlib --with-pic --prefix=/usr/local --with-x --with-libpng --with-jpeglib --with-cairo --enable-R-shlib --with-recommended-packages=yes
make -j 8
sudo make install

# Set some R environment variables for EMR
cat << 'EOF' > /tmp/Renvextra
JAVA_HOME="/etc/alternatives/jre"
HADOOP_HOME_WARN_SUPPRESS="true"
HADOOP_HOME="/usr/lib/hadoop"
HADOOP_PREFIX="/usr/lib/hadoop"
HADOOP_MAPRED_HOME="/usr/lib/hadoop-mapreduce"
HADOOP_YARN_HOME="/usr/lib/hadoop-yarn"
HADOOP_COMMON_HOME="/usr/lib/hadoop"
HADOOP_HDFS_HOME="/usr/lib/hadoop-hdfs"
YARN_HOME="/usr/lib/hadoop-yarn"
HADOOP_CONF_DIR="/usr/lib/hadoop/etc/hadoop/"
YARN_CONF_DIR="/usr/lib/hadoop/etc/hadoop/"

HIVE_HOME="/usr/lib/hive"
HIVE_CONF_DIR="/usr/lib/hive/conf"

HBASE_HOME="/usr/lib/hbase"
HBASE_CONF_DIR="/usr/lib/hbase/conf"

SPARK_HOME="/usr/lib/spark"
SPARK_CONF_DIR="/usr/lib/spark/conf"

PATH=${PWD}:${PATH}
EOF
cat /tmp/Renvextra | sudo  tee -a /usr/local/lib64/R/etc/Renviron

# Reconfigure R Java support before installing packages
sudo /usr/local/bin/R CMD javareconf

# Download, verify checksum, and install RStudio Server
# Only install / start RStudio on the main node
if [ "$main_node" = true ]; then
curl -OL https://download2.rstudio.org/server/centos6/x86_64/$rspkg
sudo mkdir -p /etc/rstudio
sudo sh -c "echo 'auth-minimum-user-id=100' >> /etc/rstudio/rserver.conf"
sudo yum install -y $rspkg
sudo rstudio-server start
fi

# Set password for hadoop user for R Studio
sudo sh -c "echo '$rspasswd' | passwd hadoop --stdin"

# Install common R packages, and others used in blog example
sudo /usr/local/bin/R --no-save <<R_SCRIPT
install.packages(c('sparklyr','shiny', 'dplyr', 'ggplot2', 'nycflights13', 'Lahman'),
                 repos="http://cran.rstudio.com")
R_SCRIPT