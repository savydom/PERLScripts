#!/usr/bin/perl -w
(@return) = `/usr/bin/cat /home/scriptid/scripts/BACKUPS/undelete_pete_screwup.txt`;
open (OUTPUT,">/home/scriptid/scripts/BACKUPS/redone_file.txt");
for ($i = 0;$i<$#return;$i++) {
    chomp $return[$i];
    if ($return[$i] =~ /-----------------/) {
       # This is the end of a record so add the client with the info collected
       print OUTPUT "$return[$i]\n";

    } elsif ($return[$i] =~ /MONITOR_RAP/) {
       # This is the beginning of a record

    } elsif ($return[$i] =~ /               administrator: /) {
       T1:
        if ($return[$i+1] =~ /;/) {
           $i+=1;
           next;
        } else {
           $i+=1;
           goto T1;
        }
    } elsif ($return[$i] =~ /NAS/) { 
        next;
    } elsif ($return[$i] =~ /                    password:/) {
        next;
    } else {
       print OUTPUT "$return[$i]\n";
    }
}
