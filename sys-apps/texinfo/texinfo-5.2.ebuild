# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-apps/texinfo/texinfo-5.2.ebuild,v 1.7 2015/07/08 09:06:51 zlogene Exp $

EAPI="4"

inherit flag-o-matic

DESCRIPTION="The GNU info program and utilities"
HOMEPAGE="https://www.gnu.org/software/texinfo/"
SRC_URI="mirror://gnu/${PN}/${P}.tar.xz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="alpha amd64 arm arm64 hppa ia64 m68k ~mips ppc ppc64 s390 sh sparc x86 ~amd64-fbsd ~sparc-fbsd ~x86-fbsd"
KEYWORDS+="~ppc-aix ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~m68k-mint ~sparc-solaris ~sparc64-solaris ~x64-solaris ~x86-solaris"
IUSE="nls static"

RDEPEND="!=app-text/tetex-2*
	>=sys-libs/ncurses-5.2-r2
	dev-lang/perl
	dev-perl/libintl-perl
	dev-perl/Unicode-EastAsianWidth
	dev-perl/Text-Unidecode
	nls? ( virtual/libintl )"
DEPEND="${RDEPEND}
	app-arch/xz-utils
	nls? ( sys-devel/gettext )"

src_prepare() {
	epatch "${FILESDIR}"/"${PN}"-4.13-mint.patch
	epatch "${FILESDIR}"/"${P}"-terminal.patch
	# timestamps must be newer than configure.ac touched by prefix patch
	sed -i -e '1c\#!/usr/bin/env sh' util/texi2dvi util/texi2pdf || die
	touch doc/{texi2dvi,texi2pdf,pdftexi2dvi}.1
}

src_configure() {
	use static && append-ldflags -static
	econf \
		--with-external-libintl-perl \
		--with-external-Unicode-EastAsianWidth \
		--with-external-Text-Unidecode \
		$(use_enable nls)
}

src_install() {
	default
	newdoc info/README README.info
}
