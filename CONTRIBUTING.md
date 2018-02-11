# Contributing to luakit

## Submitting trivial fixes

If you notice a small issue that's easy to fix, you're free to submit
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
