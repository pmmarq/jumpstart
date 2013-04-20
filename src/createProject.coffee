fs = require "fs"
fsExists = require "fs-exists"
readdir = require "recursive-readdir"
Memoblock = require "memoblock"
faithful = require "faithful"
mkdirp = require "mkdirp"
_ = require "underscore"
getDirname = require("path").dirname

renames = require "./renames"

{reduce,each,adapt,collect,map,applyEach,filter} = faithful

readFile = adapt fs.readFile
writeFile = adapt fs.writeFile
fsExists = adapt fsExists
rename = adapt fs.rename
readdir = adapt readdir
mkdirp = adapt mkdirp

module.exports = createProject = (targetDir, templateDir, getValues) ->
  Memoblock.do [
    -> @targetExists = fsExists targetDir
    -> throw new Error "Target directory #{targetDir} already exist." if @targetExists
    -> @paths = readdir templateDir
    -> @buffers = map @paths, readFile
    -> @contents = @buffers.map (buffer) -> buffer.toString()
    -> @varNamesArrays = @buffers.map (buffer) -> findPlaceholderNames buffer
    -> @varNames = _.union.apply {}, @varNamesArrays
    -> @values = getValues @varNames
    -> @targetPaths = @paths.map (path) -> path.replace templateDir, targetDir
    -> @replacements = ([new RegExp("---#{n}---","g"),v] for n,v of @values)
    -> @newContents = @contents.map (contents) => @replacements.reduce replace, contents
    -> @targetDirs = _.unique @targetPaths.map getDirname
    -> @makingPaths = each @targetDirs, mkdirp
    -> @writingFiles = applyEach _.zip(@targetPaths,@newContents), writeFile
    -> @rPaths = filter Object.keys(renames), (path) -> fsExists "#{targetDir}/#{path}"
    -> @renamePairs = (["#{targetDir}/#{path}","#{targetDir}/#{renames[path]}"] for path in @rPaths)
    -> @renamingFiles = applyEach @renamePairs, rename
  ]

replace = (string, replacement) ->
  string.replace replacement[0], replacement[1]

findPlaceholderNames = (contents) ->
  return [] unless matches = contents.toString().match  /---([a-z]+(-[a-z]+)*)---/g
  return (match.substring 3,match.length-3 for match in matches)