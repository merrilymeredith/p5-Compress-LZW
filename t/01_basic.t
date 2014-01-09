#!/usr/bin/env perl

use Test::Simple tests => 9;

use Compress::LZW;

ok(1);

use strict;
$|=1;

my $testdata = "# This is a comment intended to take up space.  It turns out that\n# larger scripts may be handled differently!  blah blah blah blah blah\n# blah blah blah blah blah blah blah blah blah blah blah blah blah\n# blah blah blah blah blah blah blah blah blah blah blah blah blah\n# blah blah blah blah blah blah blah blah blah blah blah blah blah\n# blah blah\n";

for my $bits (12, 16) {
   my $compdata = compress($testdata, $bits);
   my $decompdata = decompress($compdata, $bits);
   ok( length($decompdata) == length($testdata) );
   ok( $decompdata eq $testdata );
}

print "Doing some sanity checks; I'm closing STDERR until done.\n";
sleep 1;
close STDERR;

do {
   my $compdata = compress($testdata, 12);
   my $decompdata = decompress($compdata, 16);
   ok( length($decompdata) != length($testdata) );
   ok( $decompdata ne $testdata );
};

do {
   my $compdata = compress($testdata, 16);
   my $decompdata = decompress($compdata, 12);
   ok( length($decompdata) != length($testdata) );
   ok( $decompdata ne $testdata );
};

print "Done.\n";
