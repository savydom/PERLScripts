#!/usr/bin/perl -w
$SOURCE      = 'sscprodeng2';
$DESTINATION = 'sscprodeng';
# Example client
#nsradmin>  . type:nsr client;name:sscprod1
#Current query set
#nsradmin> show
#nsradmin> print
#k                        type: NSR client;
#k                        name: sscprod1;
#k                      server: sscprodeng;
#                   client id: \
#6beca748-00000004-45d4b5c3-45d4b73d-00170000-c0a86564;
#k            scheduled backup: Enabled;
#k                     comment: ;
#k             Save operations: ;
#            archive services: Disabled;
#k                    schedule: CSA;
#k               browse policy: Year;
#k            retention policy: Year;
#                  statistics: elapsed = 104259, index size (KB) = 429190,
#                              amount used (KB) = 429190, entries = 2548021;
#               index message: ;
#       index operation start: ;
#              index progress: ;
#             index operation: Idle;
#              index save set: ;
#k                   directive: Unix standard directives;
#k                       group: CSA, INDEX, Automated-NON-PROD-Reruns;
#k                    save set: All;
#                save set MBT: All;
#k  Backup renamed directories: Enabled;
#k          Checkpoint enabled: Disabled;
#k      Checkpoint granularity: Directory;
#kParallel save streams per save set: Disabled;
#k                    priority: 500;
#   File inactivity threshold: 0;
#File inactivity alert threshold: 0;
#k               remote access: ;
#k                 remote user: ;
#k                    password: ;
#         NAS management user: ;
#     NAS management password: ;
#        NAS file access user: ;
#    NAS file access password: ;
#        index backup content: No;
#              backup command: ;
#                 Pre command: ;
#                Post command: ;
#     application information: ;
#                 job control: ;
#     ndmp vendor information: ;
#                        ndmp: No;
#                  NAS device: No;
#             NDMP array name: ;
#  NAS device management name: ;
#storage replication policy name: ;
#       De-duplication backup: No;
#         De-duplication node: ;
#                        Pool: ;
#          Data Domain backup: No;
#       Data Domain interface: IP;
#               Client direct: Disabled;
#         Probe resource name: ;
#              virtual client: Yes;
#          Block based backup: No;
#               physical host: sscprod1;
#           Proxy backup type: ;
#           Proxy backup host: ;
#             executable path: ;
#k    server network interface: sscprodeng;
#k                     aliases: sscprod1, sscprod1.sscnola.oob;
#                  index path: ;
#          owner notification: ;
#k                 parallelism: 13;
#k physical client parallelism: Disabled;
#               archive users: ;
#     autoselect storage node: Disabled;
#k               storage nodes: sscustno1-bk2;
#       recover storage nodes: ;
#         clone storage nodes: ;
#   save session distribution: max sessions;
#                  hard links: Disabled;
#             short filenames: Disabled;
#                 backup type: ;
#               backup config: ;
#                    hostname: sscprodeng;
#               administrator: root@sscprodeng2, root@sscustno1,
#                              root@sscustno1-mn, root@sscustno1-bk2,
#                              root@sscprodeng, root@sscprodeng-mn,
#                              root@sscprodeng-bk2, root@sscustno1,
#                              root@sscustno1-mn, root@sscustno1-bk2,
#                              gbrandt@sscprodeng, gbrandt@sscprodeng-mn,
#                              gbrandt@sscprodeng-bk2, preed@sscprodeng,
#                              preed@sscprodeng-mn, preed@sscprodeng-bk2,
#                              "user=root,host=sscprodeng",
#                              "user=administrator,host=sscprodeng",
#                              "user=administrator,host=sscustno1",
#                              "user=system,host=sscprodeng";
#          ONC program number: 390109;
#          ONC version number: 2;
#               ONC transport: TCP;
#              client OS type: Solaris;
#                        CPUs: 24;
#           NetWorker version: 8.2.2.6.Build.985;
#              enabler in use: Yes;
#       licensed applications: ;
#               licensed PSPs: ;
#               VBA Host type: ;
#
# Sample script
#nsradmin>
#cat <<EOF | nsradmin -i -
#create type:nsr client; name: c27acecnla03a;
#                      server: sscprodeng;
#            scheduled backup: Enabled;
#                     comment: Log;
#             Save operations: "VSS:*=off";
#            archive services: Disabled;
#                    schedule: Auditlog;
#               browse policy: Year;
#            retention policy: Year;
#                   directive: NT standard directives;
#                       group: AUDITLOG;
#                    save set: ALL;
#  Backup renamed directories: Disabled;
#                    priority: 500;
#   File inactivity threshold: 0;
#File inactivity alert threshold: 0;
#               remote access: ;
#                 remote user: ;
#
# Want to skip any clients in DECOM, and with backup
# Looks like there is no option to sort display.  It is in the order it appears within the client

# Build a list of clients and groups on the new server
(@clients) = `/bin/cat transfer_back_final.txt`;

$count = 0;
open (NEW_CLIENT,">new_client_create_script.sh") or die "Could not create file new_client_create_script.sh\n";
print NEW_CLIENT "/usr/bin/cat <<EOF | nsradmin -s $DESTINATION -i - \n";
foreach $client (@clients) {
   chomp $client;
   print "********************Client name is $client********************\n";
   print NEW_CLIENT "\n";
   $nsrpass = ". type:NSR client\\;name:$client'\n'show'\n'print";
   print "NSRPASS=$nsrpass\n";
   (@source) = `/usr/bin/echo $nsrpass | /usr/sbin/nsradmin -s $SOURCE -i -`;
   $iprint = 1;
   foreach $val (@source) {
      if ($count >300) {goto END};
      chomp $val; 
      next if ($val =~ /NSR client/);
      next if $val =~ /Current query set/;
      next if $val =~ /Will show all attributes/;
      # skip the stuff I don't want
      # Need to handle multiple line backups
      # There is a multiple line if there is no ; on the end
      if ($val =~ 'client id: ') {$iprint = 0};
      if ($val =~ 'archive services: ') {$iprint = 0};
      if ($val =~ 'statistics: ') {$iprint = 0};
      if ($val =~ 'index \S+: ') {
         $iprint = 0;
         if ($val =~ /index backup content/ ) {$iprint = 1};
      }
      if ($val =~ /scheduled backup: /) {$val =~ s/Enabled/Disabled/};
      if ($val =~ 'File inactivity.*: ') {$iprint = 0};
      if ($val =~ 'NAS.*: ') {$iprint = 0};
      if ($val =~ 'De-duplication.*: ') {$iprint = 0};
      if ($val =~ 'Data Domain.*: ') {$iprint = 0};
      if ($val =~ /ONC.*: /) {$iprint = 1};
      if ($val =~ /$SOURCE/) {$val =~ s/$SOURCE/$DESTINATION/};
      if ($val =~ /sscustno1.*/) { $val =~ s/sscustno1.*/;/};
      if ($val =~ /10\./) { $val =~ s/storage nodes: .*$/storage nodes: $DESTINATION\;/};
      $val =~ s/: ,/: /;
      if ($val =~ /^\s*name: /) {$val=~ s/^\s+/\ncreate type: NSR client\;/};
      if ($val =~ /^\s*storage nodes:\s+\;$/) {$val=~ s/\;/$DESTINATION\;/};
      if ($iprint == 1) {
         #if ($val =~ /^\s+name: /) {print "$val\n"};
         print NEW_CLIENT "$val\n";
      }
      if ($val =~ /\;/) {$iprint = 1};
   }
   $count +=1;
}
END: print NEW_CLIENT "EOF\n";
