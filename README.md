# Heroku Buildpack for Bower and Grunt

This is a [Heroku buildpack](http://devcenter.heroku.com/articles/buildpacks) for [Bower](http://bower.io) & [Grunt](http://gruntjs.com).

## How it Works

This buildpack was started as a fork from the [official Heroku buildpack for Node.js apps](https://github.com/heroku/heroku-buildpack-nodejs), and as such, has many of the same features.

This buildpack can be used alone or as part of a chain of multiple buildpacks, whether Node or something else.
It does not require the Node buildpack, and will work as long as you've got a package.json file, and one of bower.json, Gruntfile.js, or Gruntfile.coffee.

This buildpack installs npm packages from your devDependencies, then cleans them up after it's done so that your slug stays small.

This buildpack will install bower and grunt-cli for you, since you should've installed them globally, and not added them to your devDependencies.

It will call bower and then grunt in that order, if necessary.

If you've got a bower.json file, then the buildpack will run `bower install`.
If `$NPM_CONFIG_PRODUCTION` is true (default), then we will use the `--production` flag.

If you've got a Gruntfile.js or Gruntfile.coffee file, then the buildpack will run `grunt heroku`.
You must have a task registered like so in your Gruntfile: `grunt.registerTask('heroku', ['some', 'thing']);`.
You also should have grunt, and the various grunt npm libraries you use defined in devDependencies of your package.json.

## Typical Usage

You'll first want you to set your buildpack to the multi buildpack:

    $ heroku buildpacks:set https://github.com/heroku/heroku-buildpack-multi.git

From here you will need to create a `.buildpacks` file which contains (in order) the buildpacks you wish to run when you deploy:

    $ cat .buildpacks
    https://github.com/heroku/heroku-buildpack-nodejs.git
    https://github.com/gfguthrie/heroku-buildpack-bower-grunt.git

## Inspiration

Thanks to [Matthias Buchetics](https://github.com/mbuchetics) for ideas taken from his [Node.js Grunt buildpack](https://github.com/mbuchetics/heroku-buildpack-nodejs-grunt).

## Options

These options are the holdovers left from this project being a fork of the Node.js buildpack.

### Specify a node version

Set engines.node in package.json to the semver range
(or specific version) of node you'd like to use.
(It's a good idea to make this the same version you use during development)

```json
"engines": {
  "node": "0.11.x"
}
```

```json
"engines": {
  "node": "0.10.33"
}
```

Default: the
[latest stable version.](http://semver.io/node)

### Specify an npm version

Set engines.npm in package.json to the semver range
(or specific version) of npm you'd like to use.
(It's a good idea to make this the same version you use during development)

Since 'npm 2' shipped several major bugfixes, you might try:

```json
"engines": {
  "npm": "2.x"
}
```

```json
"engines": {
  "npm": "^2.1.0"
}
```

Default: the version of npm bundled with your node install (varies).

### Configure npm with .npmrc

Sometimes, a project needs custom npm behavior to set up proxies,
use a different registry, etc. For such behavior,
just include an `.npmrc` file in the root of your project:

```
# .npmrc
registry = 'https://custom-registry.com/'
```

## Feedback

Having trouble? Dig it? Feature request?

- [@gfguthrie](http://twitter.com/gfguthrie)
- [github issues](https://github.com/gfguthrie/heroku-buildpack-bower-grunt/issues)

## Hacking

To make changes to this buildpack, fork it on Github. Push up changes to your fork, then create a new Heroku app to test it, or configure an existing app to use your buildpack:

```
# Create a new Heroku app that uses your buildpack
heroku create --buildpack <your-github-url>

# Configure an existing Heroku app to use your buildpack
heroku config:set BUILDPACK_URL=<your-github-url>

# You can also use a git branch!
heroku config:set BUILDPACK_URL=<your-github-url>#your-branch
```

## Testing

The buildpack tests use [Docker](https://www.docker.com/) to simulate
Heroku's Cedar and Cedar-14 containers.

To run the test suite:

```
test/docker
```

Or to just test in cedar or cedar-14:

```
test/docker cedar
test/docker cedar-14
```

The tests are run via the vendored [shunit2](http://shunit2.googlecode.com/svn/trunk/source/2.1/doc/shunit2.html)
test framework.
