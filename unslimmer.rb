# encoding: UTF-8

# This is a companion script to slimmer.rb. It will put back the files that was removed (without overwriting changes
# that has been made).

require 'pathname'
require 'fileutils'
require 'logger'

# Setup logging
logpath = File.expand_path('~/Library/Logs/Middleman/Slimmer/slimmer.log')
FileUtils.mkdir_p(File.dirname(logpath))
$LOG = Logger.new(logpath, 'daily')
$LOG.level = Logger::INFO
$LOG.info '---------------------------------------------------------------'
$LOG.info 'STARTING UN-SLIM'

# Handle input from automator

if ARGV.empty?
  ARGV = ['/Users/Tommy/Sites/Middleman/anvandbart.se']
  $LOG.warn "No path(s) provided to the script. Using debug path #{ARGV[0]}"
end

input = []
ARGV.each do |f|
  input << f
end

Site = Pathname.new(input[0].strip)
$LOG.debug "Site: #{Site}"
Source  = Site + 'source'
$LOG.debug "Source: #{Source}"
Archive = Site + 'source_unslimmed_copy'     # Name of a temporary copy of the sites source directory
WARNING = Source + '_WARNING - This site is slimmed for development.lock'   # This is the name of a file created
# just to mark that the site has been slimmed down. It is used to avoid slimming the site twice by mistake,
# and to prevent the site from being built while slimmed.
#    If you change this name, change it also in the `before` block in your config.rb file (see below) and
#    in the slim script.


# Check that there is anything to put back
unless Archive.exist?
  $LOG.warn "Can not find a copy of the original site source. (Maybe the site is not slimmed?)"
  raise     'Can not find a copy of the original site source. (Maybe the site is not slimmed?)'
end

# Put it back

FileUtils.cd(Archive.to_s)
bring_back = Dir.glob('**/*').select { |fd| File.file?(fd) }    # All files

# Check that all directories are in place. (Since I did not remove any directories during slimming, they should be.
# If they are not it may be a sign that I've reorganized the site or something like that, and in that case I want
# a warning now, before starting to move things back to their old places. Thus, no mkdir here.)
bring_back.each do |local_path|
  errmsg = "Directory #{(Source + local_path).dirname} does not seam to exist (needed by #{local_path}"
  $LOG.error errmsg
  raise errmsg unless ((Source + local_path).dirname).exist?
end

# Move the files back – unless there already is a file at that location (existing file are
# assumed to be the same or a newer version)
brought_back = 0
trashed = 0
bring_back.each do |local_path|
  if (Source + local_path).exist?
    # There is already a (identical or newer) file there. Throw this one away.
    FileUtils.rm((Archive + local_path).to_s)
    $LOG.debug "#{local_path} already exist."
    trashed += 1
  else
    # Move it
    FileUtils.mv((Archive + local_path).to_s, (Source + local_path).to_s)
    $LOG.debug "Bringing back: #{local_path}"
    brought_back += 1
  end
end
$LOG.info "#{brought_back + trashed} files in unslimmed copy of source"
$LOG.info "#{trashed} files was already in place"
$LOG.info "Moved back #{brought_back} files"

# Remove the archive directory
unless (Dir.glob('**/*').select { |fd| File.file?(fd) }).empty?     # If there still are files
  errmsg = "There are still files in #{Archive.to_s}"
  $LOG.warn errmsg
  raise errmsg
end
FileUtils.rm_r(Archive.to_s)


# Remove lock
FileUtils.rm (Source + WARNING).to_s
$LOG.debug "Removed the warning"


