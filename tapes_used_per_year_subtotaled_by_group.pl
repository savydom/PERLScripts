#!/usr/bin/perl -w
#-> Program Name: tapes_used_per_week.pl
#-> Authur:     Peter Reed
#-> Created:    5/24/2012
#-> Modified:
#-> Description:Report to produce statistics about tape use per week to determine burn rate
#-> Output:
#->             Number of LTO3 tapes used per week
#->             Number of LTO5 tapes used per week
#->             Full Backups per week
#->             Incremental Backups per week
#->             Total Backups per week

use Time::Local;
my ($units,$tape,$ssid);
#print "mminfo -r -xc,' 'ssid(56),group,totalsize,level' -q '!incomplete,savetime>$start,savetime<$end'\n";
(@ssid_volume)   = `mminfo -xc, -r 'ssid(56),group,sumsize,level,volume,client' -q '!incomplete,savetime>last year,savetime<today' | sort -u`;
undef %totals;
undef %totals_lto5;
undef %totals_lto3;
undef %full;
undef %incr;
foreach $val (@ssid_volume) {
     next if $val =~ /group/;
     chop $val;
     ($ssid,$group,$sumsize,$level,$volume) = split (/,/,$val);
     ($totalsize,$units) = ($sumsize =~ /(\d+)\s+(\D+)/);
     # Convert to Gigabytes
     if ($units =~ 'MB') {
        $totalsize=$totalsize/1000;
     } elsif ($units =~ 'KB') {
        $totalsize=$totalsize/1000/1000;
     } elsif ($units =~ 'GB') {
     } elsif ($units =~ 'TB') {
        $totalsize=$totalsize*1000;
     } elsif ($units =~ 'B')  {
       $totalsize=$totalsize/1024/1000/1000;
     } else {
        print "Don't know what units to use for $units\n";
     }
     $totals{$group} += $totalsize;
     #$tape{$volume} += 1;
     $volume =~s/U[NS]//;
     $volume =~s/N//;
     if ($volume>3999) {
        if (defined $totals_lto5{$group}) {
           $totals_lto5{$group} += $totalsize;
        } else {
           $totals_lto5{$group} = 0;
        }
     } else {
        if (defined $totals_lto3{$group}) {
           $totals_lto3{$group} += $totalsize;
        } else {
           $totals_lto3{$group} = 0;
        }
     }
     if ($level =~ /full/) {
         if (defined $full{$group}) {
           $full{$group} += $totalsize;
        } else {
           $full{$group} = 0;
        }
     } else {
         if (defined $incr{$group}) {
           $incr{$group} += $totalsize;
        } else {
           $incr{$group} = 0;
        }
     }
}
$lto3_week=0;
$lto5_week=0;
$total_week=0;
$total_full=0;
$total_incr=0;
foreach $key (sort keys(%totals)) {
      $size =  $totals{$key}+.005;
      $size =~ s/(\d*\.\d\d)\d*/$1/;
      if (defined  $totals_lto5{$key}) {
         $lto5 = $totals_lto5{$key}+.005;
      } else {
         $lto5 = .005;
      } 
      if (defined  $totals_lto3{$key}) {
         $lto3 = $totals_lto3{$key}+.005;
      } else {
         $lto3 = .005;
      } 
      if (defined  $full{$key}) {
         $ffull = $full{$key}+.005;
      } else {
         $ffull = .005;
      } 
      if (defined  $incr{$key}) {
         $iincr = $incr{$key}+.005;
      } else {
         $iincr = .005;
      } 

      $lto5  =~ s/(\d*\.\d\d)\d*/$1/;
      $lto3  =~ s/(\d*\.\d\d)\d*/$1/;
      $iincr  =~ s/(\d*\.\d\d)\d*/$1/;
      $ffull  =~ s/(\d*\.\d\d)\d*/$1/;
      $val   =sprintf"%-32s",$key;
      print "Group:$val\tLTO3:$lto3\tLTO5:$lto5\tINCR:$iincr\tFULL:$ffull\tTotal Group:$size\n";
      $lto3_week  += $lto3;
      $lto5_week  += $lto5;
      $total_week += $size;
      $total_incr += $iincr;
      $total_full += $ffull;
}
print "\nTotal:LTO3:$lto3_week\tLTO5:$lto5_week\t\tINCR:$total_incr\tFULL:$total_full\tTotal Group:$total_week\n\n";
$tape3=int($lto3_week/800+.5);
$tape5=int($lto5_week/2479+.5);
print "LTO3 Tapes at  800GB/tape: $tape3\n";
print "LTO5 Tapes at 2500GB/tape: $tape5\n\n\n";

#foreach $key (sort keys(%tape)) {
#   print "$key\n";
#}
#++$i;
#$start_secs = $start_secs + $increment_secs;
#if ($i < $number_of_weeks) {goto TOP};
