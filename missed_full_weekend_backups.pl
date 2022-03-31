#!/usr/bin/perl -w
unshift (@INC,"/home/scriptid/scripts/BACKUPS/SUBROUTINES");
require append_group;
require build_output_record;
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
%prod_numeric_groups = (
	"123" => "p",
	"173" => "p",
	"183" => "p",
	"193" => "p",
	"214" => "p"
 );

# If print is set to 'print' then clients will not be moved the changes will just be documented
if (-t STDIN && -t STDOUT) { 
   print "Do you want to make changes or just see what would be changed.  Make changes (Y or N): ";
   $iyorn = <STDIN>;
   chomp $iyorn;
   if ($iyorn =~ /^[Yy]/) {
      $print_only = 1;
   } else {
      $print_only = 0;
   } 
} else {
   
   $print_only = 1;
   if (defined $ARGV[0]) {
      if ( $ARGV[0] =~ /print/ ) {$print_only = 0};
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

# Get the current time
$seconds_from_1970 = time;
my ($sec,$min,$hr,$mday,$mon,$yr,$wday) = (localtime($seconds_from_1970))[0,1,2,3,4,5,6];
++$mon;
$yr = $yr+1900;
#$thisday= (Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
# This program is used to check weekend backups starting from Thursday at 16:00.
# Auto set to plan only if it is before Saturday at 8:00 am so that all Dev should be finished.
# If it is Sunday after 8:00 am  Dev and Prod should be donew
# If it is Monday after 8:00 am then Dev prod and test should be finished
# Auto starts are at 14:00 on Sunday and 6:00 on Monday
$dev = $prod = $test =0;
if ($wday > 4) {$dev = 1};
if ($wday > 5) {$prod = 1};
if ($wday == 0) {$dev = $prod = $test = 1};
#if ($wday > 1 && $wday < 5) {$print_only = 0};



$networker = `/usr/bin/hostname`;
chomp $networker;
$filename = "/home/scriptid/scripts/BACKUPS/full_reports/$networker\_$date";
print "*************************Filename=i$filename\n";
#if ($print_only == 1) {
   print "Output filename=$filename\n";
   open (FAILMAIL,">$filename") or  die "Could not open $filename\n";
   #$FAILADDRS="peter.reed.ctr\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil cody.p.crawford.ctr\@navy.mil blake.arcement.ctr\@navy.mil";
   $FAILADDRS="peter.reed.ctr\@navy.mil  jeffrey.l.rodriguez.ctr\@navy.mil";
   #$FAILADDRS="peter.reed.ctr\@navy.mil";
   print FAILMAIL "/usr/bin/mailx -s 'Backup Failures for $date on $networker' $FAILADDRS <<ENDMAIL\n";
#}

# Get a list of clients enabled on the other server
$alternate = 'sscprodeng';
if ($networker eq 'sscprodeng') {$alternate = 'sscprodeng2'};
(%alt) = check_backups_on_other_server($alternate);

# Check to see which clients are still running
(%running) = is_client_running_jobquery($networker,$alternate);

# Stop the groups
$print_only = 1;
if ($print_only == 1) {
   print "Stopping groups and waiting 15 minutes\n";
   $return =  stop_group($networker, 'Automated-NON-PROD-Reruns');
   $return =  stop_group($networker, 'Automated-NON-PROD-VADP-Reruns');
   $return =  stop_group($networker, 'Automated-PROD-Reruns');
   $return =  stop_group($networker, 'Automated-PROD-VADP-Reruns');

   # Remove clients from the group
   print "Before nsradmin\n";
   $ggroup = 'Automated-NON-PROD-Reruns';
   $return =  remove_clients_from_group($networker, $ggroup);
   $ggroup = 'Automated-NON-PROD-VADP-Reruns';
   $return =  remove_clients_from_group($networker, $ggroup);
   $ggroup = 'Automated-PROD-VADP-Reruns';
   $return =  remove_clients_from_group($networker, $ggroup);
   $ggroup = 'Automated-PROD-Reruns';
   $return =  remove_clients_from_group($networker, $ggroup);
}

# Determine the group, backup command, and scheduled backup
my $nsrpass = ". type:NSR client'\n'show name\\;group\\;backup command\\;scheduled backup\\;comment\\;action'\n'print";
(@return) = handle_nsradmin_line_continuations($networker,$nsrpass);
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
               if ($print_only == 1) {print FAILMAIL "*** Client $name is enabled on multiple servers\n"};
               $return1 = build_output_record(-90,$output,$name,18,0,-1,-1 ,'',1,18);
               $return1 = build_output_record(0,$output,'ERROR',10,0,1,1 ,'',19,29);
               $return1 = build_output_record(0,$output,'Client enabled on multiple servers',61,0,0,0 ,'',32,105);
               print "$return1\n";
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
(@backup_clients)=`/usr/sbin/mminfo -s $networker -xc, -r client -q 'savetime>8 weeks ago' | /usr/bin/sort | /usr/bin/uniq`;
foreach $client (@backup_clients) {
   chomp $client;
   $client = lc($client);
   $grouper{$client} = 1;
}
print "Determining clients with full backups since last Friday on server $networker\n"; 
#(@backup_full) = `/usr/sbin/mminfo -s $networker -xc, -a -o ct -r 'client,savetime,totalsize'  -q 'savetime>05/24/2019 16:00,level=full' | /usr/bin/sort | /usr/bin/uniq`;
(@backup_full) = `/usr/sbin/mminfo -s $networker -xc, -a -o ct -r 'client,savetime,totalsize'  -q 'savetime>last friday 00:00,level=full' | /usr/bin/sort | /usr/bin/uniq`;
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
print "Processing Client list\n\n\n";
if ($print_only ==0) {
   $return = build_output_record(-105,$output,'*** THIS IS INFORMATIONAL, CLIENTS ARE NOT BEING MOVED ****',59,0,0,0 ,'',1,105);
   print "\n\n$return\n";
}
$return1 = build_output_record(-90,$output,'CLIENT',18,0,-1,-1 ,'',1,18);
$return1 = build_output_record(0,$output,'LEVEL',10,0,1,1 ,'',19,29);
$header1= build_output_record(0,$output,'MESSAGE',61,0,0,0 ,'',32,105);
print "\n\n$header1\n";
$return1 = build_output_record(-105,$output,'------',18,0,-1,-1 ,'',1,18);
$return1 = build_output_record(0,$output,'-----',10,0,1,1 ,'',19,29);
$hyphen = '-' x 70;
$header1= build_output_record(0,$output,$hyphen,70,0,0,0 ,'',32,105);
print "$header1\n";
# Loop through the clients
foreach $client (sort keys %grouper) {
   if ( defined $full_backup{$client} ) {next};
   if (defined $running{$client}) {
      if ($print_only == 1) {print FAILMAIL "*** Client $client still running and is being skipped\n"};
      $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
      $return1 = build_output_record(0,$output,'WARN',10,0,1,1 ,'',19,29);
      $return1 = build_output_record(0,$output,'Backups are still running and is being skipped',60,0,0,0 ,'',32,105);
      print "$return1\n";
      next;
   }
   $tclient = $client;
   $ping = pinger($tclient);
   if ($ping =~ /up/) {
      $port = testport($tclient,7937);
   } else {
      $port = 'Client not listening';
   }
   if (!defined $comment{$client}) {
      if ($print_only == 1) {print FAILMAIL "*** Client $client comment not defined\n"};  
      $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
      $return1 = build_output_record(0,$output,'WARN',10,0,1,1 ,'',19,29);
      $return1 = build_output_record(0,$output,'The Client comment is not defined',61,0,0,0 ,'',32,105);
      print "$return1\n";
      $comment{$client} = '';
   }
   $dns = resolv_name($tclient);
   if ($comment{$client} !~ /D:/) {
      if ($dns =~ /In DNS/) {
         if ($ping =~ /up/) {
            if ($port =~ /Client listening/) {
               if (defined $scheduled_backup{$client}) {
                  if ($scheduled_backup{$client} eq 'Enabled') {
                     $lower = lc($group{$client});
                     next if $lower =~ /decom/;
                     $ping =~ s/\s\s//;
                     $dns =~ s/\s\s//;
                     $port =~ s/\s\s//;
                     $pre = ' ';
                     ($pre)  = ($lower =~ m/^.*(\d\d\d)vlan.*$/);
                     if (!defined $pre) {
                        $pre = ' ';
                     } else {
                        if (!defined  $prod_numeric_groups{$pre} ) {
                           print "\n\n**************** VLAN $pre not defined **************\n";
                           if (defined $missing_vlan{$pre}) {
                              $missing_vlan{$pre} += 1;
                           } else {
                              $missing_vlan{$pre} = 1;
                           }
                        }
                     }
                     #print "PRE=$pre\n";
                     if ( $lower  =~ /prod/ || defined $prod_numeric_groups{$pre} ) {
                        if ( $backup_command{$client} == 1) {
                          $return = append_group($networker, 'Automated-PROD-VADP-Reruns',$client);
                          $return1 = build_output_record(-100,$output,$client,18,0,-1,-1 ,'',1,18);
                          $return1 = build_output_record(0,$output,'INFO',10,0,1,1 ,'',19,29);
                          $return1 = build_output_record(0,$output,"Added to Automated-PROD-VADP-Reruns $ping, $dns, $port",70,0,0,0 ,'',32,105);
                          print "$return1\n";
                        } else {
                          $return = append_group($networker, 'Automated-PROD-Reruns',$client);
                          $return1 = build_output_record(-100,$output,$client,18,0,-1,-1 ,'',1,18);
                          $return1 = build_output_record(0,$output,'INFO',10,0,1,1 ,'',19,29);
                          $return1 = build_output_record(0,$output,"Added to group Automated-PROD-Reruns $ping, $dns, $port",70,0,0,0 ,'',32,105);
                          print "$return1\n";
                        }
                        if ($print_only == 1) {print FAILMAIL "*** PROD Client $client, no full backups larger than 20G since last Friday, $ping, $dns, $port\n\n"};
                     } else {
                        if ( $backup_command{$client} == 1 ) {
                          $return = append_group($networker, 'Automated-NON-PROD-VADP-Reruns',$client);
                          $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
                          $return1 = build_output_record(0,$output,'INFO',10,0,1,1 ,'',19,29);
                          $return1 = build_output_record(0,$output,"Added to group Automated-NON-PROD-VADP-Reruns",61,0,0,0 ,'',32,105);
                          print "$return1\n";
                        } else {
                          $return = append_group($networker, 'Automated-NON-PROD-Reruns',$client);
                          $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
                          $return1 = build_output_record(0,$output,'INFO',10,0,1,1 ,'',19,29);
                          $return1 = build_output_record(0,$output,"Added to group Automated-NON-PROD-Reruns",61,0,0,0 ,'',32,105);
                          print "$return1\n";
                        }
                        if ($print_only == 1) {print FAILMAIL "*** NON PROD Client $client, no full backups larger than 20G since last Friday, $ping, $dns, $port\n\n"};
                     }
                  } else {
                     if ( (!defined $alt{$client} ) || $alt{$client}  eq 'Disabled') {
                        if ($print_only == 1) {print FAILMAIL "*** Client $client is not scheduled for backups on either server\n\n"};
                        $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
                        $return1 = build_output_record(0,$output,'ERROR',10,0,1,1 ,'',19,29);
                        $return1 = build_output_record(0,$output,"Client is not scheduled for backups on either server",61,0,0,0 ,'',32,105);
                        print "$return1\n";
                     }
                  }
               } else {
                  if ( (!defined $alt{$client} ) || $alt{$client}  eq 'Disabled') {
                     if ($print_only == 1) {print FAILMAIL "*** Client $client is not scheduled for backups on either server\n\n"};
                     $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
                     $return1 = build_output_record(0,$output,'ERROR',10,0,1,1 ,'',19,29);
                     $return1 = build_output_record(0,$output,"Client is not scheduled for backups on either server",61,0,0,0 ,'',32,105);
                     print "$return1\n";
                  }
               }
            } else {
               if ($print_only == 1) {print FAILMAIL "*** Client $client is not listening on port 7937\n\n"};
               $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
               $return1 = build_output_record(0,$output,'ERROR',10,0,1,1 ,'',19,29);
               $return1 = build_output_record(0,$output,"Client is not listening on port 7937, $dns, $ping",61,0,0,0 ,'',32,105);
               print "$return1\n";
            }
        } else {
            if ($print_only == 1) {print FAILMAIL "*** Client $client is down, $dns, $port\n\n"};
            $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
            $return1 = build_output_record(0,$output,'WARN',10,0,1,1 ,'',19,29);
            $return1 = build_output_record(0,$output,"Client is down, $dns, $port",61,0,0,0 ,'',32,105);
            print "$return1\n";
        } 
      } else {
         if ($print_only == 1) {print FAILMAIL "*** Client $client not in DNS\n\n"};  
         $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
         $return1 = build_output_record(0,$output,'ERROR',10,0,1,1 ,'',19,29);
         $return1 = build_output_record(0,$output,"Client is not in DNS, $ping, $port",61,0,0,0 ,'',32,105);
         print "$return1\n";
      }
   } else {
         if ( ($ping eq 'down') && ($dns eq 'Not in DNS') && ($port eq 'Client not listening'))  {
            if ( $group{$client} !~ /DECOM/ ) { 
              if ($print_only == 1) { print FAILMAIL "		Not in DECOM group\n"};
              $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
              $return1 = build_output_record(0,$output,'ERROR',10,0,1,1 ,'',19,29);
              $return1 = build_output_record(0,$output,"Client is not in DECOM group",61,0,0,0 ,'',32,105);
              print "$return1\n";
            } 
            if ( $scheduled_backup{$client} eq 'Enabled') { 
              if ($print_only == 1) {print FAILMAIL "		Not disabled\n"};
              $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
              $return1 = build_output_record(0,$output,'WARN',10,0,1,1 ,'',19,29);
              $return1 = build_output_record(0,$output,"Client is not disabled",61,0,0,0 ,'',32,105);
              print "$return1\n";
            }
         } else {
            if ($print_only == 1) {print FAILMAIL "*** Client $client is marked as DCOM'd, $ping, $dns, $port\n"}; 
            $return1 = build_output_record(-90,$output,$client,18,0,-1,-1 ,'',1,18);
            $return1 = build_output_record(0,$output,'WARN',10,0,1,1 ,'',19,29);
            $return1 = build_output_record(0,$output,"Client is marked as DCOM'd $ping, $dns, $port",61,0,0,0 ,'',32,105);
            print "$return1\n";
         }
   }
}
# Start the groups
#if ($print_only == 1) {
#   print "Starting  groups and waiting 15 minutes\n";
#   $return1 =  start_group($networker, 'Automated-NON-PROD-Reruns');
#   $return1 =  start_group($networker, 'Automated-NON-PROD-VADP-Reruns');
#   $return1 =  start_group($networker, 'Automated-PROD-Reruns');
#   $return1 =  start_group($networker, 'Automated-PROD-VADP-Reruns');
#
   # Send email
   print FAILMAIL "ENDMAIL\n";
   foreach $val (sort keys %missing_vlan) {
      print "VLAN $val has $missing_vlan{$val} hosts\n"; 
   }
#}
#$return = `/usr/bin/sh  $filename  > /dev/null 2>&1`;
