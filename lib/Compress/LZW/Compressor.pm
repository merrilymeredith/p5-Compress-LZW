package Compress::LZW::Compressor;
# ABSTRACT: Scaling LZW compressor class

=head1 SYNOPSIS

 use Compress::LZW::Compressor;
  
 my $c = Compress::LZW::Compressor->new();
 my $compressed = $c->compress($some_data);
  
=cut


use Compress::LZW qw(:const);

use Moo;
use namespace::clean;

has block_mode => (
  is      => 'ro',
  default => 1,
);

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
  builder  => sub {
    $_[0]->init_code_size;
  },
);

has _buf => (
  is      => 'lazy',
  clearer => 1,
  builder => sub {
    my $self = shift;
    
    my $buf = $MAGIC
      . chr( $self->max_code_size | ( $self->block_mode ? $BLOCK_MASK : 0 ) );
       
    $self->_buf_size( length($buf) * 8 );
    return \$buf;
  },
);

has _buf_size => ( #track our endpoint in bits
  is      => 'rw',
);

has _code_table => (
  is      => 'ro',
  lazy    => 1,
  clearer => 1,
  builder => sub {
    return {
      map { chr($_) => $_ } 0 .. 255
    };
  },
);

has _next_code => (
  is      => 'rw',
  lazy    => 1,
  clearer => 1,
  builder => sub {
    $_[0]->block_mode ? 257 : 256;
  },
);



sub _reset_code_table {
  my $self = shift;
  
  $self->_clear_code_table;
  $self->_clear_next_code;
  $self->_clear_code_size;
}

sub reset {
  my $self = shift;
  
  $self->_reset_code_table;
  $self->_clear_buf;
  $self->_buf_size( 0 );
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
    elsif ( $self->block_mode ){
      # FINISHME
      # if compress(1) comparable we need to do a code table reset
      # ... when the ratio falls after reaching this point.
      # this doesn't need to be perfect, the only part that needs
      # match algorithm-wise is what code tables are built the same
      # after a reset.
      warn "Resetting code table at $code";
      $self->_reset_code_table;
      $self->_buf_write( $RESET_CODE );
    }
  }
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
  
  $self->reset;
  
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
  
  return ${ $self->_buf };
}

1;
