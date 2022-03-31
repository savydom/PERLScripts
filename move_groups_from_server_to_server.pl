#!/usr/bin/perl -w
unshift (@INC,"/home/scriptid/scripts/BACKUPS/SUBROUTINES");
require update_clients_group;
require copy_group;
require copy_client;
require copy_schedule;

$date = `/usr/bin/date '+%y%m%d%H%M%S'`;
chomp $date;
open (RAP,">>/home/scriptid/scripts/BACKUPS/RAP/GroupMove_RAP_$date.log") or die "Could not open /home/scriptid/scripts/BACKUPS/RAP/GroupMove_RAP_$date.log\n";

print "\n\nThis utility is used to move all the clients in a group from one backup\n";
print "\t server to another\n\n";
# What is the source server
print "Enter the name of the source backup server: ";
$source = <STDIN>;
chomp $source;
print "Enter the name of the destination backup server: ";
$destination = <STDIN>;
chomp $destination;
print "Enter a search field to limit the number of groups displayed: ";
$search = <STDIN>;
chomp $search;

# Present a list of groups on the source server
print "\n\nCreating list of groups on source server $source\n\n";
$nsrpass = "\. type: NSR group'\n'show name'\n'print";
(@return) = `/usr/bin/echo $nsrpass  | /usr/sbin/nsradmin -s $source -i -`;
foreach $val (@return) {
   next if $val =~ /Current query set/;
   next if $val =~ /^\s+$/;
   $val =~ s/^\s+name: //;
   $val =~ s/\;$//;
   chomp $val;
   if ($val =~ /$search/) {
      $source_group{$val} = 1; 
      print "$val\n";
   }
}

# Get a list of groups on the destination server
print "\n\nCreating list of groups on destination server $destination\n\n";
$nsrpass = "\. type: NSR group'\n'show name'\n'print";
(@return) = `/usr/bin/echo $nsrpass  | /usr/sbin/nsradmin -s $destination -i -`;
foreach $val (@return) {
   next if $val =~ /Current query set/;
   next if $val =~ /^\s+$/;
   $val =~ s/^\s+name: //;
   $val =~ s/\;$//;
   chomp $val;
   if ($val =~ /$search/) {
      $destination_group{$val} = 1; 
   }
}

NEWGROUP:
(@groups) = keys %source_group;
print "NEWGROUP  $#groups\n";
print "Enter the name of the group to be moved, all,  or exit: ";
$group = <STDIN>;
chomp $group;
if (lc $group =~ /exit/) {exit};
if (lc $group !~ /all/) {
   if (defined $destination_group{$group}) {
      undef @groups;
      print "Just working on one group, $group\n";
      push (@groups,$group);
   } else {
      if (!defined $source_group{$group} ) {
         # Source group doesn't exist
         print "The group you entered $group is not on the $source server\n";
         print "Reenter the group name\n";
         goto NEWGROUP;
      }
   }
}

# Determine if client needs to be created on destination server

print "\n\nCreating list of clients on destination server $destination\n\n";
$nsrpass = "\. type: NSR client'\n'show name'\n'print";
(@return) = `/usr/bin/echo $nsrpass  | /usr/sbin/nsradmin -s $destination -i -`;
foreach $val (@return) {
   next if $val =~ /Current query set/;
   next if $val =~ /^\s+$/;		# Take out blank lines
   $val =~ s/^\s+name: //;		# Strip off everything in front of client name
   $val =~ s/\;$//;			# Take off training semi colon
   chomp $val;				# Take off end of line
   $destination_client{$val} = 1; 	# Save client name in HASH
}

foreach $group (@groups) {
   print "Checking group $group\n";
   if (!defined $destination_group{$group}) {
      print "Group $group doesn't exist on $destination so it will be copied\n";
      copy_group($source, $destination,$group);
   }
   print RAP "INFO: Adding clients to $destination from $source for group $group\n";
   $nsrpass = "\. type: NSR client\\;group:$group'\n'show name'\n'print'\n'";
   #print "NSRPASS: $nsrpass\n";
   print "/usr/bin/echo $nsrpass  | /usr/sbin/nsradmin -s $source -i - \n";
   (@return) = `/usr/bin/echo $nsrpass  | /usr/sbin/nsradmin -s $source -i - `;
   foreach $val (@return) {
      next if $val =~ /Current query set/;
      last if $val =~ /No resources found for query/;
      next if $val =~ /^\s+$/;
      $val =~ s/^\s+name: //;
      $val =~ s/\;$//;
      chomp $val;
      if (defined $destination_client{$val}) {
         print RAP "Adding client $val to $group on $destination\n";
         print "Adding client $val to $group on $destination\n";
         update_clients_group ($destination, $val, $group);
      } else {
         # Copy the client
         copy_client($source,$destination,$val);
      } 
   }
}
goto NEWGROUP;

