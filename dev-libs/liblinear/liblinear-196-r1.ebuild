# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id: 959b5e8cfee01d708d73cf89500ef8dd9cb03ba0 $

EAPI=5
inherit eutils multilib toolchain-funcs

DESCRIPTION="A Library for Large Linear Classification"
HOMEPAGE="http://www.csie.ntu.edu.tw/~cjlin/liblinear/ https://github.com/cjlin1/liblinear"
SRC_URI="https://github.com/cjlin1/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="alpha amd64 arm hppa ia64 ~mips ppc ppc64 ~s390 ~sh sparc x86"

src_prepare() {
	# Contains broken symlinks to some guy's home directory...
	rm -rf matlab
	rm -rf windows

	sed -i \
		-e '/^AR/s|=|?=|g' \
		-e '/^RANLIB/s|=|?=|g' \
		-e '/^CFLAGS/d;/^CXXFLAGS/d' \
		blas/Makefile || die

	epatch "${FILESDIR}"/${PN}-194-Makefile.patch || die
}

src_compile() {
	CC=$(tc-getCC) \
		CXX=$(tc-getCXX) \
		CFLAGS="${CFLAGS} -fPIC" \
		CXXFLAGS="${CXXFLAGS} -fPIC" \
		AR="$(tc-getAR) rcv" \
		RANLIB="$(tc-getRANLIB)" \
		emake lib all
}

src_install() {
	dolib ${PN}$(get_libname 2)
	dosym ${PN}$(get_libname 2) /usr/$(get_libdir)/${PN}$(get_libname)

	newbin predict ${PN}-predict
	newbin train ${PN}-train

	insinto /usr/include
	doins linear.h

	dodoc README
}
