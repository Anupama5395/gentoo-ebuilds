# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-firewall/iptables/iptables-1.4.21-r1.ebuild,v 1.9 2014/08/02 18:06:48 ago Exp $

EAPI="5"

# Force users doing their own patches to install their own tools
AUTOTOOLS_AUTO_DEPEND=no

inherit autotools eutils git-r3 multilib systemd toolchain-funcs

# iptables-nftables was merged into iptables...
#REPO="${PN}"
# ... and no longer has its own branch...
#BRANCH="nft-compat"
REPO="iptables"
BRANCH="master"
#COMMIT="03091e55a0d949e35a723dadbd6fd0f78ddf3a8c" # nftables merge
COMMIT="ab8c7d82f7848d318e472a3d809ec7dab969bd04" # Alignment problem between 64bit kernel 32bit userspace

DESCRIPTION="Linux kernel (3.13+) firewall, NAT and packet mangling tools, with nftables compatibility"
HOMEPAGE="http://www.netfilter.org/projects/nftables/"
EGIT_REPO_URI="git://git.netfilter.org/${REPO}.git"
#EGIT_BRANCH="${BRANCH}"
EGIT_COMMIT="${COMMIT}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm ~arm64 hppa ia64 ~m68k ~mips ppc ppc64 ~s390 ~sh sparc x86"
IUSE="ipv6 netlink static-libs systemd"

RDEPEND="
	netlink? ( net-libs/libnfnetlink )
"
DEPEND="${RDEPEND}
	virtual/os-headers
	virtual/pkgconfig
	net-libs/libnetfilter_conntrack
	net-libs/libnftnl
	net-libs/libpcap
	!net-firewall/iptables
"

src_prepare() {
	# use the saner headers from the kernel
	rm -f include/linux/{kernel,types}.h

	eautoreconf
}

src_configure() {
	# Some libs use $(AR) rather than libtool to build #444282
	tc-export AR

	sed -i \
		-e "/nfnetlink=[01]/s:=[01]:=$(usex netlink 1 0):" \
		configure || die

	econf \
		--sbindir="${EPREFIX}/sbin" \
		--libexecdir="${EPREFIX}/$(get_libdir)" \
		--enable-devel \
		--enable-shared \
		--enable-libipq \
		--enable-bpf-compiler \
		--enable-nfsynproxy \
		$(use_enable static-libs static) \
		$(use_enable ipv6)
}

src_compile() {
	emake V=1
}

src_install() {
	default
	dodoc INCOMPATIBILITIES iptables/iptables.xslt

	# all the iptables binaries are in /sbin, so might as well
	# put these small files in with them
	into /
	dosbin iptables/iptables-apply
	dosym iptables-apply /sbin/ip6tables-apply
	doman iptables/iptables-apply.8

	insinto /usr/include
	doins include/iptables.h $(use ipv6 && echo include/ip6tables.h)
	insinto /usr/include/iptables
	doins include/iptables/internal.h

	keepdir /var/lib/iptables
	newinitd "${FILESDIR}"/iptables-1.4.13-r1.init iptables
	newconfd "${FILESDIR}"/iptables-1.4.13.confd iptables
	if use ipv6 ; then
		keepdir /var/lib/ip6tables
		newinitd "${FILESDIR}"/iptables-1.4.13-r1.init ip6tables
		newconfd "${FILESDIR}"/ip6tables-1.4.13.confd ip6tables
	fi

	if use systemd; then
		systemd_dounit "${FILESDIR}"/systemd/iptables{,-{re,}store}.service
		if use ipv6 ; then
			systemd_dounit "${FILESDIR}"/systemd/ip6tables{,-{re,}store}.service
		fi
	fi

	# Move important libs to /lib
	gen_usr_ldscript -a ip{4,6}tc iptc xtables

	prune_libtool_files --all
}
