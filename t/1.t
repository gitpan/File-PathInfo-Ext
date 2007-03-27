use Test::Simple 'no_plan';
use strict;
use lib './lib';
use File::PathInfo::Ext;
use Cwd;
use warnings;
use Carp;
File::PathInfo::RESOLVE_SYMLINKS = 0;
File::PathInfo::DEBUG = 1;

$ENV{DOCUMENT_ROOT} = cwd().'/t/public_html';



`touch $ENV{DOCUMENT_ROOT}/test.file`;


my $f = new File::PathInfo::Ext("$ENV{DOCUMENT_ROOT}/test.file") ;#or die( $File::PathInfo::Ext::errstr );


ok($f->rename('bla1'));
ok( !($f->rename('awe/gfaw/egawg/\\pou*()^T)(T3wt//n23')));

ok($f->rename('test.file'));

unlink "$ENV{DOCUMENT_ROOT}/test.file";

