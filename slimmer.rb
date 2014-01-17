# encoding: UTF-8

# Middlemans development environment (starting up and live reloading) can become quite
# slow if the site is large. This script will slim down the site to a minimum of pages,
# making it much faster to work with. After development is done, a companion script can
# un-slim it, replacing all the removed files again.
#   Note that directly after slimming/un-slimming Middleman will have a lot of bookkeeping
# to do handling the massive change of the site. Give it a few minutes, and it will soon
# be back to normal.
#
# IMPORTANT  To do before running the script:
#
# * Copy the security script to your config.rb, to protect the site from being built when slimmed.
#
# * Open in automator and add the path to your site in the first 'Get Specified Finder Items'
#   (It should point to the site directory (NOT the source folder).)
#
# * Optionally, add search conditions to 'Find Finder Items' (like protecting files with a certain label or
#   files you've been working on today)
#
# * Optionally, add files you want be sure will not be removed (the script is semi-smart about
#   what to keep and what to remove, but it has no sure way to identify template files used
#   to build dynamic pages)


# IMPORTANT! COPY THIS TO YOUR CONFIG.RB
# Copy the block starting with `before do` and place it inside the `configure :build do` section
# of your `config.rb` file (or create a new `configure :build do` if there is none).
#   This will prevent the site from being built while being slimmed.
#
=begin
configure :build do   # This is normally already in the config.rb file
  before do           # Copy everything from and including this line...
    if (Pathname.new(root) + source + '_WARNING - This site is slimmed for development.lock').exist?
      raise 'WARNING The site is slimmed down to make development faster. Do not build!'
    end
  end                 # ...to and including this line.
end
=end


# AUTOMATOR NOTES
#
# Steps
#
# The first step, 'Get Specified Finder Items', is where you point Automator to your site. It should point to the site
# directory (NOT the source folder).
#
# 'Find Finder Items' This will search for files to protect. Can be quite powerful. Use for stuff like protecting
# files with a label or files that you've been working on the last week.
#    IMPORTANT While it will work if set to search the entire Computer, it will be much faster if you point it to
# your source folder.
#
# If you want, you can add a 'Get Selected Finder Items'-step, for real quick protection.
#
# The second 'Get Specified Finder Items'. The script is semi-smart on what items to protect. But some stuff
# is difficult to identify, like files that are used as templates for dynamic pages. Use this step
# to manually set files and directories that should be protected.
#


require 'pathname'
require 'fileutils'
require 'logger'

# Setup logging
logpath = File.expand_path('~/Library/Logs/Middleman/Slimmer/slimmer.log')
FileUtils.mkdir_p(File.dirname(logpath))
$LOG = Logger.new(logpath, 'daily')
$LOG.level = Logger::INFO
$LOG.info '==============================================================='
$LOG.info 'STARTING SLIM'

# Handle input from automator

# For debugging
if ARGV.empty?
  ARGV = ['/Users/Tommy/Sites/Middleman/anvandbart.se']
  $LOG.warn "No path(s) provided to the script. Using debug path #{ARGV[0]}"
end


input = []
ARGV.each do |f|
  input << f
end

$LOG.debug 'input: ' + input.join(' | ')

# Automator sometimes adds a little extra space in path. Clean it up.
# Also convert input to UTF-8
input = input.map do |path|
  path.strip
  path.encode('utf-8', 'iso-8859-1')  # from iso-8859-1 to utf-8   # Needs Ruby 2.0
end

# Last item is the site directory. The rest is stuff that should be protected from being slimmed away.
Site = Pathname.new(input.pop)
$LOG.debug "Site: #{Site}"
Source  = Site + 'source'
$LOG.debug "Source: #{Source}"

# Logging files protected by Automator
if input.empty?
  $LOG.info "No files protected by Automator"
else
  input.each {|path| $LOG.info "Protected by Automator: #{path}" }
  $LOG.info "#{input.count} files protected by Automator"
end

# Removing some unneeded stuff from input
input.uniq!       # Removing any duplicates
input = input - [Site.to_s, Source.to_s]    # The site or source folders can not be protected, since it
      # would render this script pointless

# Translating the absolute paths to local paths, and removing those that are not in the Source folder
local_paths = []
input.each do |absolute_path|
  prefix = Source.to_s + '/'               #i.e. inside the source folder
  if absolute_path.start_with?(prefix)     # Note that if it does not, it is not in the source dir and will not be included
    local_paths << absolute_path[prefix.length..-1]
  end
end

Protected = local_paths
$LOG.debug 'Protected: ' + Protected.join(' | ')

=begin   # This code is left here for debugging (when running without automator)
Site = Pathname.new(File.expand_path('~/Sites/Middleman/anvandbart.se'))   # Path to the site directory
Source  = Site + 'source'
Protected = [         # Add any files you want to protect from being removed.
    # For example template files used by dynamic pages.
    # Use paths relative to `source`, like 'blog/an_article.html.markdown'
    'ab/anvandbarhet.html.erb',
    'blogsource/strategiskdesign.html.haml'
]
=end


Archive = Site + 'source_unslimmed_copy'            # Name of a temporary copy of the sites source directory
WARNING = Source + '_WARNING - This site is slimmed for development.lock'   # This is the name of a file created
      # just to mark that the site has been slimmed down. It is used to avoid slimming the site twice by mistake,
      # and to prevent the site from being built while slimmed.
      #    If you change this name, change it also in the `before` block in your config.rb file (see above) and
      #    in the unslim script.


# Start slimming the site
FileUtils.cd(Source.to_s)

# Check that the site is not already slimmed
if File.exist? WARNING
  $LOG.warn 'This site indicates that it is already in a slimmed state'
  raise     'This site indicates that it is already in a slimmed state'
end

# Make a complete copy of source
FileUtils.copy_entry(Source, Archive)

# Split Protected into two separate lists, for files and for directories
protected_files = Protected.select { |fd| File.file?(fd) }
$LOG.debug 'Protected files: ' + protected_files.join(' | ')
protected_directories = Protected.select { |fd| File.directory?(fd) }
$LOG.debug 'Protected directories: ' + protected_directories.join(' | ')


# First, get all files that are candidates to be removed (i.e. files with `.html` in their names)
remove_candidates = Dir.glob('**/*.html*').select { |fd| File.file?(fd) }  # This will just return files, no directories
$LOG.debug 'First list of files that are to be removed: ' + remove_candidates.join(' | ')

# Then identify those that are to be kept
stay_candidates = Dir.glob('**/index.*')    # Any index file
stay_candidates += protected_files          # Manually added at the beginning of this script
$LOG.debug 'Index-files (not to be removed): ' + stay_candidates.join(' | ')

# Only move those files that are not to stay
remove_candidates = remove_candidates - stay_candidates

# Some directories are protected, as are some markers in the file name, suffixes etc.
remove_candidates = remove_candidates.reject do |local_path|
  case local_path
    when /^_|\/_/,      # If local path contains a directory or a file that starts with an underscore, don't touch it
        /^\.|\/\./,     # If local path contains a directory or a file that starts with a dot, don't touch it
        /^javascripts\/|\/javascripts\//,     # It should be rare that any of these three folder contains a
        /^layouts\/|\/javascripts\//,         # file with .html in the name. But just to be sure.
        /^stylesheets\/|\/javascripts\//,     #
        /.html$/,       # IMPORTANT! I have found no way to reliably identify all templates for dynamic pages.
                        # You will have to manually add them to the manual selection above. This will however
                        # handle those that ends with .html
        /.builder$/
      true
    else
      false
  end
end

# Protecting directories and making sure there are enough files in the others

#     Put into hash, to be able to count the number of files in each directory
remove_candidates_directories = {}
remove_candidates.each do |local_path|
  directory = File.dirname(local_path)
  directory = :root if directory == ''
  remove_candidates_directories[directory] = [] unless remove_candidates_directories.has_key?(directory)
  remove_candidates_directories[directory] << local_path
end

#     Protect some directories
protected_directories.each do |local_path|
  remove_candidates_directories.delete(local_path)
end


#     Then protect a number of items in each directory, before putting them back into remove_candidates
remove_candidates = []
remove_candidates_directories.each do |key, value|
  # Always keep 15 files (or as many as are available if fewer) in a directory, plus index and other protected
  # files. This to avoid making index pages, lists etc. empty.
  remove_candidates += value - value.sample(14)   # Requires Ruby 1.9.1+. If earlier, this can be used instead:
  # remove_candidates += value[15..-1]
end

# Remove!
#     A 'lock'-file is created, to avoid slimming the site twice by mistake
FileUtils.touch (WARNING).to_s
FileUtils.rm remove_candidates
$LOG.debug 'Removed files: ' + remove_candidates.join(' | ')
$LOG.info "Removed #{remove_candidates.count} files"


