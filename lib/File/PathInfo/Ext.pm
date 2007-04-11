package File::PathInfo::Ext;
use base 'File::PathInfo';
use strict;
use warnings;
use File::Copy;
use YAML;
use Carp;
=pod

=head1 NAME

File::PathInfo::Ext - metadata files, renaming, some other things on top of PathInfo

=head1 SYNOPSIS

	use File::PathInfo::Ext;

	my $f = new File::PathInfo::Ext('/home/myself/thisfile.pdf');

	$f->meta_save({ keywords => 'salt, pepper, lemon, ginger' });

	printf "keywords are: %s\n", $f->meta->{keywords};

	$f->rename('thatfile.pdf');

	printf "filename is now %s\n", $f->filename;
	printf "keywords are still: %s\n", $f->meta->{keywords};	
	

=head1 DESCRIPTION

This extends File::PathInfo.
Added is a simple api for YAML metadata files. Also a way to rename the file, and 
maintain the metadata file (YAML file).

This software is still under development.

=head1 METHODS

These are added methods to the usual L<File::PathInfo> methods.

=cut

#use vars qw($VERSION);
our $VERSION = sprintf "%d.%02d", q$Revision: 1.7 $ =~ /(\d+)/g;

# extended, with metadata
my $DEBUG=0; sub DEBUG : lvalue { $DEBUG }
my $META_HIDDEN=1; sub META_HIDDEN : lvalue { $META_HIDDEN }
my $META_EXT = 'meta'; sub META_EXT : lvalue { $META_EXT }

# TODO : rename must be able to fix up metadata




sub rename {
	my ($self, $newname) =(shift, shift);
	
	print STDERR __PACKAGE__."::rename called\n" if DEBUG;

	unless( rename( $self->abs_path, $self->abs_loc ."/$newname")){
		carp ('cant rename '.$self->abs_path .' to '.$self->abs_loc ."/$newname, $!");
		return 0;
	}	
	# rename meta
	my $to;
#	my $to = $self->abs_loc . ( META_HIDDEN ? "/.$newname." : "/$newname." ) . META_EXT; # THIS CRASHES, why????

	if (META_HIDDEN){
		$to =  $self->abs_loc . "/.$newname.". META_EXT;
	}
	else {
		$to =  $self->abs_loc . "/$newname.". META_EXT;
	}
	
	print STDERR "meta renamed to [$to]\n" if DEBUG;

	# both hidden and non hidden
	rename( $self->abs_loc .'/.'.$self->filename . '.' . META_EXT,  $to );
	rename( $self->abs_loc .'/' .$self->filename . '.' . META_EXT,  $to );

	$self->set($self->abs_loc .'/'.$newname) or die($!);
	return 1;
}




sub move {
	my ($self, $to) =(shift, shift);
	print STDERR __PACKAGE__."::move called [$to]\n" if DEBUG;

	my $from_loc = $self->abs_loc or die;
	my $filename = $self->filename or die;
	
	if (-d $to){
		print STDERR "move 'to' is a dir, will move there. " if DEBUG;
		$to.='/'.$filename;
	}

	if (-e $to){
		carp __PACKAGE__."::move() [$from_loc/$filename] to [$to] failed, already exists.";
		return 0;
	}

	print STDERR "from $from_loc/$filename\nto $to\n" if DEBUG;

	my $to_loc= $to;
	$to_loc=~s/\/[^\/]+$//;
	
	-d $to_loc or carp __PACKAGE__."::move() [$from_loc/$filename] to [$to] failed, [$to_loc] is not a directory." and return 0;
	
	unless( File::Copy::mv( "$from_loc/$filename", $to)){
		carp ("cant move [$from_loc/$filename] to [$to], $! - check permissions?");
		return 0;
	}	
	print STDERR "moved [$from_loc/$filename]to [$to]\n" if DEBUG;
		
	File::Copy::mv("$from_loc/.$filename.".META_EXT, "$to_loc/.$filename.".META_EXT );
	File::Copy::mv("$from_loc/$filename.".META_EXT, "$to_loc/$filename.".META_EXT );

	print STDERR "moved meta\n"if DEBUG;

	$self->set($to) or die("cant set to [$to] after moving, $!");
	return 1;
}





sub meta {
	my $self = shift;
	$self->{meta} ||= get_meta($self->abs_path);
	$self->{meta} ||= {};
	return $self->{meta};
}

sub meta_save {
	my $self = shift;
	set_meta($self->abs_path,$self->meta);
	return 1;
}

sub meta_delete {
	my $self = shift;
	delete_meta($self->abs_path);
	$self->{meta} = {};
	return 1;
}






# list 

sub ls {
	my $self = shift;
	$self->is_dir or return;

	unless(defined $self->{_data}->{ls}){
		printf STDERR "ls for [%s]\n", $self->abs_path if DEBUG;
		opendir(DIR, $self->abs_path);
		my @ls = grep { !/^\.+$/ } readdir DIR;
		close DIR;
		### @ls
		$self->{_data}->{ls}  = \@ls;
	}
	return $self->{_data}->{ls};
}

sub lsa {
	my $self = shift;
	$self->is_dir or return;	
	my @ls; for (@{$self->ls}){ push @ls, $self->abs_path.'/'.$_;	}
	return \@ls;
}

=head2 ls() and lsa()

takes no argument
returns array ref of files (and dirs and everything else). No . and ..
returns undef if it's not a dir

lsa() returns absolute paths, not just filename.

=cut

sub lsf {
	my $self = shift;	
	$self->is_dir or return;	
	unless( defined $self->{_data}->{_lsf_}){
		@{$self->{_data}->{_lsf_}} = grep { -f $self->abs_path .'/'. $_ } @{$self->ls};
	}
	return $self->{_data}->{_lsf_};	
}

sub lsfa {
	my $self = shift;	
	$self->is_dir or return;	
	my @ls; for (@{$self->lsf}){ push @ls, $self->abs_path.'/'.$_;	}
	return \@ls;
}


=head2 lsf() and lsfa()

returns array ref of files (-f) in dir. 
returns undef if it's not a dir.

lsfa() returns absolute paths, not just filename.

=cut 

sub lsd {
	my $self = shift;	
	$self->is_dir or return;	
	unless( defined $self->{_data}->{_lsd_}){
		@{$self->{_data}->{_lsd_}} = grep { -d $self->abs_path .'/'. $_ } @{$self->ls};
	}
	return $self->{_data}->{_lsd_};	
}

sub lsda {
	my $self = shift;	
	$self->is_dir or return;	
	my @ls; for (@{$self->lsd}){ push @ls, $self->abs_path.'/'.$_;	}
	return \@ls;
}


=head2 lsd() and lsda()

returns array ref of dirs (-d) in dir. 
returns undef if it's not a dir.

lsda() returns absolute paths, not just filename.

=cut







# procedurals

sub get_meta {
	my $abs_path = shift; 	
	$abs_path or croak('get_meta() needs abs path as argument');
	META_EXT or croak('META_EXT must have a value');

	if( -f $abs_path.'.'.META_EXT){
			my $meta = YAML::LoadFile( $abs_path.'.'.META_EXT );   
			return $meta;
	}
	
	# try hidden
	my $abs_meta = $abs_path;
	$abs_meta=~s/\/([^\/]+)$/\/.$1./;
	$abs_meta.= META_EXT;
	print STDERR "searching for [$abs_meta]\n" if DEBUG;
	if (-f $abs_meta) {
			my $meta = YAML::LoadFile( $abs_meta );
			return $meta;
	}
	return;
}

sub set_meta {
	my ($abs_path, $meta) = (shift,shift);
	$abs_path or croak('set_meta() needs abs path as argument');
	ref $meta eq 'HASH'
		or croak('second argument to set_meta() must be a hash ref');	
	META_EXT or croak('META_EXT must have a value');

	unless( keys %$meta){
		delete_meta($abs_path);
		return 1;
	}
	
	$abs_path=~s/^(.+\/)([^\/]+$)/$1.$2/ if META_HIDDEN;	
	YAML::DumpFile($abs_path .'.'.META_EXT,$meta);	
	return 1;
}

sub delete_meta {
	my $abs_path = shift;
	$abs_path or croak('delete_meta() needs abs path as argument');
	META_EXT or croak('META_EXT must have a value');
	
	# try hidden and non hidden, all.	
	my $regular = $abs_path .'.'.META_EXT;
	return 1 if unlink $regular;

	my $hidden = $regular;
	$hidden=~s/^(.+\/)([^\/]+$)/$1.$2/;
	unlink $hidden;

	return 1;
} 


sub is_empty_dir {
	my $self = shift;
	$self->is_dir or return 0;
	
	scalar @{$self->ls} or return 1;
	return 0;
}


sub get_datahash {
	my $self = shift;
	
	my $hash = $self->SUPER::get_datahash;
	$hash->{is_empty_dir} = $self->is_empty_dir;
	return $hash;
	
}


=pod

=head2 meta()

takes no argument, like L<get_meta()>
returns hash ref with metadata for file.

=head2 meta_save()

takes no argument, like L<set_meta>
returns true. 
Saves the current metadata to disk.

=head2 meta_delete()

Takes no argument. 
Makes sure file does not have a meta file associated with it.

=head2 move()

argument is new dir to move to, or new destination

	$f->move('/home/myself/newdocs');

If the destination is a dir, the file or dir will be moved there
If it is a file, it will not move and carp that it already exists.
note that after moving or renaming, the other file info is automatically
updated, such as abs_loc() and rel_path() etc.
	

=head2 rename()

Argument is new filename.
This rename makes it so if you have a meta file, it is renamed also.

	$f->rename('blah') or die'cant rename';

=head1 USAGE EXAMPLES

I adore this little module. I use it a lot.
Here are some examples of how to use it, and you'll see why I like it.

=head2 using meta() and meta_save()

=over 4

=item Example 1

	use File::PathInfo::Ext;

	my $f = new File::PathInfo::Ext('/home/myself/documents/doc1.pdf');
	
	$f->meta_save({ title => 'great title here', keywords => [qw(food spices mice cats)]});

This creates the YAML file '/home/myself/documents/.doc1.pdf.meta':

	---
	title: 'great title here'
	keywords:
	 - food
	 - spices
	 - mice
	 - cats

So if you call meta(), you get the title.
This is really useful if you want to be able to simply add info to a file via vim or notepad.

=item Example 2

What if you don't want to have the files hidden, and you want to use another extension?

	use File::PathInfo;
	File::PathInfo::Ext::META_EXT = 'data';
	File::PathInfo::Ext::META_HIDDEN = 0;	

	my $f = new File::PathInfo('/home/myself/documents/doc1.pdf');
	$f->meta_save({ title => 'great title here', keywords => [qw(food spices mice cats)]});

And then..

	printf "Title for this file %s\n", $f->meta->{title};

Add some more stuff

	$f->meta->{age} = 24;
	$f->meta->{state} = 'WY';

And save it

	$f->meta_save;	

To erase it

	$f->meta_delete

Furthermore what if you want to rename the file without losing the metadata (which is associated
by filename)

	$f->rename('newname.whatever');

=item Example 3

A more real world example. If you're a unix minion like me, you swear by the cli. So, I want
to be able to edit metadata with vim for anything.
Maybe I'm keeping an archive of scanned documents.. and I want to remember that file 
/home/docs/document1.pdf is authored by Joe, and that it's a replacement for another file.
So I simply do 'vim /home/docs/.document1.pdf.meta' and enter:

	---
	author:joe
	description: this is not the original. The other one got eaten by my dog.

You can see how useful this can be if you're maintaining a client website, or a large
archive of mundane data.

=head1 PROCEDURAL SUBROUTINES

None of these are exported by default.

=head2 get_meta()

argument is absolute path to a file on disk
returns metadata hash if found. (YAML).


=head2 set_meta()

argument is absolute path and hash ref with metadata
if the hash ref is empty, will attempt to delete existing metadata
file.

does NOT check to see if the file exists.

	set_meta('/home/file',{ name => 'hi', age => 4 });
	
Above example creates meta file '/home/file.meta' :

	---
	name: hi
	age: 4

If you wish all metadata files to be hidden;

	use File::PathInfo;
	File::PathInfo::META_HIDDEN = 1;	

See also: L<YAML>

=head2 delete_meta()

argument is absolute path to file the meta is for.
will delete hidden as well as non-hidden meta.

	delete_meta('/home/myself/document');

Deletes /home/myself/document.meta and /home/myself/.document.meta
This is just to assure a file does not have metadata anymore.

=head1 SEE ALSO

See also L<File::PathInfo>, L<YAML>, and L<File::Attributes>.

=head1 PACKAGE SETTINGS

Metadata files can be hidden (prepended by period). 

	File::PathInfo::Ext::META_HIDDEN = 1;	

Metadata ext, by default .meta

	File::PathInfo::Ext::META_EXT = meta;

Debug

	File::PathInfo::Ext::DEBUG = 1;	

=head1 BUGS

Yes. No doubt.
Please forwards any bug detection to author.

=head1 AUTHOR

Leo Charre leocharre at cpan dot org
	
=cut

1;

