path        = require('path')
optimist    = require('optimist')
utils       = require('./utils')
fs          = require('fs')
compilers   = require('./compilers')
server      = require('./server')
application = require('./package')
testing     = require('./test')

# ------- Commandline arguments

argv = optimist.usage([
  'usage:\nhem COMMAND',
  '    server  :start a dynamic development server',
  '    build   :serialize application to disk',
  '    watch   :build & watch disk for changes'
  '    test    :build and run tests'
  '    clean   :clean compiled targets'
  '    version :version the application files'
].join("\n"))
.alias('p', 'port').describe('p',':hem server port')
.alias('c', 'compress').describe('c',':all complications are compressed/minified')
.alias('w', 'watch').describe('w',':watch files when running tests')
.alias('s', 'slug').describe('s',':run hem using a specified slug file')
.alias('n', 'nocolors').describe('n',':disable color in console output')
.describe('v',':make hem more talkative(verbose)')
.argv

# set command and targets properties
argv.command = argv._[0]
argv.targets = argv._[1..]

# disable colors
require("sty").disable() if !!argv.nocolors

# expose argv 
utils.ARGV = argv

# always have a value for these argv options
utils.COMPRESS = argv.compress = !!argv.compress
utils.VERBOSE  = argv.v        = !!argv.v
utils.COMMAND  = argv.command

# ------- Global Functions

help = ->
  utils.log "<b>HEM</b> Version: <green>" + require('../package.json')?.version + "</green>\n"
  optimist.showHelp()
  process.exit()

# ------- Hem Class

class Hem

  @exec: (command, options) ->
    (new @(options)).exec(command)

  @include: (props) ->
    @::[key] = value for key, value of props

  @middleware: (slugFile) ->
    hem = new Hem(slugFile)
    server.middleware(hem, hem.options.server)

  # ------- instance variables

  compilers: compilers

  # the slug directory
  homeDir: '' 

  # default values for server
  options:
    server:
      port: 9294
      host: "localhost"

  # emtpy applications list
  apps: []

  # ------- Constructor

  constructor: (options = {}) ->
    # handle slug file
    if options is "string"
      slug = options
    else
      slug = argv.slug or './slug.json'
      @options[key] = value for key, value of options

    # quick check to make sure slug file exists
    if fs.existsSync(slug)
      @options[key] = value for key, value of @readSlug(slug)
      # make sure we are in same directory as slug
      @homeDir = path.dirname(path.resolve(process.cwd() + "/"  + slug))
      process.chdir(@homeDir)
    else
      utils.errorAndExit "Unable to find #{slug} file in current directory"

    # allow overrides and set defaults
    @options.server.port = argv.port if argv.port
    @options.server.host or= ""
    @options.server.routes or= []

    # setup applications from options/slug
    for name, config of @options
      continue if name is "server"
      @apps.push application.createApplication(name, config)

  # ------- Command Functions

  server: ->
    utils.log "Starting Server at <blue>http://#{@options.server.host or "localhost"}:#{@options.server.port}</blue>"
    server.start(@, @options.server)

  clean: ->
    targets = argv.targets
    cleanAll = targets.length is 0
    app.unlink() for app in @apps when app.name in targets or cleanAll

  build: ->
    @clean()
    @buildTargets(argv.targets)

  version: ->
    @versionTargets(argv.targets)

  watch: ->
    targets = argv.targets
    @buildTargets(targets)
    watchAll = targets.length is 0
    app.watch() for app in @apps when app.name in targets or watchAll

  test: ->
    targets = argv.targets
    testOptions = {}
    if argv.watch
      @watch()
      testOptions.singleRun = false
    else
      @buildTargets(targets)
      testOptions.singleRun = true
    @testTargets(targets, testOptions)

  exec: (command = argv.command) ->
    return help() unless @[command]
    switch command
      when 'test'    then utils.log 'Test application'
      when 'clean'   then utils.log 'Clean application'
    @[command]()

  # ------- Private Functions

  readSlug: (slug) ->
    return {} unless slug and fs.existsSync(slug)
    JSON.parse(fs.readFileSync(slug, 'utf-8'))

  getTargetApps: (targets = []) ->
    targetAll = targets.length is 0
    (app for app in @apps when app.name in targets or targetAll)

  testTargets: (targets = [], options = {}) ->
    testApps = (app for app in @getTargetApps(targets) when app.test)
    testing.run(@, testApps, options)

  buildTargets: (targets = []) ->
    app.build() for app in @getTargetApps(targets)

  versionTargets: (targets = []) ->
    app.version() for app in @getTargetApps(targets)



module.exports = Hem

