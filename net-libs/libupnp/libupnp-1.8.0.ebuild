# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id: 32baec6ad6fa2b067ebd5dfafc6f2dda59519543 $

EAPI=6

inherit autotools eutils flag-o-matic vcs-snapshot

DESCRIPTION="A Portable Open Source UPnP Development Kit" # forked in 2008 from upstream libupnp-1.6.6
HOMEPAGE="http://pupnp.sourceforge.net/"
SRC_URI="https://github.com/mrjimenez/pupnp/archive/release-${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="1.8"
KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ppc ~ppc64 ~sparc ~x86 ~amd64-fbsd ~x86-fbsd ~amd64-linux"
IUSE="+client debug doc examples ipv6 static-libs +tools +server +webserver"
REQUIRED_USE="!server? ( !webserver )"

DOCS="NEWS README.md ChangeLog"

PATCHES=(
	"${FILESDIR}"/${P}-docs-install.patch
	"${FILESDIR}"/${PN}-1.6.21-cflags.patch
	"${FILESDIR}"/${P}-suse.patch
)

src_prepare() {
	default

	# fix tests
	chmod +x ixml/test/test_document.sh || die

	eautoreconf
}

src_configure() {
	use x86-fbsd &&	append-flags -O1
	# w/o docdir to avoid sandbox violations
	econf \
		$(use_enable client) \
		$(use_enable debug) \
		$(use_enable ipv6) \
		$(use_enable server device) \
		$(use_enable static-libs static) \
		$(use_enable tools) \
		$(use_enable webserver) \
		$(use_with doc documentation "${EPREFIX}/usr/share/doc/${PF}")
}

src_install () {
	default
	use client && use server && use examples && dobin upnp/sample/.libs/tv_{combo,ctrlpt,device}-1.8
	use static-libs || prune_libtool_files
}
