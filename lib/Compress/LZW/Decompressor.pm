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
