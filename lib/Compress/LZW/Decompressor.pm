package Compress::LZW::Decompressor;
# ABSTRACT: Scaling LZW decompressor class

=head1 SYNOPSIS

 use Compress::LZW::Decompressor;
  
 my $d    = Compress::LZW::Decompressor->new();
 my $orig = $d->decompress( $lzw );
  
=cut

use Compress::LZW qw(:const);

use Types::Standard qw( Bool Int );

use Moo;
use namespace::clean;

=attr lsb_first

Default: Dectected through Config.pm / byteorder

True if bit 0 is the least significant in this environment. Not well-tested,
but intended to change some internal behavior to match compress(1) output on
MSB-zero platforms.

Needs to match the value used during compression, if data is passing across
CPU architectures.

=cut

has lsb_first => (
  is      => 'ro',
  default => \&Compress::LZW::_detect_lsb_first,
  isa     => Bool,
);

=attr init_code_size

Default: 9

After the first three header bytes, input codes are expected tobegin at this
size. This is not stored in the resulting stream, so if this was altered from
default at compression, you I<must> supply the same value here.

May be between 9 and 31, inclusive.  An exception will be raised in decompress
if this value is already higher than the given stream's declared maximum code
size.

=cut

has init_code_size => (
  is      => 'ro',
  default => 9,
  isa     => Type::Tiny->new(
    parent => Int,
    constraint => sub { $_ >= 9 and $_ < $BITS_MASK },
    message    => sub { "$_ isn't between 9 and $BITS_MASK" },
  ),
);

has _block_mode => ( # can code table reset
  is      => 'rw',
  default => 1,
);

has _max_code_size => ( # max bits
  is      => 'rw',
  default => 16,
);

has _code_size => ( # current bits
  is       => 'rw',
  clearer  => 1,
  lazy     => 1,
  builder  => sub {
    $_[0]->init_code_size;
  },
);

has _buf => (
  is      => 'ro',
  clearer => 1,
  default => sub { \'' },
);

has _code_table => (
  is      => 'ro',
  lazy    => 1,
  clearer => 1,
  builder => sub {
    return {
      map { $_ => chr($_) } 0 .. 255
    }
  },
);

has _next_code => (
  is      => 'rw',
  lazy    => 1,
  clearer => 1,
  builder => sub {
    $_[0]->_block_mode ? 257 : 256;
  },
);


=method decompress ( $input )

Decompress $input with the current settings and returns the result.

=cut

sub decompress {
  my $self = shift;
  my ( $data ) = @_;

  $self->reset;

  my $codes = $self->_code_table;

  my $code_reader = $self->_begin_read( $data );
  
  my $init_code = $code_reader->();
  my $str = $codes->{ $init_code };
  
  my $seen = $init_code;
  while ( defined( my $code = $code_reader->() ) ){
    if ( $self->_block_mode and $code == $RESET_CODE ){
      #reset table, next code, and code size
      $self->_reset_code_table;
      
      # trigger the builder
      $codes = $self->_code_table;
      
      my $reinit_code = $code_reader->();
         $str .= $codes->{ $reinit_code };
         $seen = $reinit_code;
      
      next;
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
      $self->_inc_next_code;
      
      $codes->{$code} = $word . substr( $word, 0, 1 );
      
      $str .= $codes->{$code};
    }
    $seen = $code;
    
    # if next code expected will require a larger bit size
    if ( $self->_next_code == (2 ** $self->_code_size) ){
      $self->{_code_size}++ if $self->_code_size < $self->_max_code_size;
    }
    
  }
  return $str;
}

=method reset ()

Resets the decompressor state for another round of input. Automatically
called at the beginning of ->decompress.

Resets the following internal state: code table, next code number, code
size, output buffer

=cut

sub reset {
  my $self = shift;
  
  $self->_reset_code_table;
  $self->_clear_buf;
}

sub _reset_code_table {
  my $self = shift;
  
  $self->_clear_code_table;
  $self->_clear_next_code;
  $self->_clear_code_size;
}

sub _inc_next_code {
  my $self = shift;
  
  $self->_next_code( $self->_next_code + 1 );
}

sub _new_code {
  my $self = shift;
  my ( $data ) = @_;
  
  $self->_code_table->{ $self->_next_code } = $data;
  $self->_inc_next_code;
}


sub _begin_read {
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
  
  if ( $self->init_code_size > $self->_max_code_size ){
    die
      "Can't decompress stream with init_code_size " .
      $self->init_code_size .
      " > the stream's max_code_size ".
      $self->_max_code_size;
  }

  my $rpos = 8 * 3;  #reader position in bits;
  my $eof = length( $data ) * 8;
  
  my $code_reader = sub {
    
    my $code_size = $self->_code_size;
    
    return undef if ( $rpos > $eof );
    
    my $cpos = $self->lsb_first ? $rpos : ($rpos + $code_size - 1);
    
    my $code = 0;
    for ( 0 .. $code_size - 1 ){
      $code |=
        vec( $data, $cpos + ( $self->lsb_first ? $_ : (0 - $_) ), 1) << $_;
    }
    
    $rpos += $code_size;
    
    return undef if $code == 0 and $rpos > $eof;
    return $code;
    
  };

  return $code_reader;
}

1;
