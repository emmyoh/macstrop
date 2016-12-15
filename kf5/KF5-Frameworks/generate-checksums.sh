#!/bin/sh

if [ "${prefix}" = "" ] ;then
    prefix=/opt/local
fi

version=5.29.0
branch=${version%.0}

METAPORT="KF5-Frameworks"
PORTFILE=`port file ${METAPORT}`
FRAMEWORKS="`grep '^[   ]*subport ' ${PORTFILE} | sed -e 's|subport \(.*\) {|\1|g'`"
MASTERSITE="http://download.kde.org/stable/frameworks/${branch}"
MASTERSITEPA="${MASTERSITE}/portingAids"

echo "# checksums for KF5 Frameworks ${version}"
echo "\narray set checksumtable {"

DISTDIR="${prefix}/var/macports/distfiles/${METAPORT}"
mkdir -p "${DISTDIR}"

for F in ${FRAMEWORKS} ;do
    # remove the "kf5-" prefix
    FW="${F#kf5-}"
    DISTFILE="${DISTDIR}/${FW}-${version}.tar.xz"
    if [ ! -e "${DISTFILE}" ] ;then
        wget -P "${DISTDIR}" "${MASTERSITE}/${FW}-${version}.tar.xz"
        if [ $? != 0 ] ;then
            # could have been a portingAid framework; try here:
            wget -P "${DISTDIR}" "${MASTERSITEPA}/${FW}-${version}.tar.xz"
        fi
    fi
    if [ -r "${DISTFILE}" ] ;then
        echo "\t${F} {"
        echo "\t\t`openssl rmd160 ${DISTFILE} | sed -e 's|.*= ||g'`"
        echo "\t\t`openssl sha256 ${DISTFILE} | sed -e 's|.*= ||g'`"
        echo "\t}"
    fi
done

echo "}"
