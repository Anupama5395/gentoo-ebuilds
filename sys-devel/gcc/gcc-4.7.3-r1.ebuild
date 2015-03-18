# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-devel/gcc/gcc-4.7.3-r1.ebuild,v 1.21 2015/03/17 06:41:31 vapier Exp $

EAPI="2"

PATCH_VER="1.5"
UCLIBC_VER="1.0"

# Hardened gcc 4 stuff
PIE_VER="0.5.5"
SPECS_VER="0.2.0"
SPECS_GCC_VER="4.4.3"
# arch/libc configurations known to be stable with {PIE,SSP}-by-default
PIE_GLIBC_STABLE="x86 amd64 ppc ppc64 arm ia64"
PIE_UCLIBC_STABLE="x86 arm amd64 ppc ppc64"
SSP_STABLE="amd64 x86 ppc ppc64 arm"
# uclibc need tls and nptl support for SSP support
# uclibc need to be >= 0.9.33
SSP_UCLIBC_STABLE="x86 amd64 ppc ppc64 arm"
#end Hardened stuff

inherit eutils multilib toolchain

KEYWORDS="alpha amd64 arm hppa ia64 m68k ~mips ppc ppc64 s390 sh sparc x86 -amd64-fbsd -x86-fbsd"

RDEPEND=""
DEPEND="${RDEPEND}
	elibc_glibc? ( >=sys-libs/glibc-2.8 )
	>=${CATEGORY}/binutils-2.18"

if [[ ${CATEGORY} != cross-* ]] ; then
	PDEPEND="${PDEPEND} elibc_glibc? ( >=sys-libs/glibc-2.8 )"
fi

src_prepare() {
	if has_version '<sys-libs/glibc-2.12' ; then
		ewarn "Your host glibc is too old; disabling automatic fortify."
		ewarn "Please rebuild gcc after upgrading to >=glibc-2.12 #362315"
		EPATCH_EXCLUDE+=" 10_all_default-fortify-source.patch"
	fi

	# drop the x32 stuff in the next patchset #543578
	if [[ ${CTARGET} != x86_64* ]] || ! has x32 $(get_all_abis TARGET) ; then
		EPATCH_EXCLUDE+=" 90_all_gcc-4.7-x32.patch"
	fi

	toolchain_src_prepare

	use vanilla && return 0

	[[ ${CHOST} == ${CTARGET} ]] && epatch "${FILESDIR}"/gcc-spec-env.patch

	if [[ "${ARCH}" == "amd64" ]]; then
		local LD32="$( get_abi_LIBDIR x86 )"
		local LDx32="$( get_abi_LIBDIR x32 )"
		local LD64="$( get_abi_LIBDIR amd64 )"
		sed -i \
			-e "/^#define GLIBC_DYNAMIC_LINKER32/{s:/lib/:/${LD32:-lib}/:}" \
			-e "/^#define GLIBC_DYNAMIC_LINKERX32/{s:/libx32/:/${LDx32:-libx32}/:}" \
			-e "/^#define GLIBC_DYNAMIC_LINKER64/{s:/lib64/:/${LD64:-lib64}/:}" \
				gcc/config/i386/linux64.h \
			|| die 'LIBDIR replacement failed'

		einfo "Using the following LIBDIR defines:"
		tail -n 3 gcc/config/i386/linux64.h

		sed -i \
			-e "/^MULTILIB_OSDIRNAMES[+ ]= m64=/{s:=../lib64$:=../${LD64:-lib64}:}" \
			-e "/^MULTILIB_OSDIRNAMES[+ ]= m32=/{s:=../lib$:=../${LD32:-lib}:}" \
			-e "/^MULTILIB_OSDIRNAMES[+ ]= mx32=/{s:=../libx32$:=../${LDx32:-libx32}:}" \
				gcc/config/i386/t-linux64 \
			|| die 'DIRNAMES replacement failed'

		einfo "Using the following DIRNAMES defines:"
		tail -n 3 gcc/config/i386/t-linux64

		sed -i \
			-e "/^const char \*__gnat_default_libgcc_subdir = \"libx32\";$/{s:\"libx32\":\"${LDx32:-libx32}\":}" \
				gcc/ada/link.c \
			|| die 'ADA replacement failed'
	fi
}
