# NAME

Compress::LZW - Pure-Perl implementation of scaling LZW

# VERSION

version 0.05

# SYNOPSIS

    use Compress::LZW;
     
    my $compressed = compress($some_data);
    my $data       = decompress($compressed);

# DESCRIPTION

`Compress::LZW` is a perl implementation of the Lempel-Ziv-Welch compression
algorithm, which should no longer be patented worldwide.  It is shooting for
loose compatibility with the flavor of LZW found in the classic UNIX
compress(1), though there are a few variations out there today.  I test against
ncompress on Linux x86.

# FUNCTIONS

## compress

Accepts a scalar, returns compressed data in a scalar.

Wraps [Compress::LZW::Compressor](https://metacpan.org/pod/Compress::LZW::Compressor)

## decompress

Accepts a (compressed) scalar, returns decompressed data in a scalar.

Wraps [Compress::LZW::Decompressor](https://metacpan.org/pod/Compress::LZW::Decompressor)

# EXPORTS

Default: `compress` `decompress`

# SEE ALSO

The implementations, [Compress::LZW::Compressor](https://metacpan.org/pod/Compress::LZW::Compressor) and
[Compress::LZW::Decompressor](https://metacpan.org/pod/Compress::LZW::Decompressor).

Other Compress::\* modules, especially Compress::LZV1, Compress::LZF and
Compress::Zlib.

I definitely studied some other implementations that deserve credit, in
particular: Sean O'Rourke, <SEANO> - Original author,
`Compress::SelfExtracting`, and another by Rocco Caputo which was posted
online.

# AUTHOR

Meredith Howard <mhoward@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2019 by Meredith Howard.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
