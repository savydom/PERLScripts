#!/usr/bin/perl -w 
for $j ('dsk5') {
    (@files) = `/usr/bin/find /AFTD/$j -type f -exec /usr/bin/ls -1 {} \\; `;
     $size_aftd = 0;
     foreach $file (@files) {
         
         ($temp) = `/usr/bin/du -s $file`;
         chomp $temp;
         my ($kb,$fff) = split(/\s+/,$temp);
         $fff =~ s:/AFTD/dsk5/::;
         my ($top,$bot,$ff) =($fff=~/(\d\d)\/(\d\d)\/(.*$)/);
         print "$top,$bot,$ff\n";
         $size = $kb*512/1000/1000/1000;
         $topsize{$top} += $size;
         $size_aftd += $size;
     }
     print "Size = $size\n";
}
print "Size = $size_aftd GB\n";

foreach $val (sort keys %topsize) {
    print "Top Directory $val size = $topsize{$val}\n";
}


