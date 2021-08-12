#!/bin/awk

#//-----------------------------------------------------------------------------//#
# Author: Nicklaus Koeppen							  #
#										  #	
# Use this script to parse out key information from the Zookeeper logs such as    #
# OS information, unique errors & their counts, lost channel connections to other # 
# nodes, elections & results, and fsync times. This is written for ZK logs with   #
# VDS versions 7.2.x. (aka logs with a 'T' in the timestamp.)			  #
#										  										  #	
#//-----------------------------------------------------------------------------//#

BEGIN{	
	PROCINFO["sorted_in"] = "@val_num_asc"; 
	isVDS72 = "";
	electionCount=0;
	connected=0;
	reconnected=0;
	suspended=0;
	lost=0;
	isROM="";
	max=0;
	onesec=0;
	onetwosec=0;
	twosecplus=0;
	passHash="No value found";
	channelBroken=0;

	}

# Check if the logs are for VDS 7.2.x
	
	$1{

	if(index($1,"T")==11){
		#print "TRUE"
		isVDS72 = "TRUE";
		}
	}		

# Gather System Info:

	/Client environment:os.name=/  {
			
				# get OS Name
				osName = "";
				for (i= 9; i <= NF; i++)
					osName = osName "" $i
					!seen[$0]++
					name[i++]=$0
					#print "The OS Name is: " osName

				}

	/Client environment:os.arch=/	{
				
				# get OS architecture
				osArchitecture = "";
				split($8,a,"=")
				osArchitecture = a[2];
				#print "The OS Architecture is: " osArchitecture

				}

	/Client environment:os.version=/  {
				
				# get OS version
				osVersion = "";
				split($8,a,"=")
				osVersion = a[2];
				#print "The OS Version is: " osVersion

				}

	/Client environment:user.name=/  {

				# get user name being used
				userName = "";
				split($8,a,"=")
				userName = a[2];
				#print "User Name is: " userName		
				
				}

	/Client environment:user.home=/  {

				# get user home directory
				homeDir = "";
				split($8,a,"=")
				homeDir = a[2];
				#print "The User Home Dir is: " homeDir

				}

	/Client environment:user.dir/  {
				
				# get user directory
				userDir = "";
				split($8,a,"=")
				userDir = a[2];
				#print "The user Dir is: " userDir

				}

	/Server environment:zookeeper.version/ {

				# get ZK verion
				ZKversion = "";
				split($8,a,"=")
				temp = a[2];
				split(temp,b,"-")
				zkVersion=b[1];
				}		

	/My id = /			{

				# get ZK node id
				zkID = substr($12,1,1);
				#print "ZK id is: " zkID

				}

	/password/{

		# get ZK password hash
		passHash = $10				
	}


# Gather occurrences of ROM (Read Only Mode):

	/Curator connection state change:/ {

					curatorState[$11]++
					
						
					}
	/VDS-ZK connection state changed:/ {
			
					count[$11]++
					if($11 == "READ_ONLY"){
						isROM = "TRUE";
						ROMcounter++ 
					}					

					}

				
# Gather Number of Occurrences of Errors:

	/java.net.SocketException/ {
	err[$0]++
			}

	/java.lang.InterruptedException/ {

	err[$0]++
			}
	/java.io.IOException: ZooKeeperServer not running/ {

	out="";
	for(i=16;i<=NF;i++){
		out = out " " $i;		
	}
	err[out]++	
	
			}

	/java.io.EOFException/ {
			
	err[$0]++
			}

	/EndOfStreamException/ {
	
	if($10 == "0x0,"){
		err[$0]++
		}	
			}

	/Cannot open channel to/ {
 	channelBroken++
	err[$0]++
	for (i = 1; i <= channelBroken; i++)
		disconnectedSID[channelBroken] = $11
		disconnectedTime[channelBroken] = $1	
	}

	/java.lang.OutOfMemoryError: Java heap space/ {
	
	err[$0]++

	}

	/java.lang.OutOfMemoryError: GC overhead limit exceeded/ {

	err[$0]++

	}

# Gather LEADERSHIP/FOLLOWERSHIP Info:

	
	/New election/{
	electionTime[$1]++
	electionCount++
	
	}

	/- LEADER ELECTION TOOK/{
	for (j = 1; j <= electionCount; j++)
		electionStatus[electionCount] = $7
		
	}

# Check FSYNC-ing metric:

	/fsync-ing/{
	fsync[substr($15, 1, length($15)-2)]++
	}


# Print System Info Only Once 

END  {  

	print"\n"
	print"Check log version:\n"

	if (isVDS72 == "TRUE"){
		print "[+] ZK logs are for VDS72"
		}
	else
		print "[!!!] These ZK logs NOT for VDS72. Script will not work"

	print"+----------------------------------+\n"

	print"ZK ID:\n"

	print"[+] The ZK id is: " zkID

	print"+----------------------------------+\n"

	print"Check for Read Only Mode:\n"

	if(isROM != ""){
		print "[-] SERVER ENTERED ROM STATE " ROMcounter " time(s)"
		}
	else
		print "[+] SERVER NEVER ENTERED ROM STATE"

	print"+----------------------------------+\n"
	print"System Information:\n"

	for (i in name){
		if (seen[name[i]]==1){
			printf("%-24s %s\n", "The OS Name is          :", osName)
			printf("%-24s %s\n", "The OS Architecture is  :", osArchitecture) 
			printf("%-24s %s\n", "The OS Version is       :", osVersion)
			printf("%-24s %s\n", "The User Name is        :", userName)
			printf("%-24s %s\n", "The Home Dir is         :", homeDir)
			printf("%-24s %s\n", "The User Dir is         :", userDir)
			printf("%-24s %s\n", "The ZK password hash is :", passHash)
			printf("%-24s %s\n", "The ZK Version is       :", zkVersion)
		}
		else
			print "no value found."
	}

	print"+----------------------------------+\n"
	print"Error Count and Discovery:\n"
	
	#n=asort(err)
	for (i in err){			
		print "(x"err[i]")" " " i
		}	

	print"+----------------------------------+\n"

	print "Number of times channel was broken: " channelBroken
	for (i = 1; i <= channelBroken; i++)
		print "Couldn't connect to node: " disconnectedSID[i] " at " disconnectedTime[i]


	print"+----------------------------------+\n"
	print"ZK Server Connection Statuses:\n"

	for (word in curatorState)
		print "The ZK server " word " " curatorState[word] " time(s)."
		 
	print"+----------------------------------+\n"
	print"Elections and Statuses:\n"

	n = asorti(electionTime, electionTimeSorted)
	for (time = 1; time <= n; time++)
		print "Election: " time " occurred at " electionTimeSorted[time]
		for (status = 1; status <= length(electionStatus); status++)
			if (electionStatus[status] != "")
				print ">>>>Status for election " status " was: " electionStatus[status]
			else
				print ">>>>Status for election " status " was: [!!!] no status!!. Likely leader election was restarted"

	#WORKING
	#for (j = 1; j <= length(electionStatus); j++)
	#	print "Election Status was: " electionStatus[j]

	print"+----------------------------------+\n"
	print"Fsync Times and Count:\n"
	
	for (f in fsync){
		#print "fsync value: " f
		if (f < 1000){
			onesec++;	
		}
		if (f >= 1000 && f < 2000){
			onetwosec++;
		}
		if (f >= 2000){
			twosecplus++;
		}
	}

	print "[0 - 1000 ms[    : " onesec
	print "[1000 - 2000 ms[ : " onetwosec
	print "[2000+ ms]       : " twosecplus
	print"+----------------------------------+\n"
	
	print "Troubleshooting Suggestions\n"
	
	for (i in err){
		if (i ~ /OutOfMemory/ && i ~ /Java heap space/) { 
                	print i":"
			print "*Check the size of the ZK snapshot file(s) and/or amount of memeory allocated to ZK. (Default 1Gb)\n"
			}
		if (i ~ /OutOfMemory/ && i ~ /GC overhead limit exceeded/) {
                        print i":"
                        print "*Check the size of the ZK snapshot file(s)\n"
                        }
		if (i ~ /Cannot open channel to/) {
			print i":"
			print "*Issue pertains to network connectivity. Check the following:"
			print "--DNS resolution (/etc/hosts file or local DNS server)"
			print "--Are ports 2181, 2888, and 3888 all open in the firewall rules"
			print "--Make sure ping and telnet to the other hosts works"
			print "--Check if the ZK password has been modified recently"
			print "--Use the run.exe/run.sh client to try connecting to the other ZK nodes\n"
			}

                }




	print"+----------------------------------+\n"
	}
	
