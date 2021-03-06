# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id: 71328fd758822d3c597082593d66284b751591de $

EAPI=5
PYTHON_COMPAT=( python2_7 )

inherit autotools git-r3 python-single-r1

DESCRIPTION="USB enumeration utilities"
HOMEPAGE="http://linux-usb.sourceforge.net/"
EGIT_REPO_URI="https://github.com/srcshelton/${PN}.git"
EGIT_COMMIT="tags/v${PV}-nohwdb"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm ~arm64 hppa ia64 ~m68k ~mips ppc ppc64 ~s390 ~sh sparc x86 ~amd64-linux ~arm-linux ~x86-linux"
IUSE="python zlib"
REQUIRED_USE="python? ( ${PYTHON_REQUIRED_USE} )"

RDEPEND="virtual/libusb:1=
	zlib? ( sys-libs/zlib:= )"
DEPEND="${RDEPEND}
	app-arch/xz-utils
	virtual/pkgconfig"
RDEPEND="${RDEPEND}
	sys-apps/hwids
	python? ( ${PYTHON_DEPS} )"

pkg_setup() {
	use python && python-single-r1_pkg_setup
}

src_prepare() {
	epatch "${FILESDIR}"/${P}-stdint.patch
	sed -i -e '/^usbids/s:/usr/share:/usr/share/misc:' lsusb.py || die
	use python && python_fix_shebang lsusb.py

	eautoreconf
}

src_configure() {
	econf \
		--datarootdir="${EPREFIX}/usr/share" \
		--datadir="${EPREFIX}/usr/share/misc" \
		--disable-usbids \
		$(use_enable zlib)
}

src_install() {
	for d in README* ChangeLog AUTHORS NEWS TODO CHANGES \
			THANKS BUGS FAQ CREDITS CHANGELOG ; do
		[[ -s "${d}" ]] && rm "${d}"
	done

	default

	use python || rm -f "${ED}"/usr/bin/lsusb.py
}
