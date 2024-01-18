# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4

# Copyright (c) 2015 The MacPorts Project
# Copyright (c) 2017-2019 RJVB
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
# Usage:
# PortGroup     devport 1.0

options mainport_name devport_name devport_content devport_description devport_long_description
default mainport_name               {${name}}
default devport_name                {${mainport_name}-dev}
default devport_content             ""
default devport_description         {"Development headers and libraries for ${mainport_name}"}
default devport_long_description    {"${long_description}\nThis installs the development headers and libraries."}

# namespace eval dev {
    # it shouldn't be necessary to record variants in the archive name
    options dev::archname dev::archdir
    default dev::archname    {${mainport_name}@${version}-dev.tar.bz2}
    # this could go into the software images directory
    default dev::archdir     {${prefix}/var/devcontent}

    set dev::mainport_installed no
# }

proc dev::port_variants {} {
    global PortInfo
    set variants ""
    if {[info exists PortInfo(variants)]} {
        foreach v $PortInfo(variants) {
            if {[variant_isset ${v}]} {
                set variants "${variants}+${v}"
            }
        }
    }
    return ${variants}
}

# create the online devport content archive
proc create_devport_content_archive {} {
    global destroot prefix mainport_name devport_name dev::archdir dev::archname
    set rawargs [option devport_content]
    set args ""
    # convert the arguments to local-relative:
    foreach a ${rawargs} {
        set args "${args} .${a}"
    }
    xinstall -m 755 -d ${destroot}${dev::archdir}
    ui_debug "Creating devport archive ${destroot}${dev::archdir}/${dev::archname} from \"${args}\""
    if {[catch {system -W ${destroot} "bsdtar -cjvf ${destroot}${dev::archdir}/${dev::archname} ${args}"} err]} {
        ui_error "Failure creating ${destroot}${dev::archdir}/${dev::archname} for ${args}: ${err}"
        file delete -force ${destroot}${dev::archdir}/${dev::archname}
    } else {
        ui_debug "Deleting archived \"${args}\""
        foreach a ${args} {
            file delete -force ${destroot}/${a}
        }
        # New: we create the devport's destroot dir here, unpack the archive there
        # and then delete that archive. We still go through the archive because it's
        # a tested and foolproof way to preserve all permissions as well as the layout.
        set cVariants [dev::port_variants]
        ui_debug "making sure the devport workdir exists!"
        if {[catch {system "port -nok fetch ${devport_name} ${cVariants}"} err]} {
            ui_debug "Ignoring failure doing fetch for ${devport_name}: ${err}"
        }
        set devworkdir "[exec port work ${devport_name}]"
        if {${devworkdir} eq ""} {
            ui_error "port:${devport_name}'s work directory should exist by now!"
            return -code error "Internal devport PortGroup error"
        }
        set devdestdir "${devworkdir}/destroot"
        ui_debug "Cleaning ${devport_name}"
        # `port clean` can block on the registry lock so we do this manually:
        system "rm -rf ${devworkdir}"
        # now prepare the devport for our manual destroot "injection"
        ui_debug "port -nok -v build ${devport_name} ${cVariants}"
        # the fake build can be handled via the port driver up to the extract step
        # which might block on the registry lock. This also re-creates the work dir.
        system "port -nok -v fetch ${devport_name} ${cVariants}"
        # complete shunt of the extract, patch, configure and build steps so we won't lock
        system -W ${devworkdir} "echo \"target: org.macports.extract\" >> .macports.${devport_name}.state"
        system -W ${devworkdir} "echo \"target: org.macports.patch\" >> .macports.${devport_name}.state"
        system -W ${devworkdir} "echo \"target: org.macports.configure\" >> .macports.${devport_name}.state"
        system -W ${devworkdir} "echo \"target: org.macports.build\" >> .macports.${devport_name}.state"
        xinstall -m 755 -d ${devdestdir}
        ui_debug "unpacking the devport archive into ${devdestdir}"
        unpack_devtarball_from_to_for ${destroot} ${devdestdir} ${devport_name}
                system -W ${devworkdir} "echo \"target: org.macports.destroot\" >> .macports.${devport_name}.state"
        ui_debug "Deleting the devport archive"
        file delete ${destroot}${dev::archdir}/${dev::archname}
    }

}
# registers content that standard devports will contain
proc register_devport_standard_content {} {
    global subport destroot prefix mainport_name devport_name
    if {${subport} eq "${mainport_name}"} {
        ui_msg "---->  Transferring developer content to port:${devport_name}"
        ui_debug "Finding and registering standard content for the devport"
        foreach h [glob -nocomplain ${destroot}${prefix}/include/*] {
            ui_debug "\theader: ${h}"
            devport_content-append [string map [list ${destroot} ""] ${h}]
        }
        foreach h [glob -nocomplain ${destroot}${prefix}/lib/lib*.a] {
            ui_debug "\tstatic library: ${h}"
            devport_content-append [string map [list ${destroot} ""] ${h}]
        }
        foreach h [glob -nocomplain ${destroot}${prefix}/lib/lib*.la] {
            ui_debug "\t.la library: ${h}"
            devport_content-append [string map [list ${destroot} ""] ${h}]
        }
        foreach h [glob -nocomplain ${destroot}${prefix}/lib/lib*.dylib] {
            if {![string match -nocase {lib*.[0-9.]*.dylib} [file tail ${h}]] && [file type ${h}] eq "link"} {
                ui_debug "\tMac shared linker library: ${h}"
                devport_content-append [string map [list ${destroot} ""] ${h}]
            }
        }
        foreach h [glob -nocomplain ${destroot}${prefix}/lib/lib*.so] {
            if {[file type ${h}] eq "link"} {
                ui_debug "\tstandard Unix shared linker library: ${h}"
                devport_content-append [string map [list ${destroot} ""] ${h}]
            }
        }
        foreach h [glob -nocomplain ${destroot}${prefix}/lib/pkgconfig/*] {
            ui_debug "\tpkg-config file: ${h}"
            devport_content-append [string map [list ${destroot} ""] ${h}]
        }
    }
}

proc append_to_devport_standard_content {args} {
    global subport destroot prefix mainport_name devport_name
    if {${subport} eq "${mainport_name}"} {
        foreach pattern ${args} {
            ui_debug "Finding and registering additional content for the devport: \"${pattern}\""
            foreach h [glob ${destroot}${pattern}] {
                ui_debug "\tmatching: ${h}"
                devport_content-append [string map [list ${destroot} ""] ${h}]
            }
        }
    }
}

# check for the presence and basic validity of the -dev port tarball,
# restoring the file from the main port install image if required.
# Main purpose: allow reinstalling the -dev port after uninstalling it,
# without having to reinstall/re-activate the main port.
# Warnings but no errors are raised if this fails.
proc restore_devport_tarball {baseport} {
    global dev::archdir dev::archname
    if {[file exists ${dev::archdir}/${dev::archname}]
        && [file size ${dev::archdir}/${dev::archname}] > 0} {
        return 1
    }
    set ret 1
    if {![catch {set installed [lindex [registry_active ${baseport}] 0]}]} {
        set cVersion [lindex $installed 1]
        set cRevision [lindex $installed 2]
        set cVariants [lindex $installed 3]
        global name subport portdbpath os.platform os.major build_arch portarchivetype prefix
        set portimage "${portdbpath}/software/${baseport}/${baseport}-${cVersion}_${cRevision}${cVariants}.${os.platform}_${os.major}.${build_arch}.${portarchivetype}"
        if {[file exists ${portimage}]} {
            if {[catch {system -W ${dev::archdir} "bsdtar -xOf ${portimage} .${dev::archdir}/${dev::archname} > ${dev::archname}"} err]} {
                ui_warn "Failure restoring ${dev::archdir}/${dev::archname}: ${err}"
                set ret 0
            } elseif {![file exists ${dev::archdir}/${dev::archname}]
                || [file size ${dev::archdir}/${dev::archname}] == 0} {
                ui_warn "Failure restoring ${dev::archdir}/${dev::archname} - did you use sudo?"
                system "ls -l ${dev::archdir}/${dev::archname}*"
                set ret 0
            }

        } else {
            ui_warn "Calculated port image \"${portimage}\" doesn't exist"
            if {[file exists ${portdbpath}/software/${baseport}]} {
                ui_warn "Image directory content:"
                system "ls -1 ${portdbpath}/software/${baseport}"
            }
            set ret 0
        }
    } else {
        ui_warn "Cannot determine installed image name for ${baseport}"
        set ret 0
    }
    return ${ret}
}

proc unpack_devtarball_from_to_for {srcdir destdir portname} {
    global subport dev::archdir dev::archname mainport_name
    if {[file exists ${srcdir}${dev::archdir}/${dev::archname}]
        && [file size ${srcdir}${dev::archdir}/${dev::archname}] > 0} {
        ui_debug "Unpacking \"${srcdir}${dev::archdir}/${dev::archname}\" for ${portname}"
        if {[catch {system -W ${destdir} "bsdtar -xvf ${srcdir}${dev::archdir}/${dev::archname}"} err]} {
            ui_error "Failure unpacking ${srcdir}${dev::archdir}/${dev::archname}: ${err}"
        }
    } else {
        ui_error "The port's content archive doesn't exists or is empty (${srcdir}${dev::archdir}/${dev::archname})!"
        return -code error "Missing or invalid content archive; try re-activating or reinstalling port:${mainport_name}"
    }
}

proc unpack_devport_content {} {
    global destroot subport
    unpack_devtarball_from_to_for "" ${destroot} ${subport}
}

# Define (more so than create!) the devport
# and (231021) add post-installation logic to install/upgrade it after installing/upgrading
# the main port. See comments in the post-activate procedure for when we do and when we don't.
proc create_devport {dependency} {
    global subport mainport_name devport_name devport_description devport_long_description baseport \
            dev::archdir dev::archname \
            dev::mainport_installed
    # just so we're clear that what port we're talking about (the main port):
    set baseport ${mainport_name}
    subport ${devport_name} {
        description     [join ${devport_description}]
        long_description [join ${devport_long_description}]
        depends_fetch
        depends_build
        depends_lib
        # we really only have a runtime dependency on the mainport because it
        # expresses itself only when using the port for building a dependent.
        depends_run     ${dependency}
        depends_extract bin:bsdtar:libarchive
        installs_libs   yes
        supported_archs noarch
        distfiles
        fetch {}
        checksum {}
        extract {}
        use_configure   no
        patchfiles
        build           {}
        destroot {
            if {[restore_devport_tarball ${baseport}]} {
                unpack_devport_content
            } else {
                ui_error "The destroot phase of this port is handled by the main port (${mainport_name})!"
                ui_debug "###"
                ui_debug "### You will need to do (or 'rewind' and redo) the main port's destroot phase"
                ui_debug "###"
                return -code error "Please (re)invoke at least `port -n destroot ${mainport_name}` !"
            }
        }
        pre-activate {
            if {[file exists ${dev::archdir}/${dev::archname}]} {
                ui_info "${subport} is now installed, removing installed content archive ${dev::archdir}/${dev::archname}"
                file delete -force ${dev::archdir}/${dev::archname}
                # make sure the file exists to keep rev-upgrade happy
                # NB: this c/should be a symlink to the port's image tarball!
                system "touch ${dev::archdir}/${dev::archname}"
            }
        }
    }
    if {${subport} eq ${baseport}} {
        post-install {
            # register that we just have installed the main port
            set dev::mainport_installed yes
        }
        post-activate {
            # we activated a version/variant of the mainport; try to auto-install the corresponding
            # version/variant of the devport if the activation followed an install. We just remind
            # the user to do this manually if we only activated an already installed version/variant
            # (because the user might have deactivated the devport on purpose).
            if {![catch {set installed [lindex [registry_active ${baseport}] 0]}]} {
                set cVersion [lindex $installed 1]
                set cRevision [lindex $installed 2]
                set cVariants [lindex $installed 3]
                if {${dev::mainport_installed} eq yes} {
                    ui_msg "---->  Programming the delayed (!) installation of the dev port \"${devport_name} ${cVariants}\""
                    catch {
                        # check if our (new!) devport archive exists, which means we're
                        # dealing with an older build for which we need to fall back to
                        # cleaning the devport workdir before attempting an install.
                        if {[file exists ${dev::archdir}/${dev::archname}]
                            && [file size ${dev::archdir}/${dev::archname}] > 0} {
                                ui_msg "Cleaning ${devport_name}"
                                system "port -v clean ${devport_name}"
                        }
                        # we need to spawn/fork the actual install or else we'll be waiting
                        # indefinitely to obtain a lock on the registry!
                        if {![catch {registry_active ${devport_name}}]} {
                            # a version of the devport is already active; we are certain that
                            # we can use the fastest safe solution: `upgrade --force`
                            set dpinstmode upgrade
                            notes-append "port:${devport_name}@${cVersion}_${cRevision}${cVariants} will be upgraded and activated"
                            exec port -n ${dpinstmode} --force ${devport_name} ${cVariants} &
                        } else {
                            # the devport is not active or not installed. We want to use `archive`
                            # to keep it inactive after the install of this new version, but we
                            # need to do an uninstall for the case that the user is doing an `upgrade --force`
                            # in order to reinstall the current/new version.
                            set dpinstmode archive
                            notes-append "port:${devport_name}@${cVersion}_${cRevision}${cVariants} will be installed but not activated; you can do this manually if/when required"
                            exec sh -c "port -p -v uninstall ${devport_name}@${version}_${revision}${cVariants} ; \
                                port -n ${dpinstmode} ${devport_name} ${cVariants}" &
                        }
                    }
                } else {
                    ui_msg "${baseport}@${cVersion}_${cRevision}${cVariants} activated, please activate the corresponding port:${devport_name}!"
                }
            } else {
                if {${dev::mainport_installed} eq yes} {
                    set action "install"
                } else {
                    set action "activate"
                }
                ui_warning "---->  Couldn't obtain the required information to auto-${action} the devport!"
                ui_msg     "       Please ${action} port:${devport_name} with the same variants as the active port:${baseport}!"
            }
        }
    }
}

proc is_devport {} {
    global subport devport_name
    return [eval {"${subport}" eq "${devport_name}"}]
}

proc is_mainport {} {
    global subport mainport_name
    return [expr {${subport} eq "${mainport_name}"}]
}

# if {[is_mainport] && [file exists ${destroot}${dev::archdir}/${dev::archname}]} {
#     notes-append "Don't forget to upgrade port:${devport_name} after upgrading port:${mainport_name}"
# }
