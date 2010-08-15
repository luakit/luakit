--- luakit core API
-- @author Mason Larobina &lt;mason.larobina&lt;AT&gt;gmail.com&gt;
-- @author Paweł Zuzelski &lt;pawelz&lt;AT&gt;pld-linux.org&gt;
-- @copryight 2010 Mason Larobina, Paweł Zuzelski
module("luakit")

--- Quit luakit
-- @param -
-- @name quit
-- @class function

--- Get selection
-- @param clipboard X clipboard name ('primary', 'secondary' or 'clipboard')
-- @return A string with the selection (clipboard) content.
-- @name get_selection
-- @class function

--- Set selection
-- @param text UTF-8 string to be copied to clipboard
-- @param clipboard X clipboard name ('primary', 'secondary' or 'clipboard')
-- @name set_selection
-- @class function

--- Spawn process asynchronously
-- @param cmd Command to execute. It is parsed with simple shell-like parser.
-- @name spawn
-- @class function

--- Spawn process synchronously
-- @param cmd Command to execute. It is parsed with simple shell-like parser.
-- @return An exit status of the command.
-- @return A string containig data printed on stdout.
-- @return A string containig data printed on stderr.
-- @name spawn_sync
-- @class function
