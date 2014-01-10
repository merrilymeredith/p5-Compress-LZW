package Compress::LZW;

use warnings;
use strict;

use base 'Exporter';
our @EXPORT = qw/compress decompress/;;

our $MAGIC      = "\037\235";
our $BIT_MASK   = 0x1f;
our $BLOCK_MASK = 0X80;

sub compress {
  my ( $str ) = @_;
  
  return Compress::LZW::Compressor->new()->compress( $str );
}

sub decompress {
  my ( $str ) = @_;
  
  return Compress::LZW::Compressor->new()->compress( $str );
}  

############################################################


package Compress::LZW::Compressor;

use Moo;
use namespace::clean;

has max_code_size => (
  is      => 'ro',
  default => 16,
);

has _code_size => (
  is      => 'rwp',
  clearer => 1,
  default => 9,
);

has _buf => (
  is      => 'lazy',
  builder => 1,
);

has _buf_size => (
  is      => 'rw',
);

has _code_table => (
  is      => 'lazy',
  clearer => 1,
);

has _next_code => (
  is      => 'rw',
  clearer => 1,
  default => 257,
);

sub _build__buf {
  my $self = shift;
  
  my $buf = $Compress::LZW::MAGIC
    . chr( $self->max_code_size | $Compress::LZW::BLOCK_MASK );
     
  $self->_buf_size( length($buf) * 8 );
  return \$buf;
}


sub _build__code_table {
  my $self = shift;
  
  return {
    map { chr($_) => $_ } 0 .. 255
  };
}

sub _reset__code_table {
  my $self = shift;
  
  $self->_clear__code_table;
  $self->_clear__next_code;
  $self->_clear__code_size;
  $self->_buf_write( 256 );
}

sub _inc__next_code {
  my $self = shift;
  $self->_next_code( $self->_next_code + 1 );
}

sub _add_code {
  my $self = shift;
  my ( $code ) = @_;

  my $max_code = 2 ** $self->_code_size;
  if ( $code > $max_code ){
    
    if ( $self->_code_size < $self->max_code_size ){
      $self->_set_code_size($self->_code_size + 1 );
    }
    else {
      # FINISHME
      # if compress(1) compatible we need to do a code table reset
      # ... when the ratio falls after reaching this point.
      # this doesn't need to be perfect, the only part that needs
      # match algorithm-wise is what code tables are built the same
      # after a reset.
      warn "Resetting code table at $code";
      $self->_reset__code_table;
    }
  }
  
  $self->_buf_write( $code );
}

sub _finish {
  my $self = shift;

  return ${ $self->_buf };
}

sub _buf_write {
  my $self = shift;
  my ( $code ) = @_;

  return unless defined $code;
  
  my $code_size = $self->_code_size;
  my $buf       = $self->_buf;
  my $buf_size  = $self->_buf_size;

  if ( $code > ( 2 ** $code_size ) ){
    die "Code value too high for current code size $code_size";
  }
  my $wpos = $buf_size;# + $code_size - 1;
  
  #~ warn "write 0x" . hex( $code ) . "\tat $code_size bits\toffset $wpos (byte ".int($wpos/8) . ')';
  
  if ( $code == 1 ){
    vec( $$buf, $wpos, 1 ) = 1;
  }
  else {
    for my $bit ( 0 .. $code_size-1 ){
      vec( $$buf, $wpos + $bit, 1 ) = 1 if ( ($code >> $bit) & 1 );
    }
  }
  
  $self->_buf_size( $buf_size + $code_size );
}


sub compress {
  my $self = shift;
  my ( $str ) = @_;
  
  my $codes = $self->_code_table;

  my $seen = '';
  for ( 0 .. length($str) ){
    my $char = substr($str, $_, 1);
    
    if ( exists $codes->{ $seen . $char } ){
      $seen .= $char;
    }
    else {
      $self->_add_code( $codes->{ $seen } );
      
      $codes->{ $seen . $char } = $self->_next_code;
      $self->_inc__next_code;
      
      $seen = $char;
    }
  }
  $self->_add_code( $codes->{ $seen } );  #last bit of input
  
  return $self->_finish;
}



1;
__END__

=head1 NAME

Compress::LZW -- Pure perl implementation of LZW

=head1 WARNING

This module does not yet support compress(1)'s .Z files!! Nor is its
interface stable.  Hence the alpha status.  Expect support to come soon.

=head1 WARNING

Read above once more :) 

=head1 SYNOPSIS

  use Compress::LZW;
  
  my $compressed = compress($fatdata);
  my $fatdata    = decompress($compressed);
  
  my $smallcompressed = compress($thindata, 12);
  my $thindata        = decompress($smallcompressed, 12);
  
=head1 DESCRIPTION

C<Compress::LZW> it a perl implementation of the newly free LZW
compression algorithm.  It defaults to building a 16-bit codeword
table, but provides the ability to choose a 12-bit table also.
Depending on the size of your data, the 12-bit table may provide
better compression.

=head2 Functions

=over

=item C<compress>

Takes a string as its first argument, and returns the compressed
result.  You can also specify the size of your codeword table in
C<@_[1]>, choosing either 12 or 16.  16 is the default.  C<compress>
will 

=item C<decompress>

Takes a string as its first argument, and returns the decompressed
result.  You can also specify the size of your codeword table in
@_[1], choosing either 12 or 16.  16 is the default.

=back


=head1 EXPORTS

C<Compress::LZW> exports: C<compress> C<decompress>
That's all.

=head1 SEE ALSO

Other Compress::* modules, especially Compress::LZV1, Compress::LZF and Compress::Zlib.

=head1 AUTHOR

Sean O'Rourke, E<lt>seano@cpan.orgE<gt> - Original author, C<Compress::SelfExtracting>

Matt Howard E<lt>mhoward@hattmoward.orgE<gt> -  C<Compress::LZW>
   
Bug reports welcome, patches even more welcome.

=head1 COPYRIGHT

Copyright (C) 2003 Sean O'Rourke & Matt Howard.  All rights reserved, some wrongs
reversed.  This module is distributed under the same terms as Perl
itself.  Let me know if you actually find it useful.

MH: Also, credit to Rocco Caputo for a 2nd implementation to study. 
Thanks!

=cut
