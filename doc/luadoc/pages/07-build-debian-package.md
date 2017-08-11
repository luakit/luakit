@name Build Debian package

# Build Debian package

## Prepare the build environment (need just once)

Install necessary packages:

    $ sudo apt-get install gitpkg pbuilder

Create pbuilder build chroot environments for Debian Strech (stable), Buster (testing), Sid (unstable):

    $ sudo pbuilder create --distribution strech --basetgz /var/cache/pbuilder/base-strech.tgz --mirror http://ftp.debian.org/debian
    $ sudo pbuilder create --distribution buster --basetgz /var/cache/pbuilder/base-buster.tgz --mirror http://ftp.debian.org/debian
    $ sudo pbuilder create --distribution sid --basetgz /var/cache/pbuilder/base-sid.tgz --mirror http://ftp.debian.org/debian

Note: Just skip whatever Debian distributions you don't need.

Clone luakit source code:

    $ mkdir ~/debian
    $ cd ~/debian
    $ git clone https://github.com/luakit/luakit.git
    $ cd luakit

Setup gitpkg hook:

    $ git config gitpkg.deb-export-hook debian/source/gitpkg-deb-export-hook

## Build Debian package for current release

Find the git tags of current release:

    $ git tag
    ...
    2017.08.10
    debian/2017.08.10-1

Export luakit source code to Debian source packages:

    $ gitpkg debian/2017.08.10-1 2017.08.10

Debian source packages could be found in:

    $ ls -1 ../deb-packages/luakit
    luakit_2017.08.10-1.debian.tar.xz
    luakit_2017.08.10-1.dsc
    luakit_2017.08.10.orig.tar.gz

Update the pbuilder build chroot environments:

    $ sudo pbuilder update --distribution strech --basetgz /var/cache/pbuilder/base-strech.tgz
    $ sudo pbuilder update --distribution buster --basetgz /var/cache/pbuilder/base-buster.tgz
    $ sudo pbuilder update --distribution sid --basetgz /var/cache/pbuilder/base-sid.tgz

Note: Again, just skip whatever Debian distributions you don't need.

Build the Debian source packages:

    $ sudo pbuilder build --distribution strech --basetgz /var/cache/pbuilder/base-strech.tgz --buildresult ../deb-packages/luakit/strech ../deb-packages/luakit/luakit_2017.08.10-1.dsc
    $ sudo pbuilder build --distribution buster --basetgz /var/cache/pbuilder/base-buster.tgz --buildresult ../deb-packages/luakit/buster ../deb-packages/luakit/luakit_2017.08.10-1.dsc
    $ sudo pbuilder build --distribution sid --basetgz /var/cache/pbuilder/base-sid.tgz --buildresult ../deb-packages/luakit/sid ../deb-packages/luakit/luakit_2017.08.10-1.dsc

Result binary packages could be found in:

    $ ls -1 ../deb-packages/luakit/{strech,buster,sid}
    luakit_2017.08.10-1_amd64.buildinfo
    luakit_2017.08.10-1_amd64.changes
    luakit_2017.08.10-1_amd64.deb
    luakit_2017.08.10-1.debian.tar.xz
    luakit_2017.08.10-1.dsc
    luakit_2017.08.10.orig.tar.gz
    luakit-dbgsym_2017.08.10-1_amd64.deb

Install the binary package, for Debian Sid (unstable):

    $ sudo dpkg -i ../deb-packages/luakit/sid/luakit_2017.08.10-1_amd64.deb
    $ sudo apt-get install -f
