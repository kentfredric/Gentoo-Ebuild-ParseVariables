use strict;
use warnings;

package Gentoo::Ebuild::ParseVariables;
# ABSTRACT: Query variables in ebuilds

BEGIN {
	$Gentoo::Ebuild::ParseVariables::VERSION = '0.0.1';
}

use Sub::Exporter -setup => { exports => [qw( gentoo_ebuild_var )] };
use Shell::EnvImporter;
use File::ShareDir;
use File::Temp qw( tempfile tempdir );
use File::Basename qw( basename );

sub gentoo_ebuild_var {

	my ( $ebuild, $ebuild_vars, $portdir ) = @_;
	$ebuild_vars ||= _ebuild_vars();
	$portdir     ||= "/usr/portage";

	my $td = tempdir();

	my $fixed_eclasses = File::ShareDir::module_dir('Gentoo::Ebuild::ParseVariables');
	my $ebuildsh       = File::ShareDir::module_file('Gentoo::Ebuild::ParseVariables','ebuild.sh');

	$ebuild =~ qr,(?<repo>.+)/(?<category>[^/]+)/(?<package>[^/]+)/\g{package}-(?<version>.+)\.ebuild,;
	my $repo     = $+{repo};
	my $category = $+{category};
	my $pn       = $+{package};
	my $pvr      = $+{version};
	(my $pv       = $pvr )=~ s/-r[0-9]+$//;
	my $pr = ( $pvr =~ m{.*-(r[0-9]+)$} )? $1 : "r0";

	my $repo_name = basename $repo;
	if ( -e "$repo/profiles/repo_name" ) {
		$repo_name = do {
			open my $fh, '<:raw', "$repo/profiles/repo_name" or die "Cant open repo_name $!";
			local $/ = undef;
			<$fh>;
		};
	}
	my ( $fh, $filename ) = tempfile();
	print {$fh} "unset $_;\n" for ( @{$ebuild_vars} );
	print {$fh} "export CATEGORY=$category\n";
	print {$fh} "export EBUILD=$ebuild\n";
	print {$fh} "export EBUILD_MASTER_PID=$$\n";
	print {$fh} "export EBUILD_PHASE=depend\n";
	print {$fh} "export ECLASSDIR=$portdir/eclass\n";
	print {$fh} "export P=$pn-$pv\n";
	print {$fh} "export PF=$pn-$pvr\n";
	print {$fh} "export PN=$pn\n";
	print {$fh} "export PORTAGE_BIN_PATH='$fixed_eclasses'\n";
	print {$fh} "export PORTAGE_ECLASS_LOCATIONS='$fixed_eclasses $repo'\n";
	print {$fh} "export PORTAGE_PIPE_FD=2\n";
	print {$fh} "export PORTAGE_REPO_NAME=$repo_name\n";
	print {$fh} "export PORTAGE_TMPDIR='$td'\n";
	print {$fh} "export PORTDIR_OVERLAY='$repo $fixed_eclasses'\n";
	print {$fh} "export PR=$pr\n";
	print {$fh} "export PV=$pv\n";
	print {$fh} "export PVR=$pvr\n";
	print {$fh} "source $ebuildsh\n";
	close $fh;

	my $sourcer  = Shell::EnvImporter->new(
		shell       => 'bash',
		command     => "source $filename",
		debuglevel  => 0,
		auto_run    => 0,
		auto_import => 0,
	);
	#
	$sourcer->shellobj->envcmd('set');
	$sourcer->run;
	$sourcer->env_import($ebuild_vars);
	my $retval = {};
	for my $var ( @{$ebuild_vars} ) {
		$retval->{$var} = _sanitize($ENV{$var}) if defined $ENV{$var};
	}
	$sourcer->restore_env();
	return $retval;
}

sub _sanitize {
	my ($v) = @_;
	$v=~s/^\$'(.*)'$/$1/m;
	$v=~s/^'(.*)'$/$1/m;
	$v=~s/'\\''/'/g;
	$v=~s/\\'/'/g;
	$v=~s/\\[tn]/ /g;
	$v=~s/^\s+//;
	$v=~s/\s+$//;
	$v=~s/\s{2,}/ /g;
	return $v;
}

sub _ebuild_vars {
	return [ qw(
		EAPI

		MODULE_AUTHOR
		MODULE_SECTION
		MODULE_VERSION
		MODULE_A
		MODULE_EXT
		MODULE_PN
		MODULE_PV
		CATEGORY
		P
		PN
		PV
		PVR
		PF
		MY_P
		MY_PN
		MY_PV

		DESCRIPTION
		HOMEPAGE
		SRC_URI

		LICENSE
		SLOT
		KEYWORDS
		IUSE

		DEPEND
		RDEPEND
		PDEPEND

		SRC_TEST
		INHERITED
		DEFINED_PHASES
		RESTRICT
		REQUIRED_USE
		) ];
};

1;
