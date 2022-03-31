#!/usr/bin/perl -w

use warnings;
use strict;

die("usage: $0 <size_in_gigabytes> <file_name>\n") unless @ARGV == 2;

my ($giga_bytes, $fname) = @ARGV;
my $num_bytes = $giga_bytes * 1000 *  1000 * 1024;

open (FILE, ">",$fname) or die "Can't open $fname for writing ($!)";

my $minimum = 32;
my $range = 96;

my $start_seconds = time;
for (1 .. $num_bytes) {
   print FILE pack( "c", int(rand($range)) + $minimum);
}
my $end_seconds = time;
my $delta = $end_seconds - $start_seconds;
print "Took $delta seconds to write $giga_bytes gigabyte(s)\n";

close FILE;

