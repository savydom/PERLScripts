#!/usr/bin/perl -w
(@test) = ('ABC', 'DEF', 'HIJ');
if (grep (/DEF/,@test) ) { print "Found def\n"};
