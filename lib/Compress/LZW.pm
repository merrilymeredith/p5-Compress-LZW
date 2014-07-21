package Compress::LZW;
# ABSTRACT: Pure-Perl implementation of scaling LZW

=head1 SYNOPSIS

 use Compress::LZW;
  
 my $compressed = compress($some_data);
 my $data       = decompress($compressed);
  
=head1 DESCRIPTION

C<Compress::LZW> is a perl implementation of the Lempel-Ziv-Welch compression
algorithm, which should no longer be patented worldwide.  It is shooting for
loose compatibility with the flavor of LZW found in the classic UNIX
compress(1), though there are a few variations out there today.  I test against
ncompress on Linux x86.

=cut

use strictures;

use base 'Exporter';

BEGIN {
  our @EXPORT      = qw/compress decompress/;
  our @EXPORT_OK   = qw(
    $MAGIC       $MASK_BITS    $MASK_BLOCK
    $RESET_CODE  $BL_INIT_CODE $NR_INIT_CODE
    $INIT_CODE_SIZE
  );
  our %EXPORT_TAGS = (
    const => \@EXPORT_OK,
  );
}

our $MAGIC          = "\037\235";
our $MASK_BITS      = 0x1f;
our $MASK_BLOCK     = 0x80;
our $RESET_CODE     = 256;
our $BL_INIT_CODE   = 257;
our $NR_INIT_CODE   = 256;
our $INIT_CODE_SIZE = 9;

use Compress::LZW::Compressor;
use Compress::LZW::Decompressor;

=func compress

Accepts a scalar, returns compressed data in a scalar.

Wraps L<Compress::LZW::Compressor>

=cut

sub compress {
  my ( $str ) = @_;
  
  return Compress::LZW::Compressor->new()->compress( $str );
}

=func decompress

Accepts a (compressed) scalar, returns decompressed data in a scalar.

Wraps L<Compress::LZW::Decompressor>

=cut


sub decompress {
  my ( $str ) = @_;
  
  return Compress::LZW::Decompressor->new()->decompress( $str );
}  

=head1 EXPORTS

Default: C<compress> C<decompress>

=head1 SEE ALSO

The implementations, L<Compress::LZW::Compressor> and
L<Compress::LZW::Decompressor>.

Other Compress::* modules, especially Compress::LZV1, Compress::LZF and
Compress::Zlib.

I definitely studied some other implementations that deserve credit, in
particular: Sean O'Rourke, E<lt>SEANOE<gt> - Original author,
C<Compress::SelfExtracting>, and another by Rocco Caputo which was posted
online.

=cut

1;
