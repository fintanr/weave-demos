#
# AppArmor confinement for docker daemon
#
# This confinement is intentionally not restrictive and is here to help guard
# against programming errors and not for security confinement. docker daemon
# requires far too much access to effictively confine and by its very nature it
# must be considered a trusted service.
#

#include <tunables/global>

# Specified profile variables
@{CLICK_DIR}="{/apps,/custom/click,/usr/share/click/preinstalled}"
@{APP_PKGNAME}="docker"
@{APP_APPNAME}="docker"
@{APP_VERSION}="1.4.1.001"

profile "docker_docker_1.4.1.001" (attach_disconnected) {
  #include <abstractions/base>
  #include <abstractions/consoles>
  #include <abstractions/dbus-strict>
  #include <abstractions/nameservice>
  #include <abstractions/openssl>
  #include <abstractions/ssl_certs>

  # FIXME: app upgrades don't perform migration yet. When they do, remove
  # these two rules and update package-dir/bin/docker.wrap as per its comments.
  # See: https://app.asana.com/0/21120773903349/21160815722783
  /var/lib/apps/@{APP_PKGNAME}/   w,
  /var/lib/apps/@{APP_PKGNAME}/** wl,

  # Read-only for the install directory
  @{CLICK_DIR}/@{APP_PKGNAME}/                   r,
  @{CLICK_DIR}/@{APP_PKGNAME}/@{APP_VERSION}/    r,
  @{CLICK_DIR}/@{APP_PKGNAME}/@{APP_VERSION}/**  mrklix,

  # Writable path
  @{CLICK_DIR}/@{APP_PKGNAME}/@{APP_VERSION}/.docker/**  mrwklix,

  # Need to be able to read access /home to read Dockerfile:
  owner /home/** mrwklix,

  # Writable home area
  owner @{HOMEDIRS}/apps/@{APP_PKGNAME}/   rw,
  owner @{HOMEDIRS}/apps/@{APP_PKGNAME}/** mrwklix,

  # Read-only system area for other versions
  /var/lib/apps/@{APP_PKGNAME}/   r,
  /var/lib/apps/@{APP_PKGNAME}/** mrkix,

  # TODO: the write on  /var/lib/apps/@{APP_PKGNAME}/ is needed in case it
  # doesn't exist, but means an app could adjust inode data and affect
  # rollbacks.
  /var/lib/apps/@{APP_PKGNAME}/                  w,

  # Writable system area only for this version.
  /var/lib/apps/@{APP_PKGNAME}/@{APP_VERSION}/   w,
  /var/lib/apps/@{APP_PKGNAME}/@{APP_VERSION}/** wl,

  /writable/cache/docker/   rw,
  /writable/cache/docker/** mrwklix,

  # Allow our pid file and socket
  /run/@{APP_PKGNAME}.pid rw,
  /run/@{APP_PKGNAME}.sock rw,

  # Wide read access to /proc, but somewhat limited writes for now
  @{PROC}/** r,
  @{PROC}/[0-9]*/attr/exec w,
  @{PROC}/sys/net/** w,

  # Wide read access to /sys
  /sys/** r,
  # Limit cgroup writes a bit
  /sys/fs/cgroup/*/docker/   rw,
  /sys/fs/cgroup/*/docker/** rw,
  /sys/fs/cgroup/*/system.slice/   rw,
  /sys/fs/cgroup/*/system.slice/** rw,

  # We can trace ourselves
  ptrace (trace) peer=@{profile_name},

  # Docker needs a lot of caps, but limits them in the app container
  capability,

  # Allow talking to systemd
  dbus (send)
       bus=system
       peer=(name=org.freedesktop.systemd*,label=unconfined),
  # Allow receiving from unconfined
  dbus (receive)
       bus=system
       peer=(label=unconfined),

  # Allow execute of anything we need
  /{,usr/}bin/* pux,
  /{,usr/}sbin/* pux,

  # Docker does all kinds of mounts all over the filesystem
  /dev/mapper/control rw,
  /dev/mapper/docker* rw,
  /dev/loop* r,
  /dev/loop[0-9]* w,
  mount,
  umount,
  pivot_root,
  /.pivot_root*/ rw,

  # for console access
  /dev/ptmx rw,

  # For loading the docker-default policy. We might be able to get rid of this
  # if we load docker-default ourselves and make docker not do it.
  /sbin/apparmor_parser ixr,
  /etc/apparmor*/** r,
  /var/lib/apparmor/profiles/docker rw,
  /etc/apparmor.d/cache/docker* w,
  /sys/kernel/security/apparmor/** rw,

  # We'll want to adjust this to support --security-opts...
  change_profile -> docker-default,
  signal (send) peer=docker-default,
  ptrace (read, trace) peer=docker-default,

#cf bug 1411639
  /dev/dm-* rw,
  /dev/net/ r,
  /dev/snd/ r,
  /dev/ r,
  /dev/block/ r,
  /dev/bsg/ r,
  /dev/char/ r,
  /dev/cpu/ r,
  /dev/disk/ r,
  /dev/disk/by-id/ r,
  /dev/disk/by-label/ r,
  /dev/disk/by-partlabel/ r,
  /dev/disk/by-partuuid/ r,
  /dev/disk/by-path/ r,
  /dev/disk/by-uuid/ r,
  /dev/hugepages/ r,
  /dev/input/ r,
  /dev/input/by-path/ r,

  /dev/mapper/ r,
  /dev/mqueue/ r,

  /proc r, # for some reason only this works and not @{PROC} or anything

  change_profile -> unconfined,
  ptrace (read) peer=unconfined,
  signal (send) peer=unconfined,
}
