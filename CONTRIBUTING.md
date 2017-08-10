# Contributing to luakit

## How to ask for help

If you're having difficulty with any aspect of luakit, a good place to
ask is [here](https://github.com/luakit/luakit/issues) on the luakit issue
tracker. This will require making a GitHub user account if you do not
already have one.

It's a good idea to search the issue tracker before asking, in case your
question has already been asked and answered.

## How to report a bug

Please report any bugs or issues you find
[here](https://github.com/luakit/luakit/issues) on the luakit issue tracker.
This will require making a GitHub user account if you do not already
have one.

Please search the issue tracker before opening a new issue; if someone
has already reported the same issue, it's better to comment on that
issue instead of opening a new one.

Please include the following information in your bug report:

 - Current luakit version; this can be found by running `luakit --version` in the terminal.

   Example: `luakit 2012.09.13-r1-1722-gca2571be`

 - Current operating system, version, and CPU architecture, if applicable. E.g

   Examples: "Ubuntu 16.04 on i386", "Arch 64-bit"

 - If luakit was working recently but broke in an update, please also include
   the version number for the most recent known-working build.

## How to request a new feature / make a suggestion

Feature requests can be made [here](https://github.com/luakit/luakit/issues)
on the luakit issue tracker. It's always a good idea to search before
opening a new issue, in case anyone has already requested that feature
or made a similar/related suggestion.

## Submitting trivial fixes

If you notice a small issue that's easy to fix, you're free to submut
a pull request or patch directly, without asking or opening an issue
first. This includes spelling / grammar mistakes, whitespace /
formatting fixes, and any tweaks needed to get luakit to run.

## Submitting pull requests and patches

If you plan to submit more involved patches, here's a checklist:

1. Unless you're contributing something you've already written, please
   open an issue to first discuss your plan; maintainers of luakit may have
   preferences about how you implement your goal or insights about needed
   changes.

2. Focus on a single goal at a time:
	- Do _not_ modify piece of code not related to your commit
	- Do _not_ include fixes for existing code-style problems; it's just adding noise for no gain

3. Ensure your commits are well-formed:
	- Make commits of logical units
    - Provide a meaningful commit message for each commit: the first line
      of the commit message should be a short description and should skip the
      full stop

4. Check for problems and formatting errors:
	- Ensure that your work does not cause any tests to fail
	- Add new tests if appropriate
	- Add an entry to the changelog if appropriate
	- Check for unnecessary whitespace with "git diff --check" before committing
	- Do not check in commented out code or unneeded files

GitHub pull requests should be made against [https://github.com/luakit/luakit/](https://github.com/luakit/luakit/).
