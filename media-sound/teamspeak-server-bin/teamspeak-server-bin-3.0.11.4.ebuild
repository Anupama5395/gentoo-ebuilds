# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id: 4dd1d7f477ac8ae4dc4f86af76ee6c110947448d $

EAPI=5

inherit eutils multilib systemd user

DESCRIPTION="TeamSpeak Voice Communication Server"
HOMEPAGE="http://www.teamspeak.com/"
SRC_URI="
	amd64? ( http://teamspeak.gameserver.gamed.de/ts3/releases/${PV}/teamspeak3-server_linux-amd64-${PV}.tar.gz )
	x86? ( http://teamspeak.gameserver.gamed.de/ts3/releases/${PV}/teamspeak3-server_linux-x86-${PV}.tar.gz )"

SLOT="0"
LICENSE="teamspeak3 GPL-2"
IUSE="doc pdf systemd tsdns"
KEYWORDS="~amd64 ~x86"

RESTRICT="installsources mirror strip"

S="${WORKDIR}/teamspeak3-server_linux-${ARCH}"

QA_PREBUILT="/opt/teamspeak3"

pkg_setup() {
	enewuser teamspeak
}

src_install() {
	local dir="/opt/teamspeak3"

	# Install TeamSpeak 3 server into $dir
	into "${dir}"

	dodoc -r CHANGELOG doc/*.txt
	use doc && dodoc -r serverquerydocs && \
		docompress -x /usr/share/doc/${PF}/serverquerydocs && \
		dosym ../../usr/share/doc/${PF}/serverquerydocs  ${dir}/serverquerydocs
	use pdf && dodoc doc/*.pdf

	# Install binary, wrapper, shell files and libraries.
	newsbin ts3server_linux_${ARCH} ts3server-bin
	# Standard package installs ts3server to /usr/sbin directory
	dobin "${FILESDIR}/ts3server"

	# 'dolib' may install to libx32 or lib64 - we just want 'lib' alone
	#dolib.so *.so
	insinto "${dir}"/lib
	doins *.so

	if use tsdns; then
		newdoc tsdns/README README.tsdns
		newdoc tsdns/USAGE USAGE.tsdns
		newsbin tsdns/tsdnsserver_linux_${ARCH} tsdnsserver
		# Standard package installs sample files as documentation
		insinto "${dir}"/sbin
		doins tsdns/tsdns_settings.ini.sample
	fi

	# Standard package installs sql directory to /opt/teamspeak3-server directory
	insinto "${dir}"/lib
	doins -r sql

	insinto /etc/teamspeak3
	doins "${FILESDIR}/server.conf"
	doins "${FILESDIR}/ts3db_mariadb.ini"
	newinitd "${FILESDIR}"/${PN}-init-r1 teamspeak3

	if use systemd; then
		systemd_dounit "${FILESDIR}/systemd/teamspeak3.service"
		systemd_dotmpfilesd "${FILESDIR}/systemd/teamspeak3.conf"
	fi

	keepdir /{etc,var/{lib,log,run}}/teamspeak3

	# Fix up permissions
	fowners teamspeak /{etc,var/{lib,log,run}}/teamspeak3
	fperms 700 /{etc,var/{lib,log,run}}/teamspeak3

	fowners teamspeak "${dir}"
	fperms 755 "${dir}"
}
