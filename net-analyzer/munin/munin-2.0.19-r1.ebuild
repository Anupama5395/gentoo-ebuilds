# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id: 3a31df0ee80ab68b08070a1f37809465cd91a3bb $

EAPI=5

PATCHSET=1

inherit eutils java-pkg-opt-2 systemd user webapp

MY_P=${P/_/-}

DESCRIPTION="Munin Server Monitoring Tool"
HOMEPAGE="http://munin-monitoring.org/"
SRC_URI="mirror://sourceforge/munin/${MY_P}.tar.gz
	https://dev.gentoo.org/~flameeyes/${PN}/${P}-gentoo-${PATCHSET}.tar.xz"

LICENSE="GPL-2"
#SLOT="0"
KEYWORDS="amd64 ~arm ~mips ppc x86"
IUSE="apache asterisk cgi dhcpd doc http ipmi ipv6 irc java memcached minimal mysql postgres ssl syslog systemd test"
REQUIRED_USE="cgi? ( !minimal ) apache? ( cgi )"

# Upstream's listing of required modules is NOT correct!
# Some of the postgres plugins use DBD::Pg, while others call psql directly.
# Some of the mysql plugins use DBD::mysql, while others call mysqladmin directly.
# We replace the original ipmi plugins with the freeipmi_ plugin which at least works.
DEPEND_COM="dev-lang/perl:=[berkdb]
			kernel_linux? ( sys-process/procps )
			doc? ( dev-python/sphinx )
			asterisk? ( dev-perl/Net-Telnet )
			irc? ( dev-perl/Net-IRC )
			mysql? ( virtual/mysql
					 dev-perl/Cache-Cache
					 dev-perl/DBD-mysql )
			ssl? ( dev-perl/Net-SSLeay )
			postgres? ( dev-perl/DBD-Pg dev-db/postgresql )
			memcached? ( dev-perl/Cache-Memcached )
			cgi? ( dev-perl/FCGI )
			apache? ( www-servers/apache[apache2_modules_cgi,apache2_modules_cgid,apache2_modules_rewrite] )
			syslog? ( virtual/perl-Sys-Syslog )
			http? ( dev-perl/libwww-perl )
			dhcpd? (
				>=net-misc/dhcp-3[server]
				dev-perl/Net-IP
				dev-perl/HTTP-Date
			)
			dev-perl/DBI
			dev-perl/Date-Manip
			dev-perl/File-Copy-Recursive
			dev-perl/List-MoreUtils
			dev-perl/Log-Log4perl
			dev-perl/Net-CIDR
			dev-perl/Net-DNS
			dev-perl/Net-Netmask
			dev-perl/Net-SNMP
			dev-perl/Net-Server[ipv6(-)?]
			virtual/perl-Digest-MD5
			virtual/perl-Getopt-Long
			virtual/perl-MIME-Base64
			virtual/perl-Storable
			virtual/perl-Text-Balanced
			virtual/perl-Time-HiRes
			!minimal? (
				dev-perl/HTML-Template
				dev-perl/IO-Socket-INET6
				dev-perl/URI
				>=net-analyzer/rrdtool-1.3[graph,perl]
				virtual/ssh
			)"

# Keep this seperate, as previous versions have had other deps here
DEPEND="${DEPEND_COM}
	dev-perl/Module-Build
	cgi? ( || ( virtual/httpd-cgi virtual/httpd-fastcgi ) )
	java? ( >=virtual/jdk-1.5 )
	test? (
		dev-perl/Test-Deep
		dev-perl/Test-LongString
		dev-perl/Test-Differences
		dev-perl/Test-MockModule
		dev-perl/Test-MockObject
		dev-perl/File-Slurp
		dev-perl/IO-stringy
		dev-perl/IO-Socket-INET6
	)"
RDEPEND="${DEPEND_COM}
		virtual/awk
		ipmi? ( >=sys-libs/freeipmi-1.1.6-r1 )
		java? (
			>=virtual/jre-1.5
			|| ( net-analyzer/netcat6 net-analyzer/netcat )
		)
		!minimal? (
			virtual/cron
			media-fonts/dejavu
		)
		!<sys-apps/openrc-0.11.8"

S="${WORKDIR}/${MY_P}"

pkg_setup() {
	webapp_pkg_setup

	enewgroup munin
	enewuser munin 177 -1 /var/lib/munin munin
	enewuser munin-async -1 /bin/sh /var/spool/munin-async
	esethome munin-async /var/spool/munin-async

	java-pkg-opt-2_pkg_setup
}

src_prepare() {
	epatch "${WORKDIR}"/patches/*.patch
	epatch "${FILESDIR}"/${PN}-static-dir-2.0.19.patch
	epatch "${FILESDIR}"/${PN}-reserved-words-2.0.19.patch

	java-pkg-opt-2_src_prepare
}

src_configure() {
	local cgidir='$(DESTDIR)/usr/libexec/munin/cgi'
	use cgi || cgidir="${T}/useless/cgi-bin"

	local cgiuser=$(usex apache apache munin)

	cat - >> "${S}"/Makefile.config <<EOF
PREFIX=\$(DESTDIR)/usr
CONFDIR=\$(DESTDIR)/etc/munin
DOCDIR=${T}/useless/doc
MANDIR=\$(PREFIX)/share/man
LIBDIR=\$(PREFIX)/libexec/munin
HTMLDIR=\$(DESTDIR)/var/www/localhost/htdocs/munin
CGIDIR=${cgidir}
CGITMPDIR=\$(DESTDIR)/var/cache/munin-cgi
CGIUSER=${cgiuser}
DBDIR=\$(DESTDIR)/var/lib/munin
DBDIRNODE=\$(DESTDIR)/var/lib/munin-node
SPOOLDIR=\$(DESTDIR)/var/spool/munin-async
LOGDIR=\$(DESTDIR)/var/log/munin
PERLSITELIB=$(perl -V:vendorlib | cut -d"'" -f2)
JCVALID=$(usex java yes no)
STATEDIR=\$(DESTDIR)/var/run/munin
EOF
}

# parallel make and install need to be fixed before, and I haven't
# gotten around to do so yet.
src_compile() {
	emake -j1
	if use doc; then
		emake -C doc html
	fi
}

src_test() {
	if [[ ${EUID} == 0 ]]; then
		eerror "You cannot run tests as root."
		eerror "Please enable FEATURES=userpriv before proceeding."
		return 1
	fi

	local testtargets="test-common test-node test-plugins"
	use minimal || testtargets+=" test-master"

	LC_ALL=C emake -j1 ${testtargets}
}

src_install() {
	local dirs="
		/var/log/munin
		/var/lib/munin/plugin-state
		/etc/munin/plugin-conf.d"
	use minimal || dirs+=" /etc/munin/munin-conf.d/"

	webapp_src_preinst

	keepdir ${dirs}
	fowners munin:munin ${dirs}

	# parallel install doesn't work and it's also pointless to have this
	# run in parallel for now (because it uses internal loops).
	emake -j1 DESTDIR="${ED}" $(usex minimal install-minimal install)

	# we remove /run from the install, as it's not the package's to deal
	# with.
	rm -rf "${ED}"/run

	# remove the plugins for non-Gentoo package managers; use -f so that
	# it doesn't fail when installing on non-Linux platforms.
	rm -f "${ED}"/usr/libexec/munin/plugins/{apt{,_all},yum} \
		|| die "Failed to remove non-Gentoo package-manager plugins"

	if ! use minimal; then
		dodir "${MY_HTDOCSDIR}"/{config,static,templates}
		dodir "${MY_HTDOCSDIR}"/templates/partial
		find "${ED}"/etc/munin/static/ -type f -exec mv -v {} "${ED}"/"${MY_HTDOCSDIR}"/static/ \;
		find "${ED}"/etc/munin/templates/ -type f -not -name munin-\* -exec mv -v {} "${ED}"/"${MY_HTDOCSDIR}"/templates/partial/ \;
		find "${ED}"/etc/munin/templates/ -type f -name munin-\* -exec mv -v {} "${ED}"/"${MY_HTDOCSDIR}"/templates/ \;
		dodir "${MY_HTDOCSDIR}"/config/plugins
		rmdir "${ED}"/etc/munin/templates/partial
		rmdir "${ED}"/etc/munin/{plugins,static,templates} || die "Cannot remove directories from '${ED}/etc/'"

		# remove .htaccess files
		find "${ED}" -type f -name .htaccess -delete || die "Failed to remove .htaccess files from destination '${ED}'"
		rmdir "${ED}"/var/www/localhost/htdocs/munin || die "Cannot remove '${ED}/var/www/localhost/htdocs/munin' directory"

		if use cgi; then
			dodir "${MY_CGIBINDIR}"/munin
			mv "${ED}"/usr/libexec/munin/cgi/munin-cgi-graph "${ED}"/"${MY_CGIBINDIR}"/munin/
			mv "${ED}"/usr/libexec/munin/cgi/munin-cgi-html "${ED}"/"${MY_CGIBINDIR}"/munin/
			rmdir "${ED}"/usr/libexec/munin/cgi || die "Cannot remove '${ED}/usr/libexec/munin/cgi' directory"

			keepdir /var/cache/munin-cgi
			touch "${ED}"/var/log/munin/munin-cgi-{graph,html}.log

			webapp_serverowned /var/cache/munin-cgi
			webapp_serverowned /var/log/munin/munin-cgi-{graph,html}.log
		fi
	fi

	# The webapp application folder needs to be writable by the 'munin' user,
	# as *all* HTML content is auto-generated by cron.  Unfortunately,
	# webapp-config does not seem to propagate permissions on this top-level
	# directory, so the following statement appears in the hope that this will
	# change at some point in the future...
	webapp_serverowned "${MY_HTDOCSDIR}"

	# ... so we'll ensure that the correct permissions are set in a hook
	# instead!
	webapp_hook_script "${FILESDIR}"/webapp-hook-1.0.0

	webapp_src_install

	dodoc "${FILESDIR}"/lighttpd.sample

	insinto /etc/munin/plugin-conf.d/
	newins "${FILESDIR}"/${PN}-1.3.2-plugins.conf munin-node

	newinitd "${FILESDIR}"/munin-node_init.d_2.0.19 munin-node
	newconfd "${FILESDIR}"/munin-node_conf.d_1.4.6-r2 munin-node

	newinitd "${FILESDIR}"/munin-asyncd.init.2 munin-asyncd

	if use systemd; then
		dodir /usr/lib/tmpfiles.d
		cat - > "${ED}"/usr/lib/tmpfiles.d/${CATEGORY}:${PN}:${SLOT}.conf <<EOF
d /var/run/munin 0700 munin munin - -
EOF

		systemd_dounit "${FILESDIR}"/munin-async.service
		systemd_dounit "${FILESDIR}"/munin-graph.{service,socket}
		systemd_dounit "${FILESDIR}"/munin-html.{service,socket}
		systemd_dounit "${FILESDIR}"/munin-node.service
	fi

	cat - >> "${T}"/munin.env <<EOF
CONFIG_PROTECT=/var/spool/munin-async/.ssh
EOF
	newenvd "${T}"/munin.env 50munin

	dodoc README ChangeLog INSTALL
	if use doc; then
		cd "${S}"/doc/_build/html
		dohtml -r *
		cd "${S}"
	fi

	dodir /etc/logrotate.d/
	sed -e "s:@CGIUSER@:$(usex apache apache munin):g" \
		"${FILESDIR}"/logrotate.d-munin.2 > "${ED}"/etc/logrotate.d/munin

	dosym ipmi_ /usr/libexec/munin/plugins/ipmi_sensor_

	if use syslog; then
		sed -i -e '/log_file/s| .*| Sys::Syslog|' \
			"${ED}"/etc/munin/munin-node.conf \
				|| die "Adding syslog support to '/etc/munin/munin-node.conf' failed"
	fi

	# Use a simpler pid file to avoid trouble with /run in tmpfs. The
	# munin-node service is run as user root, and only later drops
	# privileges.
	sed -i -e 's:/run/munin/munin-node.pid:/run/munin-node.pid:' \
		"${ED}"/etc/munin/munin-node.conf \
			|| die "Flattening PID path in '/etc/munin/munin-node.conf' failed"

	keepdir /var/spool/munin-async/.ssh
	touch "${ED}"/var/spool/munin-async/.ssh/authorized_keys
	fowners munin-async:munin /var/spool/munin-async{,/.ssh/{,authorized_keys}}
	fperms 0750 /var/spool/munin-async{,/.ssh}
	fperms 0600 /var/spool/munin-async/.ssh/authorized_keys

	if use minimal; then
		# This requires the presence of munin-update, which is part of
		# the non-minimal install...
		rm "${ED}"/usr/libexec/munin/plugins/munin_stats
	else
		# remove font files so that we don't have to keep them around
		rm "${ED}"/usr/libexec/${PN}/*.ttf \
			|| die "Removing font files failed"

		if use cgi; then
			sed -i -e '/#graph_strategy cgi/s:^#::' \
				"${ED}"/etc/munin/munin.conf \
					|| die "Updating graph_strategy to 'cgi' in '/etc/munin/munin-node.conf' failed"

			if use apache; then
				insinto /etc/apache2/vhosts.d
				newins "${FILESDIR}"/munin.apache.include munin.include
				newins "${FILESDIR}"/munin.apache.include-2.4 munin-2.4.include
			fi
		else
			sed -i -e '/#graph_strategy cgi/s:#graph_strategy cgi:graph_strategy cron:' \
				"${ED}"/etc/munin/munin.conf \
					|| die "Updating graph_strategy to 'cron' in '/etc/munin/munin-node.conf' failed"
		fi

		keepdir /var/lib/munin/.ssh
		cat - >> "${ED}"/var/lib/munin/.ssh/config <<EOF
IdentityFile /var/lib/munin/.ssh/id_ecdsa
IdentityFile /var/lib/munin/.ssh/id_rsa
EOF

		fowners munin:munin /var/lib/munin/.ssh/{,config}
		fperms go-rwx /var/lib/munin/.ssh/{,config}

		insinto /usr/share/${PN}
		doins "${FILESDIR}"/"${PN}-crontab"
		doins "${FILESDIR}"/"${PN}-fcrontab"
	fi
}

pkg_config() {
	if use minimal; then
		einfo "Nothing to do."
		return 0
	fi

	einfo "Press enter to install the default crontab for the munin master"
	einfo "installation from /usr/share/${PN}/{f,}crontab"
	einfo "If you have a large site, you may wish to customize it."
	read

	ebegin "Setting up cron ..."
	if has_version sys-process/fcron; then
		fcrontab - -u munin < /usr/share/${PN}/fcrontab
	else
		# dcron is very fussy about syntax
		# the following is the only form that works in BOTH dcron and vixie-cron
		crontab - -u munin < /usr/share/${PN}/crontab
	fi
	eend $?

	einfo "Press enter to set up the SSH keys used for SSH transport"
	read

	# generate one rsa (for legacy) and one ecdsa (for new systems)
	ssh-keygen -t rsa -f /var/lib/munin/.ssh/id_rsa -N '' -C "created by portage for ${CATEGORY}/${PN}" || die "RSA key generation failed"
	ssh-keygen -t ecdsa -f /var/lib/munin/.ssh/id_ecdsa -N '' -C "created by portage for ${CATEGORY}/${PN}" || die "ECDSA key generation failed"
	chown -R munin:munin /var/lib/munin/.ssh || die
	chmod 0600 /var/lib/munin/.ssh/id_{rsa,ecdsa} || die

	einfo "Your public keys are available in "
	einfo "  /var/lib/munin/.ssh/id_rsa.pub"
	einfo "  /var/lib/munin/.ssh/id_ecdsa.pub"
	einfo "and follows for convenience"
	echo
	cat /var/lib/munin/.ssh/id_*.pub
}

pkg_postinst() {
	elog "Please follow the munin documentation to set up the plugins you"
	elog "need, afterwards start munin-node."
	elog ""
	elog "To make use of munin-async, make sure to set up the corresponding"
	elog "SSH key in /var/lib/munin-async/.ssh/authorized_keys"
	elog ""
	if ! use minimal; then
		elog "Please run"
		elog "  emerge --config net-analyzer/munin"
		elog "to automatically configure munin's cronjobs as well as generate"
		elog "passwordless SSH keys to be used with munin-async."
	fi
	elog ""
	elog "Further information about setting up Munin in Gentoo can be found"
	elog "in the Gentoo Wiki: https://wiki.gentoo.org/wiki/Munin"

	if use cgi; then
		elog ""
		if use apache; then
			elog "To use Munin with CGI you should include /etc/apache2/vhosts.d/munin.include"
			elog "or /etc/apache2/vhosts.d/munin-2.4.include (for Apache 2.4) from the virtual"
			elog "host you want it to be served."
			elog "If you want to enable CGI-based HTML as well, you have to add to"
			elog "/etc/conf.d/apache2 the option -D MUNIN_HTML_CGI."
		else
			elog "An example lighttpd CGI configuration excerpt has been deployed to"
			elog "/usr/share/doc/${PF}/"
		fi
	fi

	# we create this here as we don't want Portage to check /run
	# symlinks but we still need this to be present before the reboot.
	if ! use minimal; then
		if [[ -d "${ROOT}"/run ]]; then
			if ! [[ -d "${ROOT}"/run/munin ]]; then
				mkdir "${ROOT}"/run/munin
				chown munin:munin "${ROOT}"/run/munin
				chmod 0700 "${ROOT}"/run/munin
			fi
		elif [[ -d "${ROOT}"/var/run ]]; then
			if ! [[ -d "${ROOT}"/var/run/munin ]]; then
				mkdir "${ROOT}"/var/run/munin
				chown munin:munin "${ROOT}"/var/run/munin
				chmod 0700 "${ROOT}"/var/run/munin
			fi
		fi
	fi
}

# vi: set diffopt=iwhite,filler:
