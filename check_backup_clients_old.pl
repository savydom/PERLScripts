#!/usr/bin/perl

print "Building list of servers\n";
@actual_servers=`/home/preed/list_servers.pl`;
foreach $server (@actual_servers) {
      chop $server;
      # print "$server\n";
      $check{$server} = 0;
}

print "Building list of servers backed up\n";
(@backup_clients)=`/home/preed/list_backup_clients`;
foreach $server (@backup_clients) {
      chop $server;
      # print "$server\n";
      $check{$server} = 1;
}

foreach $server (sort(keys %check)) {
      # print "$server, $check{$server}\n";
      if ($check{$server} == 0) {print "\tServer $server not being backed up\n"};
}
