#!/usr/bin/perl -w
#-> Program Name: expiration_by_month.pl
#-> Authur:     Peter Reed
#-> Created:    5/24/2012
#-> Modified:
#-> Description:Looks at all the tapes freed during the next year and reports how many LTO3 or LTO5s
#->             will come available.
#-> Output:
#->             Month
#->             Number of LTO3 tapes that can be recycled
#->             Number of LTO5 tapes that can be recycled
my ($day);
($mon,$yr) = (localtime)[4,5];
$mon += 1;
$yr += 1900;
$yr +=1;	#Next Year
$end="$mon/28/$yr";
$end_check = $yr*100+$mon;
(@return) = `/usr/sbin/mminfo -xc, -r volume,volretent -q "volretent>today,volretent<$end"`;
foreach $value (@return) {
   chop $value;
   next if $value =~ /volume/;
   next if $value =~ /manual/;
   ($tape,$date) = split(/,/,$value);
   $number = $tape;
   $number =~ s/\D+(\d+)/$1/;
   ($month,$day,$year) = split("/",$date);
   $test = $year+2000;
   $test = $test*100+$month;
   if ($test <= $end_check) {
      if ($number > 3999) {
        $suffix=5;
      } else {
        $suffix=3;
      }
      $index = $test*10+$suffix;
      if (!defined  $lto{$index}) {$lto{$index}=0};
      $lto{$index} +=1;
   }
}
foreach $index (sort keys(%lto)) {
   $subscript = $index;
   ($year,$month,$type) = ($subscript =~ /(\d\d\d\d)(\d\d)(\d)/);
   print "$month/$year LTO$type Tapes Available=$lto{$index}\n"; 
}
