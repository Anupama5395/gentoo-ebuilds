# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id: da8d62b586c488f4f9b88397017cbf77bb59dba6 $

EAPI=5

inherit eutils linux-info flag-o-matic systemd udev

DESCRIPTION="APC UPS daemon with integrated tcp/ip remote shutdown"
HOMEPAGE="http://www.apcupsd.org/"
SRC_URI="mirror://sourceforge/apcupsd/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 ~arm ~ppc x86 ~x86-fbsd"
IUSE="snmp +usb cgi dumb gnome kernel_linux +modbus +net nls +powerchute +smart systemd udev"

DEPEND="
	||	( >=sys-apps/util-linux-2.23[tty-helpers(-)]
		  <=sys-apps/sysvinit-2.88-r4
		  sys-freebsd/freebsd-ubin
		)
	cgi? ( >=media-libs/gd-1.8.4 )
	nls? ( sys-devel/gettext )
	snmp? ( >=net-analyzer/net-snmp-5.7.2 )
	gnome? ( >=x11-libs/gtk+-2.4.0:2
		dev-libs/glib:2
		>=gnome-base/gconf-2.0 )"
RDEPEND="${DEPEND}
	sys-apps/openrc
	virtual/mailx"

CONFIG_CHECK="~USB_HIDDEV ~HIDRAW"
ERROR_USB_HIDDEV="CONFIG_USB_HIDDEV:	needed to access USB-attached UPSes"
ERROR_HIDRAW="CONFIG_HIDRAW:		needed to access USB-attached UPSes"

pkg_setup() {
	if use kernel_linux && use usb && linux_config_exists; then
		check_extra_config
	fi
}

src_prepare() {
	epatch "${FILESDIR}/${PN}-3.14.9-aliasing.patch"
}

src_configure() {
	local myconf="--disable-net-snmp --disable-test"
	use cgi && myconf="${myconf} --enable-cgi --with-cgi-bin=/usr/libexec/${PN}/cgi-bin"
	if use usb; then
		myconf="${myconf} --with-upstype=usb --with-upscable=usb --with-dev= "
	elif use modbus; then
		myconf="${myconf} --with-upstype=modbus --with-upscable=modbus"
	else
		myconf="${myconf} --with-upstype=apcsmart --with-upscable=smart"
	fi

	if use net; then
		myconf="${myconf} --with-nis-port=3551 $(use_enable powerchute pcnet )"
	else
		sed -i -e '/^NISSRV_ENABLED=yes$/{s:yes:no:}' configure || die "NIS patch failed"
	fi

	# We force the DISTNAME to gentoo so it will use gentoo's layout also
	# when installed on non-linux systems.
	econf \
		--sbindir=/sbin \
		--sysconfdir=/etc/apcupsd \
		--with-pwrfail-dir=/etc/apcupsd \
		--with-lock-dir=/var/lock \
		--with-pid-dir=/var/run/apcupsd \
		--with-log-dir=/var/log \
		--with-distname=gentoo \
		$(use_enable dumb ) \
		$(use_enable gnome gapcmon) \
		$(use_enable modbus ) \
		$(use_enable net ) \
		$(use_enable smart apcsmart ) \
		$(use_enable snmp ) \
		$(use_enable usb ) \
		${myconf} \
		APCUPSD_MAIL=/bin/mail
}

src_compile() {
	# Workaround for bug #280674; upstream should really just provide
	# the text files in the distribution, but I wouldn't count on them
	# doing that anytime soon.
	MANPAGER=$(type -p cat) \
		emake || die "emake failed"
}

src_install() {
	emake DESTDIR="${D}" install || die "installed failed"
	rm -f "${D}"/etc/init.d/halt

	insinto /etc/apcupsd
	newins examples/safe.apccontrol safe.apccontrol
	doins "${FILESDIR}"/apcupsd.conf

	dodoc ChangeLog* ReleaseNotes
	doman doc/*.8 doc/*.5

	dohtml -r doc/manual/*

	rm "${D}"/etc/init.d/apcupsd
	newinitd "${FILESDIR}/${PN}.init.4" "${PN}"
	newinitd "${FILESDIR}/${PN}.powerfail.init" "${PN}".powerfail

	if use systemd; then
		systemd_dounit "${FILESDIR}"/${PN}.service
		systemd_dotmpfilesd "${FILESDIR}"/${PN}-tmpfiles.conf
	else
		# Without this it'll crash at startup. When merging in ROOT= this
		# won't be created by default, so we want to make sure we got it!
		if [[ "${ROOT:-/}" != "/" ]]; then
			keepdir /var/lock
			fowners root:uucp /var/lock
			fperms 0775 /var/lock
		fi
	fi

	# remove hal settings, we don't really want to have it around still.
	rm -r "${D}"/usr/share/hal

	# replace it with our udev rules if we're in Linux
	if use udev && use kernel_linux; then
		udev_newrules "${FILESDIR}"/apcupsd-udev.rules 60-${PN}.rules
	fi

}

pkg_postinst() {
	if use cgi; then
		elog "The cgi-bin directory for ${PN} is /usr/libexec/${PN}/cgi-bin."
		elog "Set up your ScriptAlias or symbolic links accordingly."
	fi

	elog ""
	elog "Since version 3.14.0 you can use multiple apcupsd instances to"
	elog "control more than one UPS in a single box with openRC."
	elog "To do this, create a link between /etc/init.d/apcupsd to a new"
	elog "/etc/init.d/apcupsd.something, and it will then load the"
	elog "configuration file at /etc/apcupsd/something.conf."
	elog ""

	elog 'If you want apcupsd to power off your UPS when it'
	elog 'shuts down your system in a power failure, you must'
	elog 'add apcupsd.powerfail to your shutdown runlevel:'
	elog ''
	elog ' \e[01m rc-update add apcupsd.powerfail shutdown \e[0m'
	elog ''

	if use kernel_linux; then
		elog "Starting from version 3.14.9-r1, ${PN} installs udev rules"
		elog "for persistent device naming. If you have multiple UPS"
		elog "connected to the machine, you can point them to the devices"
		elog "in /dev/apcups/by-id directory."
	fi
}

# vi: set diffopt=iwhite,filler:
