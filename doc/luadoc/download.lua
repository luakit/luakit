--- Luakit download interface
--
-- This class provides an interface to managing ongoing downloads.
--
-- @class download
-- @author Fabian Streitel
-- @author Mason Larobina
-- @copyright 2011 Fabian Streitel <karottenreibe@gmail.com>
-- @copyright 2011 Mason Larobina <mason.larobina@gmail.com>

--- @property allow_overwrite
-- Whether this download should be permitted to overwrite any file already
-- existing at the destination.
-- @type boolean
-- @readwrite
-- @default `false`

--- @property destination
-- The path at which the downloaded file should be saved.
-- @type string
-- @readwrite
-- @default `nil`

--- @property progress
-- The download progress, ranging from 0.0 (no data yet received) to 1.0 (all
-- data received). This is only an estimate; see the @ref{current_size} property for
-- a more exact value.
-- @type number
-- @readonly

--- @property status
-- The download status. Will be one of `"created"`, `"started"`, `"cancelled"`,
-- `"finished"`, or `"failed"`.
-- @type string
-- @readonly

--- @property error
-- The error message for the download, or `nil`.
-- @type string|nil
-- @readonly

--- @property total_size
-- The total size of the file to be downloaded, including all data not yet
-- downloaded.
-- @type number
-- @readonly

--- @property current_size
-- The current size of all data that has been downloaded and written to the
-- destination.
-- @type number
-- @readonly

--- @property elapsed_time
-- The length of time that the download has been running, in seconds. This
-- includes any fractional part.
-- @type number
-- @readonly

--- @property mime_type
-- The MIME type of the download, if known.
-- @type string|nil
-- @readonly

--- @property suggested_filename
-- The suggested filename to use, for use in dialog boxes.
-- @type string
-- @readonly

--- @signal property::allow-overwrite
-- Emitted when the @ref{allow_overwrite} property has changed.

--- @signal property::destination
-- Emitted when the @ref{destination} property has changed.

--- @signal decide-destination
-- Emitted when a destination for the download must be decided. Handlers should
-- set the download's @ref{destination} property.
-- @tparam string suggested_filename The suggested filename for the download.
-- @treturn boolean `true` if the destination was decided.

--- @signal created-destination
-- Emitted when the destination has been created.
-- @tparam string destination The final destination for the download.

--- @signal error
-- Emitted when the download fails.
-- @tparam string message The error message.

--- @signal finished
-- Emitted when the download has finished.

-- vim: et:sw=4:ts=8:sts=4:tw=80
