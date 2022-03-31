#!/usr/bin/perl -w
$return =  show_client_os();
foreach $val (sort keys %os) {
   print "Client:$val, OS=$os{$val}\n"; 
}
sub show_client_os {
    $val1 =  ". type: NSR client'\n'show name\\;client OS type'\n'print"; 
    (@return) = `/usr/bin/echo $val1 | /usr/sbin/nsradmin -i - `;
    foreach $val (@return) {
      chomp $val;
      next if $val =~ /^\s*$/;
      $val =~ s/^\s*//;  # Take off leading spaces
      $val =~ s/\;//;    # Take off trailing semi
      next if $val =~ /Current query set/;
      if ($val =~ /name:/) {
         $client = $val;
         $client =~ s/name: //;
         $client = lc $client;
      } elsif ($val =~ /client OS type/) {
         $os{$client} = $val;
         $os{$client} =~ s/client OS type: //;
         $os{$client} = substr($os{$client},0,1);
      } else {
         print "Val=$val\n";
      }
    }
}
