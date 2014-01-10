#!/usr/bin/env perl

use Test::More;

use Compress::LZW;
use strict;
use warnings;

my $testdata = "# This is a comment intended to take up space.  It turns out that\n# larger scripts may be handled differently!  blah blah blah blah blah\n# blah blah blah blah blah blah blah blah blah blah blah blah blah\n# blah blah blah blah blah blah blah blah blah blah blah blah blah\n# blah blah blah blah blah blah blah blah blah blah blah blah blah\n# blah blah\n";


ok( my $compdata = compress($testdata), "Compressed test data" );
cmp_ok( length($compdata), '<', length($testdata), "Data compresses smaller" );

TODO: {
  local $TODO = 'NYI';
  my $decompdata = '';#decompress($compdata);
  cmp_ok( length($decompdata), '==', length($testdata), "Data decompresses to same size" );
  is( $decompdata, $testdata, "Decompressed data is unchanged" );
}

done_testing();
