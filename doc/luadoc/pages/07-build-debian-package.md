@name Building a Debian Package

# Building a Debian Package

## Preparing the build environment

First, it is necessary to set up the build environment and install
required packages. These steps only have to be done once.

Install the following packages:

    $ sudo apt-get install gitpkg pbuilder

Next, create a `pbuilder` build chroot environment in which to build the
package. The following commands all use Debian Stretch; to use Buster or
Sid releases, change `stretch` to `buster` or `sid` in the commands below.

    $ sudo pbuilder create --distribution strech \
	      --basetgz /var/cache/pbuilder/base-strech.tgz \
		  --mirror http://ftp.debian.org/debian

Clone the luakit source code to a local directory:

    $ mkdir ~/debian
    $ cd ~/debian
    $ git clone https://github.com/luakit/luakit.git
    $ cd luakit

Finally, setup the `gitpkg` hook:

    $ git config gitpkg.deb-export-hook debian/source/gitpkg-deb-export-hook

## Building a Debian package for the current release

Find the git tag for the current release:

    $ git tag
    ...
    2017.08.10
    debian/2017.08.10-1

The following commands all use `2017.08.10` as the release date; make
sure you substitute the correct release.

Export the luakit source code to Debian source packages:

    $ gitpkg debian/2017.08.10-1 2017.08.10

Now, debian source packages can be found in:

    $ ls -1 ../deb-packages/luakit
    luakit_2017.08.10-1.debian.tar.xz
    luakit_2017.08.10-1.dsc
    luakit_2017.08.10.orig.tar.gz

Update the pbuilder build chroot environment:

    $ sudo pbuilder update --distribution strech \
	      --basetgz /var/cache/pbuilder/base-strech.tgz

Finally, build the Debian source package:

    $ sudo pbuilder build --distribution strech \
	      --basetgz /var/cache/pbuilder/base-strech.tgz \
		  --buildresult ../deb-packages/luakit/strech \
		  ../deb-packages/luakit/luakit_2017.08.10-1.dsc

The resulting binary package can now be found in the output directory:

    $ ls -1 ../deb-packages/luakit/stretch
    luakit_2017.08.10-1_amd64.buildinfo
    luakit_2017.08.10-1_amd64.changes
    luakit_2017.08.10-1_amd64.deb
    luakit_2017.08.10-1.debian.tar.xz
    luakit_2017.08.10-1.dsc
    luakit_2017.08.10.orig.tar.gz
    luakit-dbgsym_2017.08.10-1_amd64.deb

To install luakit, run the following:

    $ sudo dpkg -i ../deb-packages/luakit/stretch/luakit_2017.08.10-1_amd64.deb
    $ sudo apt-get install -f
