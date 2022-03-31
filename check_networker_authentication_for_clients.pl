#!/usr/bin/perl -w
# This script is used to look for bad servers files on clients
#                        type: NSR peer information;
#               administrator: gbrandt@*, "isroot,host=sscprodeng",
#                              "isroot,host=sscprodeng-bk2",
#                              "isroot,host=sscprodeng-bk2.sscnola.oob",
#                              "isroot,host=sscprodeng-mn",
#                              "isroot,host=sscprodeng-mn.sscnola.oob",
#                              "isroot,host=sscprodeng.sscnola.oob",
#                              "isroot,host=sscprodeng2",
#                              "isroot,host=sscprodeng2-bk2",
#                              "isroot,host=sscprodeng2-bk2.sscnola.oob",
#                              "isroot,host=sscprodeng2-mn",
#                              "isroot,host=sscprodeng2-mn.sscnola.oob",
#                              "isroot,host=sscprodeng2.sscnola.oob", preed@*,
#                              "user=root,host=localhost",
#                              "user=root,host=sscprodeng.sscnola.oob";
#                        name: c27itsmcnlat1w.dc3n.navy.mil;
#               peer hostname: c27itsmcnlat1w.dc3n.navy.mil;
#What is Hidden display option turned on
#What is Display options:
#What is         Dynamic: Off;
#What is         Hidden: On;
#What is         Raw I18N: Off;
#What is         Resource ID: Off;
#What is         Regexp: Off;
unshift (@INC,"/home/scriptid/scripts/BACKUPS/SUBROUTINES");
require build_output_record;
require handle_nsradmin_line_continuations;
$date = `date '+%Y%M%D_%H%M%S'`;
$date = `/usr/bin/date '+%y%m%d%H%M%S'`;
chomp $date;
$networker = `/usr/bin/hostname`;
chomp $networker;
$filename = "/home/scriptid/scripts/BACKUPS/clients/client_auth\_$date";
print "Output filename=$filename\n";
open (FAILMAIL,">$filename") or  die "Could not open $filename\n";
$FAILADDRS="peter.reed.ctr\@navy.mil jeffrey.l.rodriguez.ctr\@navy.mil cody.p.crawford.ctr\@navy.mil blake.arcement.ctr\@navy.mil";
print FAILMAIL "/usr/bin/mailx -s 'Client Auth Data $date on $networker' $FAILADDRS <<ENDMAIL\n";
print FAILMAIL "\n\n  L O C A T E   M I S C O N F I G U R E D   C L I E N T 's  S E R V E R    F I L E\n";
print FAILMAIL "\n\tThe script ignores all entries for sscprodeng2\n";
print FAILMAIL "\n\tThe servers column indicate 's' for sscprodeng,     'S' for fully qualified\n";
print FAILMAIL "\tThe servers column indicate 'm' for sscprodeng-mn,  'M' for fully qualified\n";
print FAILMAIL "\tThe servers column indicate 'b' for sscprodeng-bk2, 'B' for fully qualified\n\n";

#$nsrpass  = ". type:NSR peer information'\n'option hidden'\n'show name'\n'print";
$nsrpass  = ". type:NSR peer information'\n'print";
(@return) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -p 390113 -i -`;
$check = '       ';
foreach $val (@return) {
   chomp $val;
   next if $val =~ /Current query set/;
   next if $val =~ /^\s*$/;
   next if $val =~ /^\s+type:.*$/;
   next if $val =~ /^\s+\"user=root/;
   next if $val =~ /Hidden display option turned on/;
   next if $val =~ /Display options:/;
   next if $val =~ /Dynamic: Off/;
   next if $val =~ /Hidden: On/;
   next if $val =~ /Raw I18N/;
   next if $val =~ /Resource ID/;
   next if $val =~ /Regexp/;
   next if $val =~ /Change certificate/;
   next if $val =~ /certificate file to load/;

   if ($val =~ /isroot,host=/) {
      if ($val =~ /isroot,host=sscprodeng\"/) {
         substr($check,0,1) = "s";
      } elsif ($val =~ /sscprodeng.sscnola.oob\"/) {
         substr($check,1,1) = "S";
      } elsif ($val =~ /sscprodeng-mn\"/) {
         substr($check,2,1) = "m";
      } elsif ($val =~ /sscprodeng-mn.sscnola.oob\"/) {
         substr($check,3,1) = "M";
      } elsif ($val =~ /sscprodeng-bk2\"/) {
         substr($check,4,1) = "b";
      } elsif ($val =~ /sscprodeng-bk2.sscnola.oob\"/) {
         substr($check,5,1) = "B";
      } else {
         next if $val =~ /sscprodeng2/;
         substr($check,6,1) = "*";
         print "Not valid in servers file $val\n";
      }
   } elsif ($val =~ /^\s+name: /) {
         $val =~ s/\;//;
         $val =~ s/^\s+name: //;
         $val = lc $val;
         $client = $val;
         $host = $client;
         if ($client =~ /\./) {
            $client =~ s/\..*$//;
         }
         #print "Client=$client\n";
         $hostname{$client} = lc $host;
         #print "***Hostname:$client***, ****$hostname{$client}****\n";
         $servers{$client} = $check;
         #print "Servers:$client, ***$servers{$client}***\n";
         $check = '       ';
   } elsif ($val =~ /peer hostname/) {
        $peer{$client} = lc $val;
        $peer{$client} =~ s/^\s+peer hostname: //;
        $peer{$client} =~ s/\;//;
        #print "Client:$client, Peer:$peer{$client}\n";
   } else {
        print FAILMAIL "What is $val\n";
   }

}
print "\nBuilding Client aliases\n";
$nsrpass = ". type:NSR client'\n'show name\\;aliases\\;action'\n'print";
#print "NSRPASS = $nsrpass\n";
(@return) = handle_nsradmin_line_continuations($networker,$nsrpass);   # Get list back from nsradmin but concatenate long lines like group and comment
foreach $val (@return) {
   chomp $val;
   next if $val =~ /^\s*$/;
   if ($val =~ /\s+name: / ) {
      $client = $val;
      $client =~ s/^\s*name: //;
      $client =~ s/\;//;
   } elsif ($val =~ /aliases: /) {
      $alias{$client} =$val;
      $alias{$client} =~ s/\s+aliases://;
      $alias{$client} =~ s/\;//;
   }
}
#foreach $val (sort keys %alias) {
#   print "Key=$val, Alias: $alias{$val}\n";
#}
#exit;

print "\n\n";
        # $control      -size  - initialize
        #               1 - insert
        # $output       The output record where the fields are inserted
        # $field        The characters or number value to place in the output record
        # $width        The number of characters to insert in the field
        # $places       The number of decimal places, 0 for character or integer
        # $fjustify     Same as ojustify but justifies with the $width.
        # ojustify      Justifies the width field within the output record
        #               -1 - left justify
        #                0 - center
        #                1 - right justify
        # $comma        comma - insert commas
        #               blank - no comas
        # $start        location in output where insertion begins starting at 1
        # $end          location in output where insertion ends

$return = build_output_record(-106,$output,'CLIENT',20,0,-1,-1 ,'',7,20);
$return = build_output_record(0,$output,'SERVERS',10,0,-1,-1 ,'',23,31);
$return = build_output_record(0,$output,'HOSTNAME',24,0,-1,-1 ,'',43,60);
$return = build_output_record(0,$output,'PEER',4,0,-1,-1 ,'',76,106);
print FAILMAIL "$return\n";
$return = build_output_record(-106,$output,'------',20,0,-1,-1 ,'',7,20);
$return = build_output_record(0,$output,'-------',10,0,-1,-1 ,'',23,31);
$return = build_output_record(0,$output,'--------',24,0,-1,-1 ,'',43,60);
$return = build_output_record(0,$output,'----',4,0,-1,-1 ,'',76,106);
print FAILMAIL "$return\n";
$count = 0;
foreach $key (sort keys %servers) {
   $count += 1;
   $return = build_output_record(-106,$output,"$count)",4,0,1,1 ,'',1,5);
   $return = build_output_record(0,$output,$key,15,0,-1,-1 ,'',7,22);
   $return = build_output_record(0,$output,$servers{$key},7,0,-1,-1 ,'',24,30);
   $return = build_output_record(0,$output,$hostname{$key},40,0,-1,-1 ,'',32,71);
   if ($hostname{$key} ne $peer{$key} ) {
      $return = build_output_record(0,$output,$peer{$key},34,0,-1,-1 ,'',72,106);
   } else {
      $return = build_output_record(0,$output,'S A M E',35,0,-1,-1 ,'',70,106);
   }
      
   print FAILMAIL "$return\n";
   if ($servers{$key} =~ /\*/)          { 
      $return = build_output_record(-80,$output,'*** Bad entry in servers file for client',40,0,-1,-1 ,'',35,84);
      print FAILMAIL "$return\n";
   }
   if ($servers{$key} !~ /sSmMbB[ *]/ ) { 
      $return = build_output_record(-80,$output,'*** Servers file not complete for client',40,0,-1,-1 ,'',35,84);
      print FAILMAIL "$return\n";
   }
   if ($hostname{$key} ne $peer{$key} ) {
      $return = build_output_record(-80,$output,'*** Hostname doesn\'t match peer for client',43,0,-1,-1 ,'',35,84);
      print FAILMAIL "$return\n";
   }
   next if $hostname{$key} eq $key;    # Don't need any alias so don't care
   if (defined $alias{$key}) {
      # Is the hostname in the list of aliases
      (@list_of_aliases) = split (/,/,$alias{$key});
      $pos = 0;
      $found = 0;
      foreach $alli (@list_of_aliases) {
         $alli =~ s/\s+//;
         #print "***ALLI=$alli***$hostname{$key}***$key***\n";
         $pos += 1;
         if ( $alli  eq  $hostname{$key} ) {
            #print "********************Found a match\n";
            $found = $pos;
            goto FOUNDIT;
         }
      }
      FOUNDIT:
      if ($found > 0) {
         $return = build_output_record(-80,$output,"Hostname was number $found in the aliases",43,0,-1,-1 ,'',35,84);
      } else {
         $return = build_output_record(-80,$output,"*** Hostname missing from client aliases",43,0,-1,-1 ,'',35,84);
         print FAILMAIL "$return\n";
      }
   }
}
print FAILMAIL "ENDMAIL\n";
$return = `/usr/bin/sh  $filename  > /dev/null 2>&1`;
