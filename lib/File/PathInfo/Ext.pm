package File::PathInfo::Ext;
use base 'File::PathInfo';
use strict;
use warnings;
use Carp;
use vars qw($VERSION);
$VERSION = sprintf "%d.%02d", q$Revision: 1.22 $ =~ /(\d+)/g;

# extended, with metadata
my $DEBUG=0; sub DEBUG : lvalue { $DEBUG }
my $META_HIDDEN=1; sub META_HIDDEN : lvalue { $META_HIDDEN }
my $META_EXT = 'meta'; sub META_EXT : lvalue { $META_EXT }

# TODO : rename must be able to fix up metadata
# 
sub debug { print STDERR __PACKAGE__.": @_\n" if DEBUG; return 1; }


sub rename {
	my ($self, $newname) =(shift, shift);
	
   debug('rename called');

   my $abs_path = $self->abs_path;
   my $abs_path_new = $self->abs_loc."/$newname";

	if ( -e  $abs_path_new ){
		carp(sprintf "cannot rename %s to %s, detination already exists.", 
         $abs_path, $abs_path_new );
		return 0;
	}

	unless( rename($abs_path, $abs_path_new) ){
		carp("cant rename $abs_path to $abs_path_new, destinaton exists.");
		return 0;
	}	

	# rename meta
	my $to;
   #	my $to = $self->abs_loc . ( META_HIDDEN ? "/.$newname." : "/$newname." ) . 
   #	META_EXT; # THIS CRASHES, why????

	if (META_HIDDEN){
		$to =  $self->abs_loc . "/.$newname.". META_EXT;
	}
	else {
		$to =  $self->abs_loc . "/$newname.".  META_EXT;
	}
	
   debug("meta renamed to $to");

	# both hidden and non hidden... hmmm 
   # TODO inspect this
	rename( $self->abs_loc .'/.'.$self->filename . '.' . META_EXT,  $to );
	rename( $self->abs_loc .'/' .$self->filename . '.' . META_EXT,  $to );

	$self->set($abs_path_new) or die($!);
	return $abs_path_new;
}




sub move {
	my ($self, $to) =(shift, shift);

	require File::Copy; 
		# using this in the package headers was causing a warning,
		# move redefined.. bla bla.. it is quite annoying to export by default
	debug("move() called [$to]");

	my $from_loc = $self->abs_loc 
      or croak('move() dont have abs_loc yet, set must have failed.');
	my $filename = $self->filename
      or croak('move() dont have filename yet, set must have failed.');

	
	# is the argument /a/dir/tomove/to/ ?
	if ($to=~s/\/$//){
		if (-d $to){
			$to.="/$filename";
         debug("move() argument was a dir, destination will be [$to]");
		}
		else {		
			carp("move() argument eneded in a slash, this means you want to move "
         ."it to at dir, but [$to] is not a dir");
			return 0;		
		}
	}

   # is destination same as source
   require Cwd;
   if ( Cwd::abs_path("$from_loc/$filename") eq $to ){
      debug("[$from_loc/$filename] source and destination are the same.");
      return $to;
   }


	if (-e $to){
		carp __PACKAGE__."::move() [$from_loc/$filename] to [$to] failed, already exists.";
		return 0;
	}


	# by now if arg was /a/path/2dir/ the filename was already appended
	my $to_loc= $to;
	$to_loc=~s/\/[^\/]+$//;
	
	unless( -d $to_loc ){ 
      carp ( __PACKAGE__."::move() [$from_loc/$filename] to [$to] failed,"
	   ." [$to_loc] is not a directory.") ;
      return 0;
   }
	
	unless( File::Copy::mv( "$from_loc/$filename", $to)){
		carp (__PACKAGE__."::move() cannot move [$from_loc/$filename] to [$to],"
      ."$! - check permissions?");
		return 0;
	}	
   debug("move() moved [$from_loc/$filename]to [$to]");
		
	# yea i know, if we havea '.file.ext' and a 'file.ext', they cannot both have meta.
	if (
		File::Copy::mv("$from_loc/.$filename.".META_EXT, "$to_loc/.$filename.".META_EXT ) or 
		File::Copy::mv("$from_loc/$filename.".META_EXT, "$to_loc/$filename.".META_EXT ) ){
		debug("move() moved meta.");
	}	

	$self->set($to) 
      or confess(__PACKAGE__."::move() moved [$from_loc/$filename]to [$to]"
      ." but cant set() after moving, $!");
	return $to;
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

sub ls_count {
	my $self = shift;
	$self->is_dir or return;
	my $count = scalar @{$self->ls};
	return $count;
}

sub lsd_count {
	my $self = shift;
	$self->is_dir or return;
	my $count = scalar @{$self->lsd};
	return $count;
}

sub lsf_count {
	my $self = shift;
	$self->is_dir or return;
	my $count = scalar @{$self->lsf};
	return $count;
}




# procedurals

sub get_meta {
	my $abs_path = shift; 	
	$abs_path or croak('get_meta() needs abs path as argument');
	META_EXT or croak('META_EXT must have a value');

	if( -f $abs_path.'.'.META_EXT){
			return YAML::LoadFile( $abs_path.'.'.META_EXT );
	}
	
	# try hidden
	my $abs_meta = $abs_path;
	$abs_meta=~s/\/([^\/]+)$/\/.$1./;
	$abs_meta.= META_EXT;

	debug("Searching for [$abs_meta]");

	if (-f $abs_meta) {
			return YAML::LoadFile( $abs_meta );
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
   require YAML;
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

sub md5_hex {
	my $self = shift;
	$self->is_file 
      or warn(sprintf "md5() doesnt worlk for dirs: %s",$self->abs_path) 
      and return;
	
	unless( exists $self->{_data}->{md5_hex}){
		require Digest::MD5;
		my $file = $self->abs_path;

		my $sum = Digest::MD5::md5_hex($file);

		$sum ||=undef;
		$sum or warn("cant get md5sum of $file");
		$self->{_data}->{md5_hex} = $sum;
		
	}
	return $self->{_data}->{md5_hex};
}

sub mime_type {
   my $self = shift;
   unless( exists $self->{_data}->{mime_type} ){
      require File::Type;
      my $mm = new File::Type;

      my $res = $mm->checktype_filename($self->abs_path);
      #my $res = $mm->mime_type($self->abs_path);
      $self->{_data}->{mime_type} = $res;

   }
   return $self->{_data}->{mime_type};

}



1;


__END__

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
Added is a simple api for YAML metadata files associated to the file the object instance is based on.
Also a way to rename the file, and move the file- maintaining the metadata YAML file association.

This software is still under development.

=head1 METHODS

These are added methods to the usual L<File::PathInfo> methods.

=head2 ls() and lsa()

takes no argument
returns array ref of files (and dirs and everything else). No . and ..
returns undef if it's not a dir

lsa() returns absolute paths, not just filename.

=head2 lsf() and lsfa()

returns array ref of files (-f) in dir. 
returns undef if it's not a dir.

lsfa() returns absolute paths, not just filename.

=head2 lsd() and lsda()

returns array ref of dirs (-d) in dir. 
returns undef if it's not a dir.

lsda() returns absolute paths, not just filename.

=head2 ls_count()

number of entries in directory, returns undef if not a dir

=head2 lsd_count()

number of directory entries in directory, returns undef if not a dir

=head2 lsf_count()

number of file entries in directory, returns undef if not a dir


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

argument is absolute path to a directory to move to
or argument is absolute destination of where to move to.

	$f->move('/home/myself/newdocs/');
	
	$f->move('/home/myself/newdocs/great.pdf');
	
If a trailing slash is present, then it is checked if it is a directory,
and the file is move there.

If the destination exists, it will not move and carp that it already exists,
returns false.
(Note that after moving or renaming, the other file info is automatically
updated, such as abs_loc() and rel_path() etc.)
The meta file is moved also if it exists. That is part why one would consider using
this move instead of File::Copy::move.

returns abs path of where the file moved to

=head2 rename()

Argument is new filename. New filename cannot have /\ characters, etc.
This rename makes it so if you have a meta file, it is renamed also.

	$f->rename('blah') or die'cant rename';

If the file you are renaming to already exists, a carps and returns false. It will not
overrite an existing file. You must first delete the exisitng file or rename to something else.


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



=head1 DIGEST

=head2 md5_hex()

returns md5 sum of file contents, cached in object {_data}
if getting the md5sum digest does not work, returns undef
see L<Digest::MD5>






=head1 SEE ALSO

See also L<File::PathInfo>, L<YAML>, L<File::Attributes>, L<File::Copy>.

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
	
