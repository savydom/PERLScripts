#!/usr/bin/perl -w
(@val) = ('ab', 'cd', 'de', 'fg');
$return = shift(@val);
print "Return=$return, val=@val\n";
