# Distributed under the terms of the GNU General Public License v2
# $Header: Exp $

EAPI=5

MODULE_AUTHOR=BDFOY
MODULE_VERSION=1.24_04
inherit perl-module

DESCRIPTION="Look up the vendor for a MAC"

SLOT="0"
KEYWORDS="~amd64 ~x86 ~x64-macos"
SRC_URI="https://github.com/briandfoy/net-mac-vendor/archive/release-1.24_04.zip -> ${P}.zip"
RESTRICT="nomirror"
IUSE=""

RDEPEND=""
DEPEND="${RDEPEND}
	virtual/perl-ExtUtils-MakeMaker
	dev-perl/Mojolicious
"

S="${WORKDIR}"/net-mac-vendor-release-"${PV/p}"

src_prepare() {
	perl_rm_files .releaserc lib/.releaserc 
	perl_rm_files Changes README.pod
}
