# vim: ft=perl

requires 'perl', '5.10.0';

requires 'Moo', '1.001000';
requires 'Type::Tiny';
requires 'namespace::clean';

on test => sub {
  requires 'strictures';
  requires 'Test::More', '0.96';
};

