
use strict;
use warnings;

use Test::More;
use Path::Tiny qw( path );
use Test::File::ShareDir::Module {
    'Gentoo::Ebuild::ParseVariables' => 'share/';
};
use Gentoo::Ebuild::ParseVariables qw( gentoo_ebuild_var );
use Test::TempDir::Tiny qw( tempdir );

# ABSTRACT: Test sourcing

in_tempdir(
    "fake-overlay" => sub {
        path('eclass')->mkpath;
        path('dev-perl/example')->mkpath;
        path('profiles')->mkpath;
        path('metadata')->mkpath;
        path('profiles/repo_name')->spew_raw('fake-overlay');
        path('layout.conf')->spew_raw(<<'EOF');
masters = gentoo
EOF
        path('eclass/perl-module.eclass')->spew_raw(<<'EOF');
RDEPEND="dev-lang/perl:="
EOF
        path('dev-perl/example/example-1.1.0.ebuild')->spew_raw(<<'EOF');
EAPI=5

inherit perl-module
RDEPEND="virtual/perl-ExtUtils-MakeMaker"
DEPEND="${RDEPEND}"

EOF
        my $hash =
          gentoo_ebuild_var(
            path('dev-perl/example/example-1.1.0.ebuild')->absolute,
          );
        note explain $hash;
        ok( exists $hash->{RDEPEND}, 'RDEPEND exists' );
        like(
            $hash->{DEPEND},
            qr/virtual\/perl-ExtUtils-MakeMaker/,
            'RDEPEND interpolated'
        );
        like( $hash->{RDEPEND}, qr/dev-lang\/perl/,
            'RDEPEND in eclass propagated' );
    }
);

done_testing;

use Cwd qw/abs_path/;

sub in_tempdir {
    my ( $label, $code ) = @_;
    my $wantarray = wantarray;
    my $cwd       = abs_path(".");
    my $tempdir   = tempdir($label);

    chdir $tempdir or die "Can't chdir to '$tempdir'";
    my (@ret);
    my $ok = eval {
        if ($wantarray) {
            @ret = $code->($tempdir);
        }
        elsif ( defined $wantarray ) {
            $ret[0] = $code->($tempdir);
        }
        else {
            $code->($tempdir);
        }
        1;
    };
    my $err = $@;
    chdir $cwd or chdir "/" or die "Can't chdir to either '$cwd' or '/'";
    die $err if !$ok;
    return $wantarray ? @ret : $ret[0];
}
