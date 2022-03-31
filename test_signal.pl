#!/usr/bin/perl -w
#foreach $val (sort keys %SIG) {
#   #print "SIG\{$val\} = $SIG{$val}\n";
#   print "SIG\{$val\}\n";
#}
use strict;
use warnings;

#$SIG{'INT'} = sub {die "Caught a sigint (control-c) $!"};

$SIG{'INT'}  = \&signal_handler;
$SIG{'TERM'} = \&signal_handler;

sleep (20);

sub signal_handler {
   die "Caught a signal $!\n";
}

