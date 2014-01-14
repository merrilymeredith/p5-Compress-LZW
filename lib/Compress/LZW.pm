package Compress::LZW;
# ABSTRACT: Pure-Perl implementation of scaling LZW

=head1 SYNOPSIS

 use Compress::LZW;
  
 my $compressed = compress($some_data);
 my $data       = decompress($compressed);
  
=head1 DESCRIPTION

C<Compress::LZW> is a perl implementation of the Lempel-Ziv-Welch
compression algorithm, which should no longer be patented worldwide.
It is shooting for loose compatibility with the flavor of LZW 
found in the classic UNIX compress(1), though there are a few
variations out there today.  I test against ncompress on Linux x86.

=cut

use warnings;
use strict;

use base 'Exporter';

BEGIN {
  our @EXPORT      = qw/compress decompress/;
  our @EXPORT_OK   = qw( $MAGIC $BITS_MASK $BLOCK_MASK $RESET_CODE );
  our %EXPORT_TAGS = (
    const => \@EXPORT_OK,
  );
}

our $MAGIC      = "\037\235";
our $BITS_MASK  = 0x1f;
our $BLOCK_MASK = 0X80;
our $RESET_CODE = 256;

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

Wraps L<Compress::LZW::Deompressor>

=cut


sub decompress {
  my ( $str ) = @_;
  
  return Compress::LZW::Decompressor->new()->decompress( $str );
}  


sub _detect_lsb_first {
  use Config;
  
  return 1 if substr($Config{byteorder},0,4) eq '1234';
  return 0;
}


=head1 EXPORTS

C<compress> C<decompress>

=head1 SEE ALSO

The implementations, L<Compress::LZW::Compressor> and L<Compress::LZW::Decompressor>.

Other Compress::* modules, especially Compress::LZV1, Compress::LZF and Compress::Zlib.

I definitely studied some other implementations that deserve credit, in particular: Sean O'Rourke, E<lt>SEANOE<gt> - Original author, C<Compress::SelfExtracting>, and another by Rocco Caputo
which was posted online.

=cut


############################################################


package Compress::LZW::Compressor;

use Compress::LZW qw(:const);

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
  
  my $buf = $MAGIC
    . chr( $self->max_code_size | $BLOCK_MASK );
     
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
  $self->_buf_write( $RESET_CODE );
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

use Compress::LZW qw(:const);

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
  if ( $head ne $MAGIC ){
    die "Magic bytes not found or corrupt.";
  }
  
  my $bits = ord(substr( $data, 2, 1 ));
  $self->_max_code_size( $bits & $BITS_MASK );
  $self->_block_mode(  ( $bits & $BLOCK_MASK ) >> 7 );
  
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
    if ( $self->_block_mode and $code == $RESET_CODE ){
      #reset table, next code, and code size
      $self->_reset__code_table;
      
      # trigger the builder
      $codes = $self->_code_table;
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
    
    # if next code expected will require a larger bit size
    if ( $self->_next_code == (2 ** $self->_code_size) ){
      $self->{_code_size}++;
    }
    
  }
  return $str;
}


1;
