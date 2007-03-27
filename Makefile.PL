use ExtUtils::MakeMaker;
WriteMakefile(
	NAME => 'File::PathInfo::Ext',
	VERSION_FROM => 'lib/File/PathInfo/Ext.pm',
	PREREQ_PM => {
		'File::PathInfo' => '1.12',
		YAML => '0.01',
		'File::Path' => '0.01',
	},
); 
