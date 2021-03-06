# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=5
ETYPE="sources"
K_NOUSENAME=1
inherit autotools eutils kernel-2 ltprune

DESCRIPTION="Userspace utilities for a general USB device sharing system over IP networks"
HOMEPAGE="https://www.kernel.org/"
SRC_URI="${KERNEL_URI}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="doc static-libs tcpd"
RESTRICT=""

RDEPEND=">=dev-libs/glib-2.6
	sys-apps/hwids
	>=sys-kernel/linux-headers-3.17
	virtual/libudev
	tcpd? ( sys-apps/tcp-wrappers )"
DEPEND="${RDEPEND}
	virtual/pkgconfig"

#DOCS="AUTHORS README ../../../drivers/usb/usbip/usbip_protocol.txt"
DOCS="README"

S=${WORKDIR}/linux-${PV}/tools/usb/${PN}

src_prepare() {
	# AC_SUBST([EXTRA_CFLAGS], ["-Wall -Werror -Wextra -std=gnu99"])
	# Bug #545398
	sed -i \
		-e '/EXTRA_CFLAGS/s|\["-Wall -Werror -Wextra -std=gnu99"\]|["-std=gnu99"]|' \
		configure.ac || die "sed failed"

	eautoreconf
}

src_configure() {
	econf \
		$(use_enable static-libs static) \
		$(use tcpd || echo --without-tcp-wrappers) \
		--with-usbids-dir=/usr/share/misc
}

src_install() {
	default

	use doc && dodoc  "${WORKDIR}"/linux-"${PV}"/drivers/usb/usbip/usbip_protocol.txt

	prune_libtool_files
}

pkg_postinst() {
	elog "In order to use USB/IP you must enable USBIP_VHCI_HCD in the client"
	elog "machine's kernel config, and USBIP_HOST on the server where the device(s)"
	elog "to share are attached."
}
