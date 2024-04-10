#!/bin/bash

GIT=/usr/bin/git
APT_GET=/usr/bin/apt-get
RPL=/usr/bin/rpl
CP=/bin/cp
RM=/bin/rm
USERADD=/usr/sbin/useradd
USERDEL=/usr/sbin/userdel
CHOWN=/bin/chown
CHMOD=/bin/chmod
MKDIR=/bin/mkdir
LN=/bin/ln
CAT=/bin/cat
ECHO=/bin/echo
MKTEMP=/bin/mktemp
PWGEN=/usr/bin/pwgen
DU=/usr/bin/du
DPKG=/usr/bin/dpkg
GREP=/bin/grep
LS=/bin/ls
BASENAME=/usr/bin/basename
GZIP=/bin/gzip
MAWK=/usr/bin/mawk
HEAD=/usr/bin/head
SED=/usr/bin/sed
SORT=/usr/bin/sort
BASH=/bin/bash
PWD=/usr/bin/pwd
FAKEROOT=/usr/bin/fakeroot
SU=/usr/bin/su
SUDO=/usr/bin/sudo
LSB_RELEASE=/usr/bin/lsb_release

#######################################################################################################################################

download_build_deps()
{
    TO_INSTALL=""
    RET=0
    for build_pkg in `${CAT} ${BUILD_DEPENDS_FILE}`
    do
        if ! ${DPKG} -s ${build_pkg} 1>/dev/null 2>/dev/null
        then
            TO_INSTALL="${TO_INSTALL} ${build_pkg}"
        fi
    done

    if [ -n "${TO_INSTALL}" ]
    then
        if [ "${EUID}" = "0" ]
        then
            ${APT_GET} -f -y install ${TO_INSTALL}
            RET=$?
        else
            if [ -f ${SUDO} ]
            then
                ${SUDO} ${APT_GET} -f -y install ${TO_INSTALL}
                RET=$?
            elif [ -f ${SU} ]
            then
                ${SU} -c "${APT_GET} -f -y install ${TO_INSTALL}"
                RET=$?
            else
                ${ECHO} "Please install these packages: ${TO_INSTALL}, with the following command"
                ${ECHO} "${APT_GET} -f -y install ${TO_INSTALL}"
                RET=1
            fi
        fi
    fi

    if ! [ "${RET}" = "0" ]
    then
        exit ${RET}
    fi

    return ${RET}
}

get_last_release()
{
    L_GIT_SERVER=$1
    L_VERSION=`${GIT} ls-remote --tags ${L_GIT_SERVER} | ${MAWK} -F "/" '{print $3;}' | ${SORT} -V -r | ${HEAD} -n 1`
    L_RESULT=$?

    if [ "${L_RESULT}" = "0" ]
    then
        if [ -n "${L_VERSION}" ]
        then
            ${ECHO} "${L_VERSION}"
        else
            L_RESULT=1
        fi
    fi

    return ${L_RESULT}
}

#######################################################################################################################################
## Edit this values
SCRIPT_VERSION=0.1.0
GIT_SERVER=https://github.com/rmalvarezkai/ehdtd_daemon
SRC_DIR=ehdtd-daemon-src

SOFT_NAME=ehdtd-daemon
SOFT_DIR=ehdtd-daemon
SOFT_ARCH=amd64
DEST_DIR=dist

SOFT_NAME_RPL=__SOFT_NAME__
VIRT_ENV_NAME="${SOFT_NAME}-virtenv"
USR_DIR=/usr/lib/${SOFT_NAME}
LOG_DIR=/var/log/${SOFT_NAME}
DOC_DIR=/usr/share/doc/${SOFT_NAME}
SHARE_DIR=/usr/share/${SOFT_NAME}
SKEL_DIR=skel
BUILD_DEPENDS_FILE=${SKEL_DIR}/build-depends.txt
#######################################################################################################################################

DIST_ID=`${LSB_RELEASE} -s -i 2>/dev/null`
DIST_CODENAME=`${LSB_RELEASE} -s -c 2>/dev/null` # Only tested for bullseye and bookworm

if [ -n "$1" ]
then
    DIST_CODENAME=$1
fi

FILE_VERSION=${DEST_DIR}/VERSION_${DIST_CODENAME}
SERIAL_FILE="${DEST_DIR}/${DIST_CODENAME}-serial.txt"

${ECHO} "Making ${SOFT_NAME} debian package"

CURRENT_DIR=`${PWD}`

SOFT_VERSION_PREV=NONE
SOFT_VERSION=NONE

download_build_deps

BRANCH=`get_last_release ${GIT_SERVER}`

if ! [ "$?" = "0" ]
then
    ${ECHO} "Error getting last release version"
    exit 1
fi

if ! [ -d "${DEST_DIR}" ]
then
    ${MKDIR} -p ${DEST_DIR}
fi

SOFT_VERSION=`${ECHO} ${BRANCH} | ${SED} 's/[a-zA-Z]//g'`

if [ -f ${FILE_VERSION} ]
then
    SOFT_VERSION_PREV=`${CAT} ${FILE_VERSION}`
fi

if [ "${SOFT_VERSION}" = "${SOFT_VERSION_PREV}" ]
then
    ${ECHO} "Nothing to do"
else
    ${RM} -f ${SOFT_NAME}_*~${DIST_ID}~${DIST_CODENAME}_${SOFT_ARCH}.deb

    ${GIT} clone -q -b ${BRANCH} ${GIT_SERVER} ${SRC_DIR} 1>/dev/null 2>/dev/null
    if ! [ "$?" = "0" ]
    then
        ${ECHO} "git clone error"
        exit 1
    fi

    ${ECHO} "${SOFT_VERSION}" > ${FILE_VERSION}
    VIRTENV_DIR=${SOFT_DIR}${USR_DIR}/${VIRT_ENV_NAME}

    if [ -d ${SOFT_DIR}${DOC_DIR} ]
    then
        ${RM} -f -r ${SOFT_DIR}${DOC_DIR}
    fi

    ${MKDIR} -p ${SOFT_DIR}${DOC_DIR}
    ${MKDIR} -p ${SOFT_DIR}${SHARE_DIR}/config-skels

    if [ -d ${SOFT_DIR}/etc/${SOFT_NAME} ]
    then
        ${RM} -f -r ${SOFT_DIR}/etc/${SOFT_NAME}
    fi

    if [ -d ${SOFT_DIR}/etc/logrotate.d ]
    then
        ${RM} -f -r ${SOFT_DIR}/etc/logrotate.d
    fi

    ${MKDIR} -p ${SOFT_DIR}/etc/${SOFT_NAME}
    # ${ECHO} "" > ${SOFT_DIR}/etc/${SOFT_NAME}/${SOFT_NAME}-config.yaml
    ${MKDIR} -p ${SOFT_DIR}/etc/logrotate.d

    cd ${SRC_DIR}

    ${GIT} log | ${GZIP} -c > ../${SOFT_DIR}${DOC_DIR}/changelog.gz
    ${CAT} README.md > ../${SOFT_DIR}${DOC_DIR}/README.md
    ${CAT} LICENSE > ../${SOFT_DIR}${DOC_DIR}/LICENSE
    ${CAT} pyproject.toml > ../${SOFT_DIR}${DOC_DIR}/pyproject.toml
    ${CAT} etc/${SOFT_DIR}/${SOFT_NAME}-config-sample.yaml > ../${SOFT_DIR}${SHARE_DIR}/config-skels/${SOFT_NAME}-config.yaml

    cd ..

    ${CAT} ${SKEL_DIR}/conf/${SOFT_NAME}.default > ${SOFT_DIR}${SHARE_DIR}/config-skels/${SOFT_NAME}.default
    ${CAT} ${SKEL_DIR}/conf/${SOFT_NAME}.logrotate > ${SOFT_DIR}${SHARE_DIR}/config-skels/${SOFT_NAME}.logrotate

    if [ -d ${SRC_DIR} ]
    then
        ${RM} -f -r ${SRC_DIR}
    fi

    if [ -d ${VIRTENV_DIR} ]
    then
        ${RM} -f -r ${VIRTENV_DIR}
    fi

    ${CHMOD} 0544 ${SOFT_DIR}/usr/sbin/${SOFT_NAME}
    ${CHMOD} 0544 ${SOFT_DIR}/usr/sbin/${SOFT_NAME}-make-venv

    cd ${CURRENT_DIR}

    BUILD_NUM=0

    if [ -f "${SERIAL_FILE}" ]
    then
	    BUILD_NUM=`${CAT} ${SERIAL_FILE}`
    fi

    BUILD_NUM=$[ ${BUILD_NUM} + 1 ]
    ${ECHO} ${BUILD_NUM} > ${SERIAL_FILE}

    SOFT_VERSION=${SOFT_VERSION}-b${BUILD_NUM}~${DIST_ID}~${DIST_CODENAME}

    FILE_IN=${SKEL_DIR}/DEBIAN/preinst
    FILE_OUT=${SOFT_DIR}/DEBIAN/preinst
    ${CAT} ${FILE_IN} > ${FILE_OUT}
    ${RPL} ${SOFT_NAME_RPL} ${SOFT_NAME} ${FILE_OUT} 1>/dev/null
    ${CHMOD} 0775 ${FILE_OUT}

    FILE_IN=${SKEL_DIR}/DEBIAN/postinst
    FILE_OUT=${SOFT_DIR}/DEBIAN/postinst
    ${CAT} ${FILE_IN} > ${FILE_OUT}
    ${RPL} ${SOFT_NAME_RPL} ${SOFT_NAME} ${FILE_OUT} 1>/dev/null
    ${CHMOD} 0775 ${FILE_OUT}

    FILE_IN=${SKEL_DIR}/DEBIAN/prerm
    FILE_OUT=${SOFT_DIR}/DEBIAN/prerm
    ${CAT} ${FILE_IN} > ${FILE_OUT}
    ${RPL} ${SOFT_NAME_RPL} ${SOFT_NAME} ${FILE_OUT} 1>/dev/null
    ${CHMOD} 0775 ${FILE_OUT}

    FILE_IN=${SKEL_DIR}/DEBIAN/postrm
    FILE_OUT=${SOFT_DIR}/DEBIAN/postrm
    ${CAT} ${FILE_IN} > ${FILE_OUT}
    ${RPL} ${SOFT_NAME_RPL} ${SOFT_NAME} ${FILE_OUT} 1>/dev/null
    ${CHMOD} 0775 ${FILE_OUT}

    FILE_IN=${SKEL_DIR}/DEBIAN/config
    FILE_OUT=${SOFT_DIR}/DEBIAN/config
    ${CAT} ${FILE_IN} > ${FILE_OUT}
    ${RPL} ${SOFT_NAME_RPL} ${SOFT_NAME} ${FILE_OUT} 1>/dev/null
    ${CHMOD} 0775 ${FILE_OUT}

    SIZE=`${DU} -k -s ${SOFT_DIR}`
    DEB_NAME_OUT=${SOFT_NAME}_${SOFT_VERSION}_${SOFT_ARCH}.deb

    FILE_IN=${SKEL_DIR}/DEBIAN/control
    FILE_OUT=${SOFT_DIR}/DEBIAN/control
    ${CAT} ${FILE_IN} > ${FILE_OUT}
    ${RPL} __VERSION__ ${SOFT_VERSION} ${FILE_OUT} 1>/dev/null
    ${RPL} __SIZE__ ${SIZE} ${FILE_OUT} 1>/dev/null
    ${RPL} ${SOFT_NAME_RPL} ${SOFT_NAME} ${FILE_OUT} 1>/dev/null
    ${CHMOD} 0644 ${FILE_OUT}

    ${ECHO} "Creating debian package in ${DEB_NAME_OUT}"
    ${FAKEROOT} ${DPKG} -b ${SOFT_DIR} ${DEB_NAME_OUT}

    if [ -d ${VIRTENV_DIR} ]
    then
        ${RM} -f -r ${VIRTENV_DIR}
    fi

    ${ECHO} "Ready."
fi
