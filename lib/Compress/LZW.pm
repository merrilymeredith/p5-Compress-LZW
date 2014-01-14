package Compress::LZW;

use warnings;
use strict;

use base 'Exporter';
our @EXPORT = qw/compress decompress/;;

our $MAGIC      = "\037\235";
our $BITS_MASK  = 0x1f;
our $BLOCK_MASK = 0X80;

sub compress {
  my ( $str ) = @_;
  
  return Compress::LZW::Compressor->new()->compress( $str );
}

sub decompress {
  my ( $str ) = @_;
  
  return Compress::LZW::Decompressor->new()->decompress( $str );
}  


sub _detect_lsb_first {
  use Config;
  
  return 1 if substr($Config{byteorder},0,4) eq '1234';
  return 0;
}

############################################################


package Compress::LZW::Compressor;

use Moo;
use namespace::clean;

has lsb_first => (
  is      => 'ro',
  default => \&Compress::LZW::_detect_lsb_first,
);

has max_code_size => ( # max bits
  is      => 'ro',
  default => 16,
);

has init_code_size => (
  is      => 'ro',
  default => 9,
);

has _code_size => ( # current bits
  is       => 'rw',
  clearer  => 1,
  lazy     => 1,
  builder  => 1,
);

has _buf => (
  is      => 'lazy',
  builder => 1,
);

has _buf_size => ( #track our endpoint in bits
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
  return {
    map { chr($_) => $_ } 0 .. 255
  };
}

sub _build__code_size {
  return $_[0]->init_code_size;
}


sub _reset__code_table {
  my $self = shift;
  
  $self->_clear__code_table;
  $self->_clear__next_code;
  $self->_clear__code_size;
  $self->_buf_write( 256 );
}


sub _new_code {
  my $self = shift;
  my ( $data ) = @_;
  
  my $code = $self->_next_code;
  $self->_code_table->{ $data } = $code;
  $self->_next_code( $code + 1 );
  
  my $max_code = 2 ** $self->_code_size;
  if ( $self->_next_code > $max_code ){
    
    if ( $self->_code_size < $self->max_code_size ){
      $self->_code_size($self->_code_size + 1 );
    }
    else {
      # FINISHME
      # if compress(1) comparable we need to do a code table reset
      # ... when the ratio falls after reaching this point.
      # this doesn't need to be perfect, the only part that needs
      # match algorithm-wise is what code tables are built the same
      # after a reset.
      warn "Resetting code table at $code";
      $self->_reset__code_table;
    }
  }
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
  my $wpos = $self->lsb_first ? $buf_size : ( $buf_size + $code_size - 1 );
  
  #~ warn "write 0x" . hex( $code ) . "\tat $code_size bits\toffset $wpos (byte ".int($wpos/8) . ')';
  
  if ( $code == 1 ){
    vec( $$buf, $wpos, 1 ) = 1;
  }
  else {
    for my $bit ( 0 .. $code_size-1 ){
      
      if ( ($code >> $bit) & 1 ){
        vec( $$buf, $wpos + ($self->lsb_first ? $bit : 0 - $bit ), 1 ) = 1;
      }
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
      $self->_buf_write( $codes->{ $seen } );
      
      $self->_new_code( $seen . $char );
      
      $seen = $char;
    }
  }
  $self->_buf_write( $codes->{ $seen } );  #last bit of input
  
  return $self->_finish;
}


############################################################


package Compress::LZW::Decompressor;

use Moo;
use namespace::clean;

has lsb_first => (
  is      => 'ro',
  default => \&Compress::LZW::_detect_lsb_first,
);

has _block_mode => ( # can code table reset
  is      => 'rw',
  default => 1,
);

has _max_code_size => ( # max bits
  is      => 'rw',
  default => 16,
);

has init_code_size => (
  is      => 'ro',
  default => 9,
);

has _code_size => ( # current bits
  is       => 'rw',
  clearer  => 1,
  lazy     => 1,
  builder  => 1,
);

has _buf => (
  is      => 'ro',
  default => sub { \'' },
);

has _code_table => (
  is      => 'lazy',
  clearer => 1,
);

has _next_code => (
  is      => 'rw',
  clearer => 1,
  builder => 1,
);


sub _build__code_table {
  return {
    map { $_ => chr($_) } 0 .. 255
  };
}

sub _build__code_size {
  return $_[0]->init_code_size;
}


sub _build__next_code {
  return $_[0]->_block_mode ? 257 : 256;
}

sub _reset__code_table {
  my $self = shift;
  
  $self->_clear__code_table;
  $self->_clear__next_code;
  $self->_clear__code_size;
}

sub _inc__next_code {
  my $self = shift;
  
  $self->_next_code( $self->_next_code + 1 );
}

sub _new_code {
  my $self = shift;
  my ( $data ) = @_;
  
  $self->_code_table->{ $self->_next_code } = $data;
  $self->_inc__next_code;
}


sub _read_codes {
  my $self = shift;
  my ( $data ) = @_;
  
  #check header,
  #return : first code @9 bits,
  #       : iterator
  
  my $head = substr( $data, 0, 2 );
  if ( $head ne $Compress::LZW::MAGIC ){
    die "Magic bytes not found or corrupt.";
  }
  
  my $bits = ord(substr( $data, 2, 1 ));
  $self->_max_code_size( $bits & $Compress::LZW::BITS_MASK );
  $self->_block_mode(  ( $bits & $Compress::LZW::BLOCK_MASK ) >> 7 );
  
  my $rpos = 8 * 3;  #reader position in bits;
  my $eof = length( $data ) * 8;
  
  my $code_reader = sub {
    my $self = shift;
    
    my $code_size = $self->_code_size;
    
    return undef if ( $rpos + $code_size ) > $eof;
    
    my $cpos = $self->lsb_first ? $rpos : ($rpos + $code_size);
    
    my $code = 0;
    for ( 0 .. $code_size - 1 ){
      $code |=
        vec( $data, $cpos + ( $self->lsb_first ? $_ : 0 - $_ ), 1) << $_;
    }
    
    $rpos += $code_size;
    
    return $code;
  };

  return ( $code_reader->( $self ), $code_reader );
}

sub decompress {
  my $self = shift;
  my ( $data ) = @_;
  
  my $codes = $self->_code_table;

  my ( $init_code, $code_reader ) = $self->_read_codes( $data);
  
  my $str = $codes->{ $init_code };
  
  my $seen = $init_code;
  
  while ( defined( my $code = $code_reader->($self) ) ){
    
    if ( $code == 256 ){
      die "got a reset";
    }    
    
    if ( my $word = $codes->{ $code } ){
      
      $str .= $word;
      
      $self->_new_code( $codes->{ $seen } . substr($word,0,1) );
    }
    else {
      my $word = $codes->{$seen};

      unless ( $code == $self->_next_code ){
        warn "($code != ". $self->_next_code . ") input may be corrupt";
      }
      $self->_inc__next_code;
      
      $codes->{$code} = $word . substr( $word, 0, 1 );
      
      $str .= $codes->{$code};
    }
    $seen = $code;
    
    
    if ( $self->_next_code == (2 ** $self->_code_size) ){
      $self->{_code_size}++;
    }
    
    
  }
  return $str;
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
