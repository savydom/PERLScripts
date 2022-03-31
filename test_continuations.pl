#!/usr/bin/perl -w
#print "Before nsradmin\n";
##$nsrpass =  ". type:NSR client'\n'show name\\;group\\;comment\\;action'\n'print";
#$nsrpass = ". type:NSR client'\n'show name\\;group\\;backup command\\;scheduled backup\\;comment\\;action'\n'print";
#(@return) = handle_nsradmin_line_continuations($nsrpass);
#foreach $vvv (@return) {
#   print "INFO: $vvv\n";
#}
$print_only=0;
#$ggroup = 'Automated-NON-PROD-Reruns';
#$return =  remove_clients_from_group($ggroup);
$ggroup = 'Automated-NON-PROD-VADP-Reruns';
$return =  remove_clients_from_group($ggroup);
#$ggroup = 'Automated-PROD-VADP-Reruns';
#$return =  remove_clients_from_group($ggroup);
#$ggroup = 'Automated-PROD-Reruns';
#$return =  remove_clients_from_group($ggroup);
sub remove_clients_from_group {
    ($pgroup) = @_;
    my $group = $pgroup;
    # Find all client in the pgroup
    $nsrpass_remove =  "\. type: NSR client\\;group:$group'\n'show name\\;group'\n'print'\n'";
    (@return) = handle_nsradmin_line_continuations($nsrpass_remove);
    #foreach $vvv (@return) {
    #  print "vvv=$vvv\n";
    #}
    #
    # The return will be client name, and group on the next line
    #foreach $val (@return) {

    for ($i=0;$i<=$#return;$i++) {
      $val=$return[$i];
      chomp $val;
      if ($val =~ /No resources found for query/) {
         # There are no client in the group
         undef $client;
         return;
      }
      next if $val =~ /type: NSR client\;/;
      next if $val =~ /Current query set/;
      next if $val =~ /^\s*$/;	# Skip blank Lines
      if ($val =~ /name:/) {
         ($client) = ($val =~ /name: (\S+)\;$/);
         $i ++;
         $val = $return[$i];
         chomp $val;
         $val =~ s/^.*group: //;
         $val =~ s/$group[, ]*//;	# Remove group first location;
         $val =~ s/,\s$group//g;	# Remove all occurences of the group after the first location;
         $nsrpass =  "\. type: NSR client\\;name:$client'\n'update group:$val'\n'";
         print "NSRPASS in remove_clients_from_group=$nsrpass\n";
         if ($print_only == 1) {(@return1) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -i - `};
         # foreach $vall (@return1) {
         #     print "Returned $vall";
         #}
      } else  {
         print "*******************************Error**********************************\n";
      }
    }
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

