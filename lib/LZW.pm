############################################################
package Compress::LZW;
require Exporter;

use Carp;
use vars qw/@ISA @EXPORT $VERSION/;
use warnings;
use strict;

@EXPORT = qw/compress decompress/;;
@ISA = qw/Exporter/;
$VERSION = 0.01;

my (%LZ, %UNLZ, %SA);
%LZ = (12 => sub {
                 my $v = '';
                 for my $i (0..$#_) {
                     vec($v, 3*$i, 4) = $_[$i]/256;
                     vec($v, 3*$i+1, 4) = ($_[$i]/16)%16;
                     vec($v, 3*$i+2, 4) = $_[$i]%16;
                 }
                 $v;
             },
       16 => sub { pack 'S*', @_ });
%UNLZ = (12 => sub {
                   my $code = shift;
                   my @code;
                   my $len = length($code);
                   my $reallen = 2*$len/3;
                   foreach (0..$reallen - 1) {
                       push @code, (vec($code, 3*$_, 4)<<8)
                       | (vec($code, 3*$_+1, 4)<<4)
                       | (vec($code, 3*$_+2, 4));
                   }
                   @code;
               },
         16 => sub { unpack 'S*', shift; });

sub compress {
    my ($str, $bits) = @_;
    $bits = $bits ? $bits : 16;
    my $p = ''; 
    my %d = map{(chr $_, $_)} 0..255;
    my @o = ();
    my $ncw = 256;
    
    for (split '', $str) {
        if (exists $d{$p.$_}) {
            $p .= $_;
        } else {
            push @o, $d{$p};
            $d{$p.$_} = $ncw++;
            $p = $_;
        }
    }
    push @o, $d{$p};
    
    if ($bits != 16 && $ncw < 1<<12) {
        $bits = 12;
        return $LZ{12}->(@o);
    } elsif ($ncw < 1<<16) {
        $bits = 16;
        return $LZ{16}->(@o);
    } else {
        croak "Sorry, code-word overflow";
    }
}

sub decompress {
    my ($str, $bits) = @_;
    $bits = $bits ? $bits : 16;
    
    my %d = (map{($_, chr $_)} 0..255);
    my $ncw = 256;
    my $ret = '';
    
    my ($p, @code) = $UNLZ{$bits}->($str);
    
    $ret .= $d{$p};
    for (@code) {
        if (exists $d{$_}) {
            $ret .= $d{$_};
            $d{$ncw++} = $d{$p}.substr($d{$_}, 0, 1);
        } else {
            my $dp = $d{$p};
            unless ($_ == $ncw++) { carp "($_ == $ncw)?! Check your table size!" };
            $ret .= ($d{$_} = $dp.substr($dp, 0, 1));
        }
        $p = $_;
    }
    $ret;
}


############################################################


package Compress::LZW::WriterQueue;

sub new {
	my $class = shift;
	my $self  = {
		queue	=> [],
		bits	=> 8,
		maxbits	=> 16,
 	};
		
	bless $self, $class;
	return $self;
}

sub queue_length {
	my $self = shift;
	
	return scalar @{ $self->{queue} };
}

sub push {
	my $self = shift;
	my $code = shift;
	
	push @{ $self->{queue} }, $code;
	
	return $self->flush_queue();
}

sub flush_queue {
	my $self = shift;
	
	my $out;
	
	if ( $self->queue_length > 8 ) ){
		
		my $buf;
		for ( 1 .. 8 ){
			if ( length $buf >= 8 ){
				my $end = length($buf) * 8;
				
				vec( $buf, $end, 8 ) = pack('b8', substr($buf,0,8,''));
			}
			
			my $code = shift @{ $self->{queue} };
			
			if ( $code > ( 2 ** $self->{bits} ) ){
				$self->{bits++};
			}
			
			$buf .= sprintf('%b', $code);
		}
		
	}
	
	return '';
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
