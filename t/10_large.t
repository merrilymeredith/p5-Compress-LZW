#!/usr/bin/env perl

use Test::More tests => 4;

use Compress::LZW;
use strictures;

my $testsize = 1024 * 1024;

my $testdata = <<'END';
Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
END

while ( length($testdata) < $testsize ){
  $testdata .= $testdata;
}

ok( my $compdata = compress($testdata), "Compressed large test data" );
cmp_ok( length($compdata), '<', length($testdata), "Data compresses smaller" );

my $decompdata = decompress($compdata);
cmp_ok( length($decompdata), '==', length($testdata), "Large data decompresses to same size" );
is( $decompdata, $testdata, "Data is unchanged" );

