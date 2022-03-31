#!/usr/bin/perl -w
unshift (@INC,"/home/scriptid/scripts/BACKUPS/SUBROUTINES");
require append_group;
require check_backups_on_other_server;
require handle_nsradmin_line_continuations;
require is_client_running_jobquery;
require pinger;
require remove_clients_from_group;
require resolv_name;
require start_group;
require stop_group;
require testport;
require update_group;

$print_only = 1;
if (defined $ARGV[0]) {
   if ( $ARGV[0] =~ /print/ ) {
      $print_only = 0;
      print "You have chosen to just get printed output and not upgrade groups\n";
      print "Is this correct (y or n) ";
      $input = <STDIN>;
      chomp $input;
      if ($input =~ /[Yy]/) {
         print "Continuing\n";
      } else {
        $print_only = 1;
      }
   }
}
# Used to determine which fulls failed from the previous Friday
# Peter Reed (aVenture)
# 11 29, 2016
# 1.08
# Comment Fields
#	F:;	Expected size of Fulls
#	A:;	AFTD
#	D:;	Decom
#	L:	Linux
#	U:	UNIX
#	V:	VMS
#	W:	Windows
#	P:	Peoduction
#	I:	Ignore

$date = `date '+%Y%M%D_%H%M%S'`;
$date = `/usr/bin/date '+%y%m%d%H%M%S'`;
chomp $date;
$networker = `/usr/bin/hostname`;
chomp $networker;
$filename = "/home/scriptid/scripts/BACKUPS/full_reports/$networker\_$date";
if ($print_only == 0) { print "Output filename=$filename\n";}
open (FAILMAIL,">$filename") or  die "Could not open $filename\n";
$FAILADDRS="peter.reed.ctr\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil cody.p.crawford.ctr\@navy.mil";
#$FAILADDRS="peter.reed.ctr\@navy.mil  jeffrey.l.rodriguez.ctr\@navy.mil cody.p.crawford.ctr\@navy.mil";
#$FAILADDRS="peter.reed.ctr\@navy.mil";
print FAILMAIL "/usr/bin/mailx -s 'Backup Failures for $date on $networker' $FAILADDRS <<ENDMAIL\n";

# Get a list of clients enabled on the other server
$alternate = 'sscprodeng';
if ($networker eq 'sscprodeng') {$alternate = 'sscprodeng2'};
check_backups_on_other_server($alternate);

# Check to see which clients are still running
my ($run) = is_client_running_jobquery($networker,$alternate);

# Stop the two groups
print "Stopping groups and waiting 15 minutes\n";
$return =  stop_group($networker, 'Automated-NON-PROD-Reruns');
$return =  stop_group($networker, 'Automated-NON-PROD-VADP-Reruns');
$return =  stop_group($networker, 'Automated-PROD-Reruns');
$return =  stop_group($networker, 'Automated-PROD-VADP-Reruns');
# Wait 15 minutes to handle VADP
#$wait_time = 15 * 60;
#sleep($wait_time);

# Remove clients from the group
print "Removing clients from groups\n";
$ggroup = 'Automated-NON-PROD-Reruns';
$return =  remove_clients_from_group($networker, $ggroup);
$ggroup = 'Automated-NON-PROD-VADP-Reruns';
$return =  remove_clients_from_group($networker, $ggroup);
$ggroup = 'Automated-PROD-VADP-Reruns';
$return =  remove_clients_from_group($networker, $ggroup);
$ggroup = 'Automated-PROD-Reruns';
$return =  remove_clients_from_group($networker, $ggroup);
# Determine the group, backup command, and scheduled backup
my $nsrpass = ". type:NSR client'\n'show name\\;group\\;backup command\\;scheduled backup\\;comment\\;action'\n'print";
print "Before nsradmin\n";
#(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $networker -i -`;
(@return) = handle_nsradmin_line_continuations($networker, $nsrpass);
print "After nsradmin on $networker\n";
# Client name  is mixed case so lower case the names
print "Determing regular/VADP, Prod/Non Prod, Scheduled/Not scheduled on $networker\n";
$cc = 0;
foreach $val (@return) {
   chomp $val;
   $val =~ s/\;//;
   next if $val =~ /^\s*$/;
   if ($val =~ /name:/) {
      $val =~ s/\s*name: //;
      $name = lc($val);
   } elsif ($val =~ /backup command/) {
      $val =~ s/\s*backup command: //;
      $backup_command{$name} = grep (/nsrvadp/,$val);
   } elsif ($val =~ /group/) {
      $val =~ s/\s*group: //;
      $group{$name} = $val;
      ## Keep tract of current groups for later
      #$current_groups{$val} = 1;
   }  elsif ($val =~ /scheduled backup/) {
      $val =~ s/\s*scheduled backup: //;
      $scheduled_backup{$name} = $val;
      if ( grep(/Enabled/,$val) ) {
         if (defined $alt{$name}) {
            if ($alt{$name} eq 'Enabled') {
               # Special case for multiple definitions for same client
               print FAILMAIL "*** Client $name is enabled on multiple servers\n";
            } 
         }
      }

   }  elsif ($val =~ /comment/) {
      $val =~ s/\s*comment: //;
      if ($val =~ /\\/) {
         # Continued comment
         $cc = 1;
      } else  {
         $comment{$name} = $val;
      }
   }  elsif ($cc == 1) {
         $comment{$name} = $val;
         $cc = 0;
   }
}
#(@totalsize) = `mminfo -xc,  -m'`;
print "Determing all clients from the last three weeks on server $networker\n"; 
(@backup_clients)=`/usr/sbin/mminfo -$networker -xc, -r client -q 'savetime>three weeks ago' | /usr/bin/sort | /usr/bin/uniq`;
foreach $client (@backup_clients) {
   chomp $client;
   $client = lc($client);
   $grouper{$client} = 1;
}
#/usr/sbin/mminfo -xc, -a -o ct -r client,savetime,name -q 'savetime>last friday,level=full'
print "Determining clients with full backups since last Friday on server $networker\n"; 
(@backup_full) = `/usr/sbin/mminfo -$networker -xc, -a -o ct -r 'client,savetime,totalsize'  -q 'savetime>last friday 8:00,level=full' | /usr/bin/sort | /usr/bin/uniq`;
undef %full_backup;
foreach $val (@backup_full) {
   chomp $val;
   next if ($val=~/lient/);
   next if ($val=~/^\s*$/);
   next if ($val=~/invalid client name/);
   ($client,$savetime,$totalsize) = split(/,/,$val);
   $client = lc($client);
   $key = "$client:$savetime";
   if (defined $server_size{$key}) {
      $server_size{$key} += $totalsize;
   } else {
      $server_size{$key} = $totalsize;
   }
}
# Process through to determine the maximum size backed up in a day
# This is to handle multiple failed fulls
foreach $key (sort keys %server_size) {
   ($client,$savetime) = split(/:/,$key);
   if (defined $full_backup{$client} ) {
      if ( $server_size{$key} >$full_backup{$client} ) {$full_backup{$client} = $server_size{$key}};
   } else {
      # Assume that 3G is smallest server
      $check_size=3000000000;
      if (defined $comment{$client}) {
         if ($comment{$client} =~ /F:/) {
             ($check_size) = $comment{$client} =~ /.*F:(\d*\.*\d*)\;.*/;
             $check_size  = $check_size*1000000;
         }
      }
      if ($server_size{$key} > $check_size) { $full_backup{$client} = $server_size{$key} }
   }
}
####################################################### good to here ****************************************
print "Begin full backup\n";
#foreach $val (sort keys %full_backup) {
#   print "Server = $val, size=$full_backup{$val}\n";
#}
print "Processing Client list\n";
# Loop through the clients
foreach $client (sort keys %grouper) {
   if ( defined $full_backup{$client} ) {next};
   if (defined $running{$client}) {
      print "**** Client $client still running and is being skipped\n";
      print FAILMAIL "*** Client $client still running and is being skipped\n";
      next;
   }
   $ping = pinger($client);
   if ($ping =~ /up/) {
      $port = testport($client,7937);
   } else {
      $port = 'Client not listening';
   }
   if (!defined $comment{$client}) {
      print FAILMAIL "*** Client $client comment not defined\n";  
      $comment{$client} = '';
   }
   $dns = resolv_name($client);
   if ($comment{$client} !~ /D:/) {
      if ($dns =~ /In DNS/) {
         if ($ping =~ /up/) {
            if ($port =~ /Client listening/) {
               #if ( $client =~ /c27eims2cnlap1p/ ) {
               #   print "DEBUG  Client $client, DNS=$dns, Ping=$ping, Port=$port, Scheduled=$scheduled_backup{$client}\n";
               #   print "DEBUG  Client $client, DNS=$dns, Ping=$ping, Port=$port, Scheduled=$scheduled_backup{$client}\n";
               #   if ( !defined $alt{$client} ) {
               #      print "DEBUG Alternative not defined for client $client\n";
               #   } else {
               #      print "DEBUG Client $client,Alternative=$alt{$client}\n";
               #   }
               #   if ( !defined ${$client} ) {
               ##      print "DEBUG Alternative not defined for client $client\n";
               #   } else {
               #      print "DEBUG Client $client,Alternative=$alt{$client}\n";
               #   }
               #}
               if (defined $scheduled_backup{$client}) {
                  if ($scheduled_backup{$client} eq 'Enabled') {
                     $lower = lc($group{$client});
                     next if $lower =~ /decom/;
                     if ( $lower  =~ /prod/) {
                        if ( $backup_command{$client} == 1) {
                          $return = append_group($networker, 'Automated-PROD-VADP-Reruns',$client);
                        } else {
                          $return = append_group($networker, 'Automated-PROD-Reruns',$client);
                        }
                        print FAILMAIL "*** PROD Client $client, no full backups larger than 3G since last Friday, $ping, $dns, $port\n\n";
                     } else {
                        if ( $backup_command{$client} == 1 ) {
                          $return = append_group($networker, 'Automated-NON-PROD-VADP-Reruns',$client);
                        } else {
                          $return = append_group($networker, 'Automated-NON-PROD-Reruns',$client);
                        }
                        print FAILMAIL "*** NON PROD Client $client, no full backups since last Friday, $ping, $dns, $port\n\n";
                     }
                  } else {
                     if ( (!defined $alt{$client} ) || $alt{$client}  eq 'Disabled') {
                        print FAILMAIL "*** Client $client is not scheduled for backups on either server\n\n";
                     }
                  }
               } else {
                  if ( (!defined $alt{$client} ) || $alt{$client}  eq 'Disabled') {
                     print FAILMAIL "*** Client $client is not scheduled for backups on either server\n\n";
                  }
               }
            } else {
               print FAILMAIL "*** Client $client is not listening on port 7937\n\n";
            }
        } else {
            print FAILMAIL "*** Client $client is down\n\n";
        } 
      } else {
         print FAILMAIL "*** Client $client not in DNS\n\n";  
      }
   } else {
         if ( ($ping eq 'down') && ($dns eq 'Not in DNS') && ($port eq 'Client not listening'))  {
            if ( $group{$client} !~ /DECOM/ ) { print FAILMAIL "		Not in DECOM group\n"};
            if ( $scheduled_backup{$client} eq 'Enabled') { print FAILMAIL "		Not disabled\n"};
         } else {
            print FAILMAIL "*** Client $client is marked as DCOM'd, $ping, $dns, $port\n"; 
         }
   }
}
# Start the groups
print "Starting  groups and waiting 15 minutes\n";
$return =  start_group($networker, 'Automated-NON-PROD-Reruns');
$return =  start_group($networker, 'Automated-NON-PROD-VADP-Reruns');
$return =  start_group($networker, 'Automated-PROD-Reruns');
$return =  start_group($networker, 'Automated-PROD-VADP-Reruns');

# Send email
print FAILMAIL "ENDMAIL\n";
$return = `/usr/bin/sh  $filename  > /dev/null 2>&1`;
gee) = @_;
   $up = 'down';
   # Test to see if machine is up
   $ping = `/usr/sbin/ping  $pingee   5 2>/dev/null`;
   if ($ping =~ /is alive/) {$up=' up'};
   return $up;
}
sub testport{
   ($host,$port) = @_;
   use IO::Socket;
   $| = 1;  # Flush Buffer immediately
   $socket = IO::Socket::INET->new(PeerAddr => $host, PeerPort =>$port, Timeout => 5);
   if ($socket) {
      $return = "  Client listening";
   } else {
      $return = "Client not listening";
   }
}

sub resolv_name {
    my ($check) = @_;
    $return = "Not in DNS";
    push(@DNS,'192.168.104.240','192.168.104.241','192.168.104.56','192.168.104.57');
    push(@SUF,'sscnola.oob','sscnola.oob','cdc.local','cdc.local');
    my $index =-1;
    foreach $dns (@DNS) {
       $index+=1;
       my (@dum) = `/usr/sbin/nslookup $check.$SUF[$index] $dns`;
       $bc =0;
       foreach $val (@dum) {
         #$val =~ s/\s//g;
         chomp $val;
         if ( $bc == 1 ) {
            if ( $val =~ /Address:/ ) {
               $return = "  In DNS";
               goto RETURN;
            } else {
               print FAILMAIL "***  problem in nslookup\n";
            }
         }
         if ($val =~ /can't find $check/ ) {
            goto RETURN;
         } elsif ($val =~ /Name:/) {
           $bc=1;
         }
       }
    }
    RETURN:
    return $return;
}
sub append_group {
    my ($group,$clnt) = @_;
    #my $a = 1;
    #if ($a == 1) {return};
    #foreach $clnt (@clients) {
      chomp $clnt;
      print FAILMAIL "\n*** Client=$clnt added to group $group on $networker\n";;
      # Create clients in $group and INDEX ignoring the current group
      my $nsrpass =  ". type: NSR client\\;name:$clnt'\n'append group:$group'\n'";
      #if ($print_only == 1) {(@return) = `/usr/bin/echo $val | /usr/sbin/nsradmin -i - `};
      if ($print_only == 1) {(@return) = handle_nsradmin_line_continuations($nsrpass)};
#      foreach $vvv (@return) {
#         print "INFO: $vvv\n";
#      }
    #}
}
sub update_group {
    ($grp,$list,%group) = @_;
    my (@clients) = split(/:/,$list);
    my ($clnt);
    foreach $clnt (@clients) {
      print "Client in update group=$clnt\n";
      # Create clients in $group and INDEX ignoring the current group
      if (!defined $group{$clnt}) {
         print RAP "GROUP_MOVE - backup client $clnt doesn't exist in group $grp\n";
         print FAILMAIL  "*** GROUP_MOVE - backup client $clnt doesn't exist in group $grp\n";
      } else {
         next if $group{$clnt} =~ /$grp/;
         print RAP "GROUP_MOVE - client $clnt moved from group $group{$clnt} to group $grp\n";
         print FAILMAIL "--> GROUP_MOVE - client $clnt moved from group $group{$clnt} to group $grp\n";
         print "GROUP_MOVE - client $clnt moved from group $group{$clnt} to group $grp\n";
         my $nsrpass =  ". type: NSR client\\;name:$clnt'\n'update group:INDEX, $grp'\n'";
         if ($print_only == 1) {(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i - `};
#         foreach $vvv (@return) {
#            print RAP "\tINFO: $vvv\n";
#         }
      }
    }
}

sub start_group {
    ($group) = @_;
    $nsrpass = ". type: NSR group\\;name:$group'\n'update autostart:start now'\n'";
    #print "In start group val=$val\n";
    if ($print_only == 1) {(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i - `};
}
sub stop_group {
    ($group) = @_;
    $nsrpass = "\. type: NSR group\\;name:$group'\n'option hidden'\n'update stop now:True'\n'";
    #print "In stop group val=$nsrpass\n";
    if ($print_only == 1) {(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i - `};
}


sub remove_clients_from_group {
    ($pgroup) = @_;
    my $group = $pgroup;
    $nsrpass_remove =  "\. type: NSR client\\;group:$group'\n'show name\\;group'\n'print'\n'";
    (@return) = handle_nsradmin_line_continuations($nsrpass_remove);
    $grp = '';
    #foreach $vvv (@return) {
    #  print "vvv=$vvv\n";
    #}

    foreach $val (@return) {
      chomp $val;
      if ($val =~ /No resources found for query/) {
         # There are no client in the group
         undef $client;
         return;
      }
      next if $val =~ /type: NSR client\;/;
      next if $val =~ /Current query set/;
      $val =~ s/^\s*//;  # Take off leading spaces
      $val =~ s/\;//;    # Take off trailing semi
      $val =~ s/\;//;    # Take off trailing semi
      next if $val =~ /^\s*$/;
      if ($val =~ /name:/) {
         #print "\nFound name=$val***\n";
         if (defined $client) {
            if ($grp =~ /^$group/) {
               $grp =~ s/$group, //;
            } else {
               $grp =~ s/, $group//;
            }
            #print "GRP=$grp***\n";
            $nsrpass =  "\. type: NSR client\\;name:$client'\n'update group:$grp'\n'";
            #print "NSRPASS in remove_clients_from_group=$nsrpass\n";
            if ($print_only == 1) {(@return1) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i - `};
            # foreach $vall (@return1) {
            #     print "Returned $vall";
            # }
         }
         ($client) = ($val =~ /name: (\S+)$/);
      } elsif ($val =~ /group/) {
         ($val) =~ s/group: //;
         $grp = $val;
      } else  {
         print "*******************************Error**********************************\n";
      }
    }
    if (defined $client) {
       if ($grp =~ /^$group/) {    # group at beginning
          $grp =~ s/$group[, ]*//;
          $grp =~ s/, $group//g;   # all other matches on the line
       } else {
          $grp =~ s/, $group//g;   # all other groups
       }
       $nsrpass =  "\. type: NSR client\\;name:\'$client\''\n'update group:$grp'\n'";
       print "NSRPASS=$nsrpass\n";
       if ($print_only == 1) {(@return1) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i - `};
#        foreach $vall (@return1) {
#            print "Bottom Returned $vall";
#        }
    }
}


sub check_backups_on_other_server {
   ($alter) = @_;
   my $nsrpass = ". type:NSR client'\n'show name\\;scheduled backup\\;action'\n'print";
   my (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $alter  -i -`;
   foreach $val (@return) {
      chomp $val;
      $val =~ s/\;//;
      next if $val =~ /^\s*$/;
      if ($val =~ /name:/) {
         $val =~ s/\s*name: //;
         $name = lc($val);
      }  elsif ($val =~ /scheduled backup/) {
         $val =~ s/\s*scheduled backup: //;
         $alt{$name} = $val;
      }
   }
#   foreach $val (sort keys %alt) {
#      print "Name=$val, scheduled=$alt{$val}\n";
#   }
}

sub handle_nsradmin_line_continuations {
   ($nsrpass) = @_;
   undef @combined;
   my (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i -`;
   $output_rec = 0;
   $combined[0] = '';
   $continue = 0;
   # Do it easy
   for ($i = 0;$i<=$#return;$i++) {
      chomp $return[$i];
      next if $return[$i] =~ /Current query set/;
      if ($return[$i] =~ /No resources found for query/) {
         $combined[0]="No resources found for query";
         goto RETURN;
      }
      # The addition is to handle multiline groups and there is space between last group and end of line
      #if line ends with , instead of ; then we have a continuation
      #if ( $return[$i] =~ /\\$/  || $return[$i] =~ /,\s*$/) {
      if ( $return[$i] =~ /,\s*$/ ) {

         #  Current line has a continuation so don't close out
         $return[$i] =~ s/\\//;
         $continue = 1;
         if (defined $combined[$output_rec]) {
            $return[$i] =~ s/^\s+//;
            $combined[$output_rec] = $combined[$output_rec] . $return[$i];
         } else {
            $combined[$output_rec] = $return[$i];
         }
      } else {
         if ($continue == 1) {
            #working on a record so append it and start new record for next;
            $return[$i] =~ s/^\s+//;
            $combined[$output_rec] = $combined[$output_rec] . $return[$i];
         } else {
            $combined[$output_rec] = $return[$i];
         }
         $output_rec +=1;
         $continue = 0;
      }
   }
   undef @return;
   #foreach $ppp (@combined) {
   #   print "In handle:$ppp\n";
   #}
   RETURN: return @combined;
}


sub is_client_running_jobquery {
   ($networker,$alternate) = @_;
   # Determine if the client is still running from other groups
   # Need to save the time also since the process returns multiple entries
   print "Determining running sessions\n";

   $nsrpass = ". type: save job\\; job state: SESSION ACTIVE'\n'show NW Client name/id'\n'print";
   foreach $server ($networker,$alternate) { 
      (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/jobquery -s $server -i - 2>&1`;
      foreach $val (@return) {
         next if $val=~/Current query set/;
         next if $val=~/No resources found for query/;
         next if $val=~/type: save job/;
         next if $val=~/job state: SESSION ACTIVE/;
         next if $val=~/^\s*$/;
         $val =~ s/^\s+NW Client name\/id: //;
         $val =~ s/\;//;
         $val = lc $val;
         $running{$val} = 1;
         # print "Session Active=$val";
      }
   }

   $nsrpass = ". type: save job\\; job state: ACTIVE'\n'show NW Client name/id'\n'print";
   foreach $server ($networker,$alternate) { 
      (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/jobquery -s $server -i - 2>&1`;
      foreach $val (@return) {
         next if $val=~/Current query set/;
         next if $val=~/No resources found for query/;
         next if $val=~/type: save job/;
         next if $val=~/job state: ACTIVE/;
         next if $val=~/^\s*$/;
         $val =~ s/^\s+NW Client name\/id: //;
         $val =~ s/\;//;
         $val = lc $val;
         $running{$val} = 1;
         # print "Active=$val";
      }
   }

   $nsrpass = ". type: save job\\; job state: QUEUED'\n'show NW Client name/id'\n'print";
   foreach $server ($networker,$alternate) {
      (@return) = `/usr/bin/echo $nsrpass | /usr/sbin/jobquery -s $server -i - 2>&1`;
      foreach $val (@return) {
         next if $val=~/Current query set/;
         next if $val=~/No resources found for query/;
         next if $val=~/type: save job/;
         next if $val=~/job state: QUEUED/;
         next if $val=~/^\s*$/;
         $val =~ s/^\s+NW Client name\/id: //;
         $val =~ s/\;//;
         $val = lc $val;
         $running{$val} = 1;
         # print "QUEUED=$val";
      }
   }
}
