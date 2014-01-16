middleman-slim-the-site
=======================

Will temporarily move files out of a Middleman site, to make development faster.

Developing in Middleman (esp. starting up and live reloading) can become quite
slow if the site is large. This script will slim down the site to a minimum of pages,
making it much faster to work with. After development is done, a companion script can
move the files back into the site again.

The script is written to be used inside an Automator action on a Mac. In its present
form, it will not run standalone (but it should be trivial to adapt it to that,
if you prefer to run it from the command line).

There is an automator action to slim down the site, and another to un-slim it in this
repository.

IMPORTANT! Before you use them, there are some things that needs to be done.

* Copy a security script (see below) to your config.rb, to protect the site from being built when slimmed down.

* Open both actions in automator and add the path to your site in the first 'Get Specified Finder Items'
  (It should point to the site directory (NOT the source folder).)

* Optionally, add search conditions to 'Find Finder Items' (like protecting files that has a certain label or
  files you've been working on today)

* Optionally, add files you want be sure will not be removed (the script is semi-smart about
  what to keep and what to remove, but it has no sure way to identify template files used
  to build dynamic pages)


### Add to config.rb

This is the security script, that should be added to your config.rb file.

Copy the block starting with `before do` and place it inside the `configure :build do` section
of your `config.rb` file (or create a new `configure :build do` if there is none).
This will prevent the site from being built while being slimmed down.

```
configure :build do   # This is normally already in the config.rb file
  before do           # Copy everything from and including this line...
    if File.exist? ( root + '/source' + '/_WARNING - This site is slimmed for development.lock')
      raise 'WARNING The site is slimmed down to make development faster. Do not build!'
    end               # ...to and including this line.
  end
```

### After running the script
If the Middleman server is running when you slim down or up the site, it will have to do
a lot of bookkeeping to handle the changes. Restart, or give it a while to catch up.


### Automator files

I'm uncertain how the Automator files will survive being pushed and pulled through git, so just to be sure
there are also zipped versions of the same files. (If you manage to pull the Automator files, and they
are ok, please tell me in the comments.)


### Configuring the Automator action

The first step, 'Get Specified Finder Items', is where you point Automator to your site. It should point to the site
directory (NOT the source folder).

'Find Finder Items' This will search for files to protect. Can be quite powerful. Use for stuff like protecting
files with a label or files that you've been working on the last week.
   IMPORTANT While it will work if set to search the entire Computer, it will be much faster if you point it to
your source folder.

If you want, you can add a 'Get Selected Finder Items'-step, for real quick selection of files or
directories that should be protected.

The second 'Get Specified Finder Items'. The script is semi-smart on what items to protect. But some stuff
is difficult to identify, like files that are used as templates for dynamic pages. Use this step
to manually set files and directories that should be protected.
