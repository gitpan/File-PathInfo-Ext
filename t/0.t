use Test::Simple 'no_plan';
use strict;
use lib './lib';	
use File::PathInfo::Ext;
use Cwd;
use warnings;
use Carp;
File::PathInfo::RESOLVE_SYMLINKS =0;
File::PathInfo::Ext::DEBUG =0;

$ENV{DOCUMENT_ROOT} = cwd().'/t/public_html';


# test ones we know are in docroot
for (qw(
./t/public_html/demo
demo
./t/public_html/demo/hellokitty.gif
./t/public_html/demo/../demo/civil.txt
demo/../demo/civil.txt
demo/civil.txt
)){
	
	my $argument = $_;
	my $f = new File::PathInfo::Ext($argument) ;#or die( $File::PathInfo::Ext::errstr );

	ok($f);
	my $filename = $f->filename;

	$f->meta->{title} = 'hello';
	
	$f->meta_save;
	
	ok(-f $f->abs_loc.'/.'.$f->filename .'.meta','meta present');	

	# try rename
	my $newname = 'hahahahaha.hahaha';
	ok( $f->rename($newname) );
	# make sure meta was renamed
	ok(-f $f->abs_loc.'/.'.$newname.'.meta');
	ok($f->meta->{title} eq 'hello');

	# rename back

	$f->rename($filename);

	
	

	
	
	$f->meta_delete;
	
	ok( !(-f $f->abs_loc.'/.'.$f->filename .'.meta'),'meta gone');

	for (qw(ctime mtime nlink size blocks atime_pretty mtime_pretty ctime_pretty ino)){		
		ok($f->$_);
	}

}

my $x = new File::PathInfo::Ext;

mkdir $ENV{DOCUMENT_ROOT}.'/timp';
# test ones we know are in docroot
for (qw(
./demo ./demo/hellokitty.gif ./demo/civil.txt


)){


#./demo ./demo/hellokitty.gif ./demo/civil.txt



	my $rel = $_;
	
	$x->set($ENV{DOCUMENT_ROOT}."/$rel");
	
	$x->meta->{var} = 'yes';
	
	ok( $x->move($ENV{DOCUMENT_ROOT}.'/timp'),'move' );

	ok( !(-f $ENV{DOCUMENT_ROOT}."/$rel"),'gone ok' );

	ok($x->abs_loc eq $ENV{DOCUMENT_ROOT}.'/timp');

	ok($x->meta->{var} eq 'yes');

	ok($x->move("$ENV{DOCUMENT_ROOT}/$rel"),"move back to $rel");

}


