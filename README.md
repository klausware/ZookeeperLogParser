# ZookeeperLogParser

# Usage

~# gawk -f zk72.awk <path/to/zookeeper.log>

# Purpose

The goal of this script is the scrape information from Zookeeper logs such as:
  * System info
    - Architecture
    - OS version
    - Username
    - User home dir
    - Zookeeper version
  * ZK node Id
  * ZK Pass hash
  * Read-only occurrences
  * Java exceptions
  * Fsync times
  
Perhaps the most valuable aspect is the calculation of all ZK election times and their results. This script can be run on each ZK node in an ensemble, and the results will yield which nodes were followers, and which node was leader, for each election. This helps with correlating logs and the state of each ZK node when troubleshooting.


