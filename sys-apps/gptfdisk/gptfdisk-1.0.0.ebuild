# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id: 249a9d2bf213f5a0ca4ac8b282beb95e73c48f18 $

EAPI=5

inherit flag-o-matic toolchain-funcs

DESCRIPTION="GPT partition table manipulator for Linux"
HOMEPAGE="http://www.rodsbooks.com/gdisk/"
SRC_URI="mirror://sourceforge/${PN}/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~ia64 ~mips ~ppc ~ppc64 ~sparc ~x86 ~amd64-linux ~arm-linux ~x86-linux"
IUSE="kernel_linux ncurses static"

LIB_DEPEND="
	dev-libs/popt[static-libs(+)]
	ncurses? ( >=sys-libs/ncurses-5.7-r7:0=[static-libs(+)] )
	kernel_linux? ( sys-apps/util-linux[static-libs(+)] )" # libuuid
RDEPEND="!static? ( ${LIB_DEPEND//\[static-libs(+)]} )"
DEPEND="${RDEPEND}
	static? ( ${LIB_DEPEND} )
	virtual/pkgconfig"

src_prepare() {
	tc-export CXX PKG_CONFIG

	if ! use ncurses; then
		sed -i \
			-e '/^all:/s:cgdisk::' \
			Makefile || die
	fi

	sed \
		-e '/g++/s:=:?=:g' \
		-e 's:-lncursesw:$(shell $(PKG_CONFIG) --libs ncursesw):g' \
		-i Makefile || die

	if [[ ${CHOST} == *-darwin* ]]; then
		# CC=gcc
		# CXX=g++
		# CFLAGS=-O2 -D_FILE_OFFSET_BITS=64 -g
		# #CXXFLAGS=-O2 -Wall -D_FILE_OFFSET_BITS=64 -D USE_UTF16 -I/sw/include -I/usr/local/include -I/opt/local/include -g
		# CXXFLAGS=-O2 -Wall -D_FILE_OFFSET_BITS=64 -I/sw/include -I /usr/local/include -I/opt/local/include -g
		sed \
			-e 's: -L/sw/lib : :' \
			-e "s:^CC=.*$:CC=$(tc-getCC):" \
			-e "s:^CXX=.*$:CC=$(tc-getCXX):" \
			-e "s:^CFLAGS=.*$:CFLAGS=${CFLAGS} -D_FILE_OFFSET_BITS=64:" \
			-e "s:^CXXFLAGS=.*$:CXXFLAGS=${CFLAGS} -D_FILE_OFFSET_BITS=64:" \
			-i Makefile.mac || die
		mv Makefile.mac Makefile || die
	fi

	use static && append-ldflags -static
}

src_install() {
	dosbin gdisk sgdisk $(usex ncurses cgdisk '') fixparts
	doman *.8
	dodoc NEWS README
}
