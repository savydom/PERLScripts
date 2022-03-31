#!/usr/bin/perl -w
# This utility is used to determine the maximum size of a client full backup
#
# Use command mminfo -r client,name,totalsize -q 'level=full,savetime>last friday'
# Output is in bytes
open (SIZES,">/home/scriptid/scripts/BACKUPS/Client_Full_Backups.out") or die "Could not open /home/scriptid/scripts/BACKUPS/Client_Full_Backups.out";
(@return) = `/usr/sbin/mminfo -r 'client,name,totalsize' -q 'level=full,savetime>last month'`;
foreach $record (@return) {
   next if $record =~ /client/;
   chomp $record;
   ($client,$name,$totalsize) = split(' ',$record);
   next if $name =~ /index/;
   next if $totalsize =~ /ROLES/;
   next if $totalsize =~ /SYSTEM/;
   next if $totalsize =~ /ASR/;
   next if $totalsize =~ /FILES/;
   next if $totalsize =~ /OTHER/;
   next if $totalsize =~ /USER/;
   next if $totalsize =~ /DB:/;
   next if $totalsize =~ /STATE:/;
   #print "$client,$name,$totalsize\n";
   $index = "$client|$name";
   if (!defined $max{$index} ) {
       $max{"$index"} = $totalsize;
   } else {
       if ($totalsize > $max{"$index"}) { $max{"$index"} = $totalsize };
   }
}

# Now process records to determine max full per client
foreach $key (sort keys (%max)) {
   ($client,$name) = split(/\|/,$key);
   #print "$key,  $max{$key}\n";
   #print "$key, $client, $name,      $max{$key}\n";
   if (!defined $total{$client}) {
      $total{$client} = $max{$key};
   } else {
      $total{$client} += $max{$key};
   }
}

# Now output the sizes
$index = 0;
foreach $key (sort keys (%total) ) {
   if ($index == 0) {
      $record = "                                                                                                          "};
   #print "*****$key,$total{$key}\n";
   $temp = $total{$key}/1024/1024/1024;
   $output = format_number($temp,'2','r',8);
   print SIZES "$key,$output\n";
   $temp = "$output GB  ".substr($key,0,19);
   $length = length($temp);
   substr($record,$index,$length) = $temp;
   $index += 37;
   if ($index == 111) {
      substr($record,34,1) = '|';
      substr($record,71,1) = '|';
      #$length = length($record);
      #print "Length=$length\n";
      print "$record\n";
      $index = 0; 
   }
   #print "$output GB\t$key\n";
}
if ($index <90) {print  "$record\n"};

sub format_number {
   my ($val,$places,$justify,$width) = @_;
   my $text1;
   $text=reverse $val;
   $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   $val=reverse $text;
   $val =~ s/(\d*\.\d{$places})\d*/$1/;
   $length = length($val);
   if ($justify eq 'l') {
      $start = 0;
   } elsif ($justify eq 'c') {
      $start = int( ($width-$length)/2 );
   } elsif ( $justify eq 'r') {
      $start = $width-$length;
   } else {
      print "Error in formatnumber\n";
  }
   $final = ' ' x $width;
   substr($final,$start,$length)=$val;
   return $final;
}

