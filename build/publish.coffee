gulp = require 'gulp'
gutil = require 'gulp-util'
ghPages = require 'gulp-gh-pages'
runSequence = require 'run-sequence'
fs = require 'fs'
request = require 'request'
pkg = require '../package.json'
helper = require './helper.coffee'

gulp.task 'publish.version', ->
  newVersion = getReleaseVersion()
  unless newVersion
    throw new Error('Publish: Invalid version in CHANGELOG.md')
    return

  pkg.version = newVersion
  fs.writeFileSync './package.json', JSON.stringify(pkg, null, 2)

  bowerConfig = require '../bower.json'
  bowerConfig.version = newVersion
  fs.writeFileSync './bower.json', JSON.stringify(bowerConfig, null, 2)

gulp.task 'publish.docs', ['docs.jade'], ->
  gulp.src '_docs/**/*'
    .pipe ghPages().on 'end', -> helper.removeDir '.publish'

gulp.task 'publish.createRelease', ->
  try
    token = require '../.token.json'
  catch e
    throw new Error 'Publish: Need github access token for creating release.'
    return

  createRelease token.github

gulp.task 'publish', ->
  runSequence 'publish.version', 'compile', 'test', 'docs', 'publish.docs', 'publish.createRelease'


getReleaseVersion = ->
  changelogs = fs.readFileSync('CHANGELOG.md').toString()
  result = changelogs.match /## V(\d+\.\d+\.\d+)/

  if result and result.length > 1
    result[1]
  else
    null

getReleaseContent = (version) ->
  changelogs = fs.readFileSync('CHANGELOG.md').toString()
  re = new RegExp "## V#{version.replace('.', '\\.')}.+\\n\\n((?:\\* .*\\n)+)"
  result = changelogs.match re

  if result and result.length > 1
    result[1]
  else
    null

createRelease = (token) ->
  pkg = require '../package.json'
  content = getReleaseContent pkg.version
  unless content
    throw new Error('Publish: Invalid release content in CHANGELOG.md')
    return

  request
    uri: "https://api.github.com/repos/#{pkg.githubOwner}/#{pkg.name}/releases"
    method: 'POST'
    json: true
    body:
      tag_name: "v#{pkg.version}",
      name: "v#{pkg.version}",
      body: content,
      draft: false,
      prerelease: false
    headers:
      Authorization: "token #{token}",
      'User-Agent': 'Mycolorway Release'
  , (err, response, body) ->
    if err
      gutil.log gutil.colors.red('Error occured while requesting github release API.')
    else if response.statusCode.toString().search(/2\d\d/) > -1
      gutil.log gutil.colors.green("#{pkg.name} v#{pkg.version} released on github!")
    else
      gutil.log gutil.colors.red("#{response.statusCode} #{JSON.stringify response.body}")
